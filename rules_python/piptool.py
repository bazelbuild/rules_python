# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""The piptool module imports pip requirements into Bazel rules."""

import argparse
import atexit
import json
import os
import pkgutil
import pkg_resources
import re
import shutil
import sys
import tempfile
import zipfile


# Note: We carefully import the following modules in a particular
# order, since these modules modify the import path and machinery.
import pkg_resources


def extract_packages(package_names):
    """Extract zipfile contents to disk and add to import path"""

    # Set a safe extraction dir
    extraction_tmpdir = tempfile.mkdtemp()
    atexit.register(lambda: shutil.rmtree(
        extraction_tmpdir, ignore_errors=True))
    pkg_resources.set_extraction_path(extraction_tmpdir)

    # Extract each package to disk
    dirs_to_add = []
    for package_name in package_names:
        req = pkg_resources.Requirement.parse(package_name)
        extraction_dir = pkg_resources.resource_filename(req, '')
        dirs_to_add.append(extraction_dir)

    # Add extracted directories to import path ahead of their zip file
    # counterparts.
    sys.path[0:0] = dirs_to_add
    existing_pythonpath = os.environ.get('PYTHONPATH')
    if existing_pythonpath:
        dirs_to_add.extend(existing_pythonpath.split(':'))
    os.environ['PYTHONPATH'] = ':'.join(dirs_to_add)


# Wheel, pip, and setuptools are much happier running from actual
# files on disk, rather than entries in a zipfile.  Extract zipfile
# contents, add those contents to the path, then import them.
extract_packages(['pip', 'setuptools', 'wheel'])

# Defeat pip's attempt to mangle sys.path
saved_sys_path = sys.path
sys.path = sys.path[:]
import pip
sys.path = saved_sys_path

import setuptools
import wheel


def pip_main(certfile, argv):
    # Extract the certificates from the PAR following the example of get-pip.py
    # https://github.com/pypa/get-pip/blob/430ba37776ae2ad89/template.py#L164-L168
    argv = ["--disable-pip-version-check", "--cert", certfile] + argv
    return pip.main(argv)


class Wheel(object):

  def __init__(self, path):
    self._path = path

  def path(self):
    return self._path

  def basename(self):
    return os.path.basename(self.path())

  def distribution(self):
    # See https://www.python.org/dev/peps/pep-0427/#file-name-convention
    parts = self.basename().split('-')
    return parts[0]

  def version(self):
    # See https://www.python.org/dev/peps/pep-0427/#file-name-convention
    parts = self.basename().split('-')
    return parts[1]

  def repository_name(self):
    # Returns the canonical name of the Bazel repository for this package.
    canonical = 'pypi__{}_{}'.format(self.distribution(), self.version())
    # Escape any illegal characters with underscore.
    return re.sub('[-.+]', '_', canonical)

  def _dist_info(self):
    # Return the name of the dist-info directory within the .whl file.
    # e.g. google_cloud-0.27.0-py2.py3-none-any.whl ->
    #      google_cloud-0.27.0.dist-info
    return '{}-{}.dist-info'.format(self.distribution(), self.version())

  def metadata(self):
    # Extract the structured data from metadata.json in the WHL's dist-info
    # directory.
    with zipfile.ZipFile(self.path(), 'r') as whl:
      # first check for metadata.json
      try:
        with whl.open(self._dist_info() + '/metadata.json') as f:
          return json.loads(f.read().decode("utf-8"))
      except KeyError:
          pass
      # fall back to METADATA file (https://www.python.org/dev/peps/pep-0427/)
      with whl.open(self._dist_info() + '/METADATA') as f:
        return self._parse_metadata(f.read().decode("utf-8"))

  def name(self):
    return self.metadata().get('name')

  def dependencies(self, extra=None):
    """Access the dependencies of this Wheel.

    Args:
      extra: if specified, include the additional dependencies
            of the named "extra".

    Yields:
      the names of requirements from the metadata.json
    """
    # TODO(mattmoor): Is there a schema to follow for this?
    run_requires = self.metadata().get('run_requires', [])
    for requirement in run_requires:
      if requirement.get('extra') != extra:
        # Match the requirements for the extra we're looking for.
        continue
      marker = requirement.get('environment')
      if marker and not pkg_resources.evaluate_marker(marker):
        # The current environment does not match the provided PEP 508 marker,
        # so ignore this requirement.
        continue
      requires = requirement.get('requires', [])
      for entry in requires:
        # Strip off any trailing versioning data.
        parts = re.split('[ ><=()]', entry)
        yield parts[0]

  def extras(self):
    return self.metadata().get('extras', [])

  def expand(self, directory):
    with zipfile.ZipFile(self.path(), 'r') as whl:
      whl.extractall(directory)

  # _parse_metadata parses METADATA files according to https://www.python.org/dev/peps/pep-0314/
  def _parse_metadata(self, content):
    # TODO: handle fields other than just name
    name_pattern = re.compile('Name: (.*)')
    return { 'name': name_pattern.search(content).group(1) }


parser = argparse.ArgumentParser(
    description='Import Python dependencies into Bazel.')

parser.add_argument('--name', action='store',
                    help=('The namespace of the import.'))

parser.add_argument('--input', action='store',
                    help=('The requirements.txt file to import.'))

parser.add_argument('--output', action='store',
                    help=('The requirements.bzl file to export.'))

parser.add_argument('--directory', action='store',
                    help=('The directory into which to put .whl files.'))

parser.add_argument('--certfile', action='store',
                    help=('The path to the certifcate PEM file.'))

def determine_possible_extras(whls):
  """Determines the list of possible "extras" for each .whl

  The possibility of an extra is determined by looking at its
  additional requirements, and determinine whether they are
  satisfied by the complete list of available wheels.

  Args:
    whls: a list of Wheel objects

  Returns:
    a dict that is keyed by the Wheel objects in whls, and whose
    values are lists of possible extras.
  """
  whl_map = {
    whl.distribution(): whl
    for whl in whls
  }

  # TODO(mattmoor): Consider memoizing if this recursion ever becomes
  # expensive enough to warrant it.
  def is_possible(distro, extra):
    distro = distro.replace("-", "_")
    # If we don't have the .whl at all, then this isn't possible.
    if distro not in whl_map:
      return False
    whl = whl_map[distro]
    # If we have the .whl, and we don't need anything extra then
    # we can satisfy this dependency.
    if not extra:
      return True
    # If we do need something extra, then check the extra's
    # dependencies to make sure they are fully satisfied.
    for extra_dep in whl.dependencies(extra=extra):
      req = pkg_resources.Requirement.parse(extra_dep)
      # Check that the dep and any extras are all possible.
      if not is_possible(req.project_name, None):
        return False
      for e in req.extras:
        if not is_possible(req.project_name, e):
          return False
    # If all of the dependencies of the extra are satisfiable then
    # it is possible to construct this dependency.
    return True

  return {
    whl: [
      extra
      for extra in whl.extras()
      if is_possible(whl.distribution(), extra)
    ]
    for whl in whls
  }

def main():
  args = parser.parse_args()

  # https://github.com/pypa/pip/blob/9.0.1/pip/__init__.py#L209
  if pip_main(args.certfile, ["wheel", "-w", args.directory, "-r", args.input]):
    sys.exit(1)

  # Enumerate the .whl files we downloaded.
  def list_whls():
    dir = args.directory + '/'
    for root, unused_dirnames, filenames in os.walk(dir):
      for fname in filenames:
        if fname.endswith('.whl'):
          yield os.path.join(root, fname)

  whls = [Wheel(path) for path in list_whls()]
  possible_extras = determine_possible_extras(whls)

  def whl_library(wheel):
    # Indentation here matters.  whl_library must be within the scope
    # of the function below.  We also avoid reimporting an existing WHL.
    return """
  if "{repo_name}" not in native.existing_rules():
    whl_library(
        name = "{repo_name}",
        whl = "@{name}//:{path}",
        requirements = "@{name}//:requirements.bzl",
        extras = [{extras}]
    )""".format(name=args.name, repo_name=wheel.repository_name(),
                path=wheel.basename(),
                extras=','.join([
                  '"%s"' % extra
                  for extra in possible_extras.get(wheel, [])
                ]))

  whl_targets = ','.join([
    ','.join([
      '"%s": "@%s//:pkg"' % (whl.distribution().lower(), whl.repository_name())
    ] + [
      # For every extra that is possible from this requirements.txt
      '"%s[%s]": "@%s//:%s"' % (whl.distribution().lower(), extra.lower(),
                                whl.repository_name(), extra)
      for extra in possible_extras.get(whl, [])
    ])
    for whl in whls
  ])

  with open(args.output, 'w') as f:
    f.write("""\
# Install pip requirements.
#
# Generated from {input}

load("@io_bazel_rules_python//python:whl.bzl", "whl_library")

def pip_install():
  {whl_libraries}

_requirements = {{
  {mappings}
}}

all_requirements = _requirements.values()

def requirement(name):
  name_key = name.replace("-", "_").lower()
  if name_key not in _requirements:
    fail("Could not find pip-provided dependency: '%s'" % name)
  return _requirements[name_key]
""".format(input=args.input,
           whl_libraries='\n'.join(map(whl_library, whls)) if whls else "pass",
           mappings=whl_targets))

if __name__ == '__main__':
  main()
