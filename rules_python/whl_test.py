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

import os
import unittest

from rules_python import whl


def TestData(name):
  return os.path.join(os.environ['TEST_SRCDIR'], name)


class WheelTest(unittest.TestCase):

  def test_grpc_whl(self):
    td = TestData('grpc_whl/file/grpcio-1.6.0-cp27-cp27m-manylinux1_i686.whl')
    wheel = whl.Wheel(td)
    self.assertEqual(wheel.name(), 'grpcio')
    self.assertEqual(wheel.distribution(), 'grpcio')
    self.assertEqual(wheel.version(), '1.6.0')
    self.assertEqual(set(wheel.dependencies()),
                     set(['enum34', 'futures', 'protobuf', 'six']))
    self.assertEqual('pypi__grpcio_1_6_0', wheel.repository_name())

  def test_futures_whl(self):
    td = TestData('futures_whl/file/futures-3.1.1-py2-none-any.whl')
    wheel = whl.Wheel(td)
    self.assertEqual(wheel.name(), 'futures')
    self.assertEqual(wheel.distribution(), 'futures')
    self.assertEqual(wheel.version(), '3.1.1')
    self.assertEqual(set(wheel.dependencies()), set())
    self.assertEqual('pypi__futures_3_1_1', wheel.repository_name())

  def test_mock_whl(self):
    td = TestData('mock_whl/file/mock-2.0.0-py2.py3-none-any.whl')
    wheel = whl.Wheel(td)
    self.assertEqual(wheel.name(), 'mock')
    self.assertEqual(wheel.distribution(), 'mock')
    self.assertEqual(wheel.version(), '2.0.0')
    self.assertEqual(set(wheel.dependencies()),
                     set(['pbr', 'six']))
    self.assertEqual('pypi__mock_2_0_0', wheel.repository_name())

if __name__ == '__main__':
  unittest.main()
