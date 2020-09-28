from pkg_resources import Requirement
from packaging.version import Version, parse as parse_version
from packaging.markers import Marker
from tools.pip_import.codegen import emit_string, emit_label, emit_string_list, emit_string_dict, emit_dict, emit_rule, indent_text
from tools.pip_import.pypi import PypiAPI
from tools.pip_import.distribution import SourceDistribution, WheelDistribution
from tools.pip_import.package import Package
import re
import os
import sys
import argparse
import pkg_resources



class DistributionMetadata:
    def __init__(self, dist, release):
        deps = dist.dependencies()

        self.project_name = dist.project_name
        self.build_requirements = deps.build_requirements
        self.requirements = deps.requirements
        self.extras = deps.extras
        self.type = release['packagetype']
        self.url = release['url']
        self.archive = release['filename']
        self.version = release['version']
        self.digest = release['digests']['sha256']


def _parse_requirements(requirements):
    return list(pkg_resources.parse_requirements(requirements))


def _load_requirements(requirements):
    with open(requirements, 'r') as f:
        return _parse_requirements(f.read())


def _get_best_wheel(wheels):
    best = None

    for w in wheels:
        if best == None:
            best = w

    return best


def _fetch_distribution_metadata(client, req, output_dir):
    project = client.get_project(req.project_name)

    candidates = [
        dict(version=version, **pkg)
        for version, release in project['releases'].items()
        if version in req
        for pkg in release
    ]

    candidates.sort(
        reverse=True,
        key=lambda x: parse_version(x['version'])
    )

    sdist = next((x for x in candidates if x['packagetype'] == 'sdist'), None)
    wheel = _get_best_wheel(
        x for x in candidates if x['packagetype'] == 'bdist_wheel')

    release = None
    project_name = project['info']['name']

    if sdist:
        release = sdist
    elif wheel:
        release = wheel
    else:
        raise Exception("No compatible package for %s" % req)

    pkg_file = client.download_package(release, output_dir)
    pkg = Package(pkg_file, filename_hint=release['filename'])

    if release['packagetype'] == 'sdist':
        dist = SourceDistribution(pkg, project_name, release['version'])
    elif release['packagetype'] == 'bdist_wheel':
        dist = WheelDistribution(pkg, project_name, release['version'])

    with dist:
        return DistributionMetadata(dist, release)


MANGLE_RE = re.compile(r'[^a-zA-Z0-9_]+')


def _mangle_name(str):
    return re.sub(MANGLE_RE, '__', str)


class Context:
    def __init__(self, client, repo_name, output='.'):
        self.client = client
        self.repo_name = repo_name
        self.output = output

        self._distributions = {}

    def fetch_distribution(self, req):
        dist = self.distribution(req.project_name)

        if dist:
            return dist

        print('Processing %s' % req)
        dist = _fetch_distribution_metadata(self.client, req, self.output)

        self._distributions[req.key] = dist

        return dist

    def fetch_distributions(self, requirements):
        for req in requirements:
            self.fetch_distribution(req)

    def distribution(self, name, default=None):
        return self._distributions.get(name.lower(), default)

    def resolve_dependencies(self, requirements=[], max_rounds=10):
        def evaluate(req, extras):
            if req.marker:
                marker = req.marker
            else:
                marker = Marker('extra == ""')

            for extra in [''] + extras:
                env = {'extra': extra}

                if marker.evaluate(environment=env):
                    return True

            return False

        def all_requirements(requirements):
            req_map = {}
            result = []
            result.extend(requirements)

            for req in requirements:
                extras = req_map.get(req.key, [])
                extras.extend(req.extras)
                req_map[req.key] = extras

            for req in requirements:
                dist = self.distribution(req.project_name)

                if dist == None:
                    continue

                result.extend([
                    req
                    for reqs in [dist.requirements, dist.build_requirements]
                    for req in reqs
                    if evaluate(req, req_map.get(req.project_name, []))
                ])

            return result

        round = 0

        while True:
            requirements = all_requirements(requirements)

            missing = [
                req for req in requirements
                if self.distribution(req.project_name) == None
            ]

            if len(missing) == 0:
                break

            print('Resolving %d missing dependencies: %s' %
                  (len(missing), ', '.join([str(x) for x in missing])))

            self.fetch_distributions(missing)

            round += 1

            if round > max_rounds:
                raise Exception(
                    "maximum number of attempts to resolve dependencies")

        warnings = [
            (req, dist)
            for req in requirements
            for dist in [self.distribution(req.project_name)]
            if dist.version not in req
        ]

        def build_req(name, version, extras):
            req = '%s' % name

            if len(extras) > 0:
                req = '%s[%s]' % (req, ','.join(set(extras)))

            req = '%s==%s' % (req, version)

            return Requirement(req)

        extras = {}
        for req in requirements:
            e = extras.get(req.key, [])
            e.extend(req.extras)
            extras[req.key] = list(set(e))

        resolved = [
            (build_req(dist.project_name, dist.version, extras.get(name, [])), dist)
            for name in set(x.key for x in requirements)
            for dist in [self.distribution(name)]
        ]

        return resolved, warnings

    def package_repo_name(self, req):
        return _mangle_name('%s_%s' % (self.repo_name, req.key))

    def requirement_labels(self, req):
        def format(req, extra):
            label = '@%s//%s' % (self.package_repo_name(req),
                                 _mangle_name(req.key))

            if extra != None:
                label = "%s/%s" % (label, _mangle_name(extra.lower()))

            return label

        return [
            format(req, extra)
            for extra in req.extras or [None]
        ]

    def requirements_labels(self, reqs):
        return set(
            label
            for req in reqs
            for label in self.requirement_labels(req)
        )

    def mappings(self, requirements):
        def format_requirement_name(req):
            result = req.project_name

            if len(req.extras) > 0:
                result += '[%s]' % ','.join(req.extras)

            return result.lower()

        return {
            # FIXME: ...
            format_requirement_name(req): self.requirement_labels(req)[0]
            for req in requirements
        }

    def filter_requirements(self, requirements, env={}, extra=None):
        def marker_for(req):
            if req.marker:
                return req.marker

            return Marker('extra == ""')

        def evaluate(req, env):
            marker = marker_for(req)

            result = marker.evaluate(environment=env)

            return result

        env = env.copy()
        env['extra'] = extra or ''

        return [
            req
            for req in requirements
            if evaluate(req, env)
        ]

    def emit_repo(self, req, dist, use_archive=True):
        env = {
            'python_version': "3.7",
        }

        deps = self.requirements_labels(
            self.filter_requirements(dist.requirements, env=env))
        build_deps = self.requirements_labels(
            self.filter_requirements(dist.build_requirements, env=env))

        extras = {
            extra: self.requirements_labels(self.filter_requirements(
                dist.requirements,
                env=env,
                extra=extra,
            ))
            for extra in req.extras
        }

        attrs = {
            'name': emit_string(self.package_repo_name(req)),
            'package_name': emit_string(req.project_name),
            'sha256': emit_string(dist.digest),
        }

        if use_archive:
            attrs['archive'] = emit_label(self.repo_name, '', dist.archive)
        else:
            attrs['url'] = emit_string(dist.url)

        if len(deps) > 0:
            attrs['deps'] = emit_string_list(deps)

        if len(build_deps) > 0:
            attrs['build_deps'] = emit_string_list(build_deps)

        if len(extras) > 0:
            attrs['extras'] = emit_dict(extras, emit_value=emit_string_list)

        return emit_rule("py_external_package", attrs)


def main():
    parser = argparse.ArgumentParser(
        description='Build wheel from source distribution')

    parser.add_argument('--persist', action='store_true', default=False,
                        help=('Save package to output folder.'))

    parser.add_argument('--name', action='store', default='pypi',
                        help=('Repository name.'))

    parser.add_argument('--output', action='store',
                        help=('Output folder.'))

    parser.add_argument('requirements', action='store',
                        help=('Requirements file'))

    args = parser.parse_args()

    try:
        os.makedirs(args.output)
    except:
        pass

    package_output = args.output

    if not args.persist:
        package_output = None

    client = PypiAPI()
    ctx = Context(client, args.name, output=package_output)

    requirements = _load_requirements(args.requirements)
    resolved, warnings = ctx.resolve_dependencies(requirements)

    for req, dist in warnings:
        print("[WARN] Possible mismatch: %s vs %s" % (req, dist.version))

    mapping = ctx.mappings([
        req for req, dist in resolved
    ])

    repos = [
        ctx.emit_repo(req, dist, use_archive=args.persist)
        for req, dist in resolved
    ]

    build_file = """
load("@rules_python//python/private:py_external_package.bzl", "py_external_package")

_MAPPING = {mapping}

all_requirements = _MAPPING.keys()

def requirement(name):
  return Label(_MAPPING[name])

def pip_install():
{repos}
  """ .format(
        mapping=emit_string_dict(mapping, multiline=True),
        repos=indent_text('\n'.join(repos), level=1),
    ).replace('\'', '"')

    with open(os.path.join(args.output, 'requirements.bzl'), 'w') as f:
        f.write(build_file)

    with open(os.path.join(args.output, 'requirements.txt'), 'w') as f:
        f.write('\n'.join([
            '%s\t\t\t\t--hash=sha256:%s' % (req, dist.digest)
            for req, dist in resolved
        ]))

    return 0

