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

import difflib
import hashlib
import os
import unittest
import zipfile


def TestData(name):
  return os.path.join(os.environ['TEST_SRCDIR'], 'io_bazel_rules_python', name)


def _format_toc(filename):
    """Return a table of contents for the zip file as a string.

    Args:
        filename (str): Path to zip file

    Returns: directory listed in format matching zipfile.printdir()
    """
    zf = zipfile.ZipFile(filename)
    lines = []
    lines.append("%-46s %19s %12s" % ("File Name", "Modified    ", "Size"))
    for zinfo in zf.filelist:
        date = "%d-%02d-%02d %02d:%02d:%02d" % zinfo.date_time[:6]
        lines.append("%-46s %s %12d" % (zinfo.filename, date, zinfo.file_size))
    return lines


class WheelTest(unittest.TestCase):

    def _diff_zip(self, filename1, filename2):
        """Compare two zip files for equality, pretty-printing differences."""
        with open(filename1, 'rb') as file1:
            contents1 = file1.read()
        with open (filename2, 'rb') as file2:
            contents2 = file2.read()
        if contents1 != contents2:
            toc1 = _format_toc(filename1)
            toc2 = _format_toc(filename2)
            sha1 = hashlib.sha256(filename1).hexdigest()
            sha2 = hashlib.sha256(filename2).hexdigest()
            diff = difflib.unified_diff(toc1, toc2)
            diff_str = '\n'.join(diff) or (
                'No differences in zip contents, only in zip headers [not shown]')
            message = r'''Files do not match.

************************************************************************
File 1: %s
Length in bytes: %s
SHA256: %s
************************************************************************
File 2: %s
Length in Bytes: %s
SHA256: %s
************************************************************************
Zip Content Diff:
%s
************************************************************************
''' % (
    filename1,
    len(contents1),
    sha1,
    filename2,
    len(contents2),
    sha2,
    diff_str,
)
            self.assertEquals(contents1, contents2, message)

    def test_piptool_matches(self):
        self._diff_zip(TestData('rules_python/piptool.par'),
                       TestData('tools/piptool.par'))

    def test_whltool_matches(self):
        self._diff_zip(TestData('rules_python/whltool.par'),
                       TestData('tools/whltool.par'))

if __name__ == '__main__':
  unittest.main()
