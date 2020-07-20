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

import boto3
import pip
import unittest


class BotoTest(unittest.TestCase):

  def test_version(self):
    # Just the minimal assertion that the boto3 import worked
    self.assertEqual(boto3.__version__, '1.4.7')
    # Regression test that the pip version is the one requested
    # see https://github.com/bazelbuild/rules_python/pull/1#discussion_r138349892
    self.assertEqual(pip.__version__, '9.0.3')


if __name__ == '__main__':
  unittest.main()
