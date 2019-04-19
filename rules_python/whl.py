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
import pkg_resources
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

  # _parse_metadata parses METADATA files according to https://www.python.org/dev/peps/pep-0314/
  def _parse_metadata(self, content):
    # TODO: handle fields other than just name
    name_pattern = re.compile('Name: (.*)')
    return { 'name': name_pattern.search(content).group(1) }
