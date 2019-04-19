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

def pip_main(argv):
    # Extract the certificates from the PAR following the example of get-pip.py
    # https://github.com/pypa/get-pip/blob/430ba37776ae2ad89/template.py#L164-L168
    cert_path = os.path.join(tempfile.mkdtemp(), "cacert.pem")
    with open(cert_path, "wb") as cert:
      cert.write(pkgutil.get_data("pip._vendor.requests", "cacert.pem"))
    argv = ["--disable-pip-version-check", "--cert", cert_path] + argv
    return pip.main(argv)
