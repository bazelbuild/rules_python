# Copyright 2018 The Bazel Authors. All rights reserved.
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

import argparse
import base64
import collections
import hashlib
import os
import os.path
import sys
import zipfile


def commonpath(path1, path2):
    ret = []
    for a, b in zip(path1.split(os.path.sep), path2.split(os.path.sep)):
        if a != b:
            break
        ret.append(a)
    return os.path.sep.join(ret)


class WheelMaker(object):
    def __init__(self, name, version, build_tag, python_tag, abi, platform,
                 outfile=None, strip_path_prefixes=None):
        self._name = name
        self._version = version
        self._build_tag = build_tag
        self._python_tag = python_tag
        self._abi = abi
        self._platform = platform
        self._outfile = outfile
        self._strip_path_prefixes = strip_path_prefixes if strip_path_prefixes is not None else []

        self._zipfile = None
        self._record = []

    def __enter__(self):
        self._zipfile = zipfile.ZipFile(self.filename(), mode="w",
                                        compression=zipfile.ZIP_DEFLATED)
        return self

    def __exit__(self, type, value, traceback):
        self._zipfile.close()
        self._zipfile = None

    def filename(self):
        if self._outfile:
            return self._outfile
        components = [self._name, self._version]
        if self._build_tag:
            components.append(self._build_tag)
        components += [self._python_tag, self._abi, self._platform]
        return '-'.join(components) + '.whl'

    def distname(self):
        return self._name + '-' + self._version

    def disttags(self):
        return ['-'.join([self._python_tag, self._abi, self._platform])]

    def distinfo_path(self, basename):
        return self.distname() + '.dist-info/' + basename

    def _serialize_digest(self, hash):
        # https://www.python.org/dev/peps/pep-0376/#record
        # "base64.urlsafe_b64encode(digest) with trailing = removed"
        digest = base64.urlsafe_b64encode(hash.digest())
        digest = b'sha256=' + digest.rstrip(b'=')
        return digest

    def add_string(self, filename, contents):
        """Add given 'contents' as filename to the distribution."""
        if sys.version_info[0] > 2 and isinstance(contents, str):
            contents = contents.encode('utf-8', 'surrogateescape')
        self._zipfile.writestr(filename, contents)
        hash = hashlib.sha256()
        hash.update(contents)
        self._add_to_record(filename, self._serialize_digest(hash),
                            len(contents))

    def add_file(self, package_filename, real_filename):
        """Add given file to the distribution."""
        def arcname_from(name):
            # Always use unix path separators.
            normalized_arcname = name.replace(os.path.sep, '/')
            for prefix in self._strip_path_prefixes:
                if normalized_arcname.startswith(prefix):
                    return normalized_arcname[len(prefix):]

            return normalized_arcname

        arcname = arcname_from(package_filename)

        self._zipfile.write(real_filename, arcname=arcname)
        # Find the hash and length
        hash = hashlib.sha256()
        size = 0
        with open(real_filename, 'rb') as f:
            while True:
                block = f.read(2 ** 20)
                if not block:
                    break
                hash.update(block)
                size += len(block)
        self._add_to_record(arcname, self._serialize_digest(hash), size)

    def add_wheelfile(self):
        """Write WHEEL file to the distribution"""
        # TODO(pstradomski): Support non-purelib wheels.
        wheel_contents = """\
Wheel-Version: 1.0
Generator: wheelmaker 1.0
Root-Is-Purelib: true
"""
        for tag in self.disttags():
            wheel_contents += "Tag: %s\n" % tag
        self.add_string(self.distinfo_path('WHEEL'), wheel_contents)

    def add_metadata(self, extra_headers, description, classifiers, requires,
                     extra_requires):
        """Write METADATA file to the distribution."""
        # https://www.python.org/dev/peps/pep-0566/
        # https://packaging.python.org/specifications/core-metadata/
        metadata = []
        metadata.append("Metadata-Version: 2.1")
        metadata.append("Name: %s" % self._name)
        metadata.append("Version: %s" % self._version)
        metadata.extend(extra_headers)
        for classifier in classifiers:
            metadata.append("Classifier: %s" % classifier)
        for requirement in requires:
            metadata.append("Requires-Dist: %s" % requirement)

        extra_requires = sorted(extra_requires.items())
        for option, option_requires in extra_requires:
            metadata.append("Provides-Extra: %s" % option)
            for requirement in option_requires:
                metadata.append(
                    "Requires-Dist: %s; extra == '%s'" % (requirement, option))

        metadata = '\n'.join(metadata) + '\n\n'
        # setuptools seems to insert UNKNOWN as description when none is
        # provided.
        metadata += description if description else "UNKNOWN"
        metadata += "\n"
        self.add_string(self.distinfo_path('METADATA'), metadata)

    def add_entry_points(self, console_scripts):
        """Write entry_points.txt file to the distribution."""
        # https://packaging.python.org/specifications/entry-points/
        if not console_scripts:
            return
        lines = ["[console_scripts]"] + console_scripts
        contents = '\n'.join(lines)
        self.add_string(self.distinfo_path('entry_points.txt'), contents)

    def add_recordfile(self):
        """Write RECORD file to the distribution."""
        record_path = self.distinfo_path('RECORD')
        entries = self._record + [(record_path, b'', b'')]
        entries.sort()
        contents = b''
        for filename, digest, size in entries:
            if sys.version_info[0] > 2 and isinstance(filename, str):
                filename = filename.encode('utf-8', 'surrogateescape')
            contents += b'%s,%s,%s\n' % (filename, digest, size)
        self.add_string(record_path, contents)

    def _add_to_record(self, filename, hash, size):
        size = str(size).encode('ascii')
        self._record.append((filename, hash, size))


def get_files_to_package(input_files):
    """Find files to be added to the distribution.

    input_files: list of pairs (package_path, real_path)
    """
    files = {}
    for package_path, real_path in input_files:
        files[package_path] = real_path
    return files


def main():
    parser = argparse.ArgumentParser(description='Builds a python wheel')
    metadata_group = parser.add_argument_group(
        "Wheel name, version and platform")
    metadata_group.add_argument('--name', required=True,
                                type=str,
                                help="Name of the distribution")
    metadata_group.add_argument('--version', required=True,
                                type=str,
                                help="Version of the distribution")
    metadata_group.add_argument('--build_tag', type=str, default='',
                                help="Optional build tag for the distribution")
    metadata_group.add_argument('--python_tag', type=str, default='py3',
                                help="Python version, e.g. 'py2' or 'py3'")
    metadata_group.add_argument('--abi', type=str, default='none')
    metadata_group.add_argument('--platform', type=str, default='any',
                                help="Target platform. ")

    output_group = parser.add_argument_group("Output file location")
    output_group.add_argument('--out', type=str, default=None,
                              help="Override name of ouptut file")

    output_group.add_argument('--strip_path_prefix',
                              type=str,
                              action="append",
                              default=[],
                              help="Path prefix to be stripped from input package files' path. "
                                   "Can be supplied multiple times. "
                                   "Evaluated in order."
                              )

    wheel_group = parser.add_argument_group("Wheel metadata")
    wheel_group.add_argument(
        '--header', action='append',
        help="Additional headers to be embedded in the package metadata. "
             "Can be supplied multiple times.")
    wheel_group.add_argument('--classifier', action='append',
                             help="Classifiers to embed in package metadata. "
                                  "Can be supplied multiple times")
    wheel_group.add_argument('--description_file',
                             help="Path to the file with package description")

    contents_group = parser.add_argument_group("Wheel contents")
    contents_group.add_argument(
        '--input_file', action='append',
        help="'package_path;real_path' pairs listing "
             "files to be included in the wheel. "
             "Can be supplied multiple times.")
    contents_group.add_argument(
        '--console_script', action='append',
        help="Defines a 'console_script' entry point. "
             "Can be supplied multiple times.")

    requirements_group = parser.add_argument_group("Package requirements")
    requirements_group.add_argument(
        '--requires', type=str, action='append',
        help="List of package requirements. Can be supplied multiple times.")
    requirements_group.add_argument(
        '--extra_requires', type=str, action='append',
        help="List of optional requirements in a 'requirement;option name'. "
             "Can be supplied multiple times.")
    arguments = parser.parse_args(sys.argv[1:])

    # add_wheelfile and add_metadata currently assume pure-Python.
    assert arguments.platform == 'any', "Only pure-Python wheels are supported"

    input_files = [i.split(';') for i in arguments.input_file]
    all_files = get_files_to_package(input_files)
    # Sort the files for reproducible order in the archive.
    all_files = sorted(all_files.items())

    strip_prefixes = [p for p in arguments.strip_path_prefix]

    with WheelMaker(name=arguments.name,
                    version=arguments.version,
                    build_tag=arguments.build_tag,
                    python_tag=arguments.python_tag,
                    abi=arguments.abi,
                    platform=arguments.platform,
                    outfile=arguments.out,
                    strip_path_prefixes=strip_prefixes
                    ) as maker:
        for package_filename, real_filename in all_files:
            maker.add_file(package_filename, real_filename)
        maker.add_wheelfile()

        description = None
        if arguments.description_file:
            if sys.version_info[0] == 2:
                with open(arguments.description_file,
                          'rt') as description_file:
                    description = description_file.read()
            else:
                with open(arguments.description_file, 'rt',
                          encoding='utf-8') as description_file:
                    description = description_file.read()

        extra_requires = collections.defaultdict(list)
        if arguments.extra_requires:
            for extra in arguments.extra_requires:
                req, option = extra.rsplit(';', 1)
                extra_requires[option].append(req)
        classifiers = arguments.classifier or []
        requires = arguments.requires or []
        extra_headers = arguments.header or []
        console_scripts = arguments.console_script or []

        maker.add_metadata(extra_headers=extra_headers,
                           description=description,
                           classifiers=classifiers,
                           requires=requires,
                           extra_requires=extra_requires)
        maker.add_entry_points(console_scripts=console_scripts)
        maker.add_recordfile()


if __name__ == '__main__':
    main()
