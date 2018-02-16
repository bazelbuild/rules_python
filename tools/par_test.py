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

import hashlib
import os
import unittest


def TestData(name):
  return os.path.join(os.environ['TEST_SRCDIR'], 'io_bazel_rules_python', name)


class WheelTest(unittest.TestCase):

  def test_piptool_matches(self):
    with open(TestData('rules_python/piptool.par'), 'r') as f:
      built = f.read()
    with open(TestData('tools/piptool.par'), 'r') as f:
      checked_in = f.read()
    self.assertEquals(
      hashlib.sha256(built).hexdigest(), hashlib.sha256(checked_in).hexdigest(),
      'The checked in tools/piptool.par does not match the latest build.')

  def test_whltool_matches(self):
    with open(TestData('rules_python/whltool.par'), 'r') as f:
      built = f.read()
    with open(TestData('tools/whltool.par'), 'r') as f:
      checked_in = f.read()
    self.assertEquals(
      hashlib.sha256(built).hexdigest(), hashlib.sha256(checked_in).hexdigest(),
      'The checked in tools/whltool.par does not match the latest build.')

if __name__ == '__main__':
  unittest.main()
