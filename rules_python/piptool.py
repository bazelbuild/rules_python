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
    existing_pythonpath = os.environ['PYTHONPATH'].split(':')
    os.environ['PYTHONPATH'] = ':'.join(dirs_to_add + existing_pythonpath)


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


def pip_main(argv):
    argv = ["--disable-pip-version-check"] + argv
    return pip.main(argv)


# TODO(mattmoor): We can't easily depend on other libraries when
# being invoked as a raw .py file.  Once bundled, we should be able
# to remove this fallback on a stub implementation of Wheel.
try:
  from rules_python.whl import Wheel
except:
  class Wheel(object):

    def __init__(self, path):
      self._path = path

    def basename(self):
      return os.path.basename(self._path)

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
      return re.sub('[-.]', '_', canonical)

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


def main():
  args = parser.parse_args()

  # https://github.com/pypa/pip/blob/9.0.1/pip/__init__.py#L209
  if pip_main(["wheel", "-w", args.directory, "-r", args.input]):
    sys.exit(1)

  # Enumerate the .whl files we downloaded.
  def list_whls():
    dir = args.directory + '/'
    for root, unused_dirnames, filenames in os.walk(dir):
      for fname in filenames:
        if fname.endswith('.whl'):
          yield os.path.join(root, fname)

  def whl_library(wheel):
    # Indentation here matters.  whl_library must be within the scope
    # of the function below.  We also avoid reimporting an existing WHL.
    return """
  if "{repo_name}" not in native.existing_rules():
    whl_library(
        name = "{repo_name}",
        whl = "@{name}//:{path}",
        requirements = "@{name}//:requirements.bzl",
    )""".format(name=args.name, repo_name=wheel.repository_name(),
              path=wheel.basename())

  whls = [Wheel(path) for path in list_whls()]

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
  name = name.replace("-", "_").lower()
  return _requirements[name]
""".format(input=args.input,
           whl_libraries='\n'.join(map(whl_library, whls)),
           mappings=','.join([
             '"%s": "@%s//:pkg"' % (wheel.distribution().lower(), wheel.repository_name())
             for wheel in whls
           ])))

if __name__ == '__main__':
  main()
