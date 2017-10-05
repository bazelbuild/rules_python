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
"""The whl modules defines classes for interacting with Python packages."""

import argparse
import json
import os
import re
import zipfile


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
    return re.sub('[-.]', '_', canonical)

  def _dist_info(self):
    # Return the name of the dist-info directory within the .whl file.
    # e.g. google_cloud-0.27.0-py2.py3-none-any.whl ->
    #      google_cloud-0.27.0.dist-info
    return '{}-{}.dist-info'.format(self.distribution(), self.version())

  def metadata(self):
    # Extract the structured data from metadata.json in the WHL's dist-info
    # directory.
    with zipfile.ZipFile(self.path(), 'r') as whl:
      with whl.open(os.path.join(self._dist_info(), 'metadata.json')) as f:
        return json.loads(f.read().decode("utf-8"))

  def name(self):
    return self.metadata().get('name')

  def dependencies(self):
    # TODO(mattmoor): Is there a schema to follow for this?
    run_requires = self.metadata().get('run_requires', [])
    for requirement in run_requires:
      if 'extra' in requirement:
        # TODO(mattmoor): What's the best way to support "extras"?
        # https://packaging.python.org/tutorials/installing-packages/#installing-setuptools-extras
        continue
      if 'environment' in requirement:
        # TODO(mattmoor): What's the best way to support "environment"?
        # This typically communicates things like python version (look at
        # "wheel" for a good example)
        continue
      requires = requirement.get('requires', [])
      for entry in requires:
        # Strip off any trailing versioning data.
        parts = re.split('[ ><=()]', entry)
        yield parts[0]

  def expand(self, directory):
    with zipfile.ZipFile(self.path(), 'r') as whl:
      whl.extractall(directory)


parser = argparse.ArgumentParser(
    description='Unpack a WHL file as a py_library.')

parser.add_argument('--whl', action='store',
                    help=('The .whl file we are expanding.'))

parser.add_argument('--requirements', action='store',
                    help='The pip_import from which to draw dependencies.')

parser.add_argument('--directory', action='store', default='.',
                    help='The directory into which to expand things.')

def main():
  args = parser.parse_args()
  whl = Wheel(args.whl)

  # Extract the files into the current directory
  whl.expand(args.directory)

  with open(os.path.join(args.directory, 'BUILD'), 'w') as f:
    f.write("""
package(default_visibility = ["//visibility:public"])

load("{requirements}", "requirement")

py_library(
  name = "pkg",
  srcs = glob(["**/*.py"]),
  data = glob(["**/*"], exclude=["**/*.py", "**/* *", "BUILD", "WORKSPACE"]),
  # This makes this directory a top-level in the python import
  # search path for anything that depends on this.
  imports = ["."],
  deps = [{dependencies}],
     )""".format(
       requirements=args.requirements,
       dependencies=','.join([
         'requirement("%s")' % d
         for d in whl.dependencies()
       ])))
    
if __name__ == '__main__':
  main()
