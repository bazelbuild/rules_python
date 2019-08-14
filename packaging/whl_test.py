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

from mock import patch

from packaging import whl


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
    self.assertEqual([], wheel.extras())

  def test_futures_whl(self):
    td = TestData('futures_3_1_1_whl/file/futures-3.1.1-py2-none-any.whl')
    wheel = whl.Wheel(td)
    self.assertEqual(wheel.name(), 'futures')
    self.assertEqual(wheel.distribution(), 'futures')
    self.assertEqual(wheel.version(), '3.1.1')
    self.assertEqual(set(wheel.dependencies()), set())
    self.assertEqual('pypi__futures_3_1_1', wheel.repository_name())
    self.assertEqual([], wheel.extras())

  def test_whl_with_METADATA_file(self):
    td = TestData('futures_2_2_0_whl/file/futures-2.2.0-py2.py3-none-any.whl')
    wheel = whl.Wheel(td)
    self.assertEqual(wheel.name(), 'futures')
    self.assertEqual(wheel.distribution(), 'futures')
    self.assertEqual(wheel.version(), '2.2.0')
    self.assertEqual(set(wheel.dependencies()), set())
    self.assertEqual('pypi__futures_2_2_0', wheel.repository_name())

  @patch('platform.python_version', return_value='2.7.13')
  def test_mock_whl(self, *args):
    td = TestData('mock_whl/file/mock-2.0.0-py2.py3-none-any.whl')
    wheel = whl.Wheel(td)
    self.assertEqual(wheel.name(), 'mock')
    self.assertEqual(wheel.distribution(), 'mock')
    self.assertEqual(wheel.version(), '2.0.0')
    self.assertEqual(set(wheel.dependencies()),
                     set(['funcsigs', 'pbr', 'six']))
    self.assertEqual('pypi__mock_2_0_0', wheel.repository_name())

  @patch('platform.python_version', return_value='3.3.0')
  def test_mock_whl_3_3(self, *args):
    td = TestData('mock_whl/file/mock-2.0.0-py2.py3-none-any.whl')
    wheel = whl.Wheel(td)
    self.assertEqual(set(wheel.dependencies()),
                     set(['pbr', 'six']))

  @patch('platform.python_version', return_value='2.7.13')
  def test_mock_whl_extras(self, *args):
    td = TestData('mock_whl/file/mock-2.0.0-py2.py3-none-any.whl')
    wheel = whl.Wheel(td)
    self.assertEqual(['docs', 'test'], wheel.extras())
    self.assertEqual(set(wheel.dependencies(extra='docs')), set(['sphinx']))
    self.assertEqual(set(wheel.dependencies(extra='test')), set(['unittest2']))

  @patch('platform.python_version', return_value='3.0.0')
  def test_mock_whl_extras_3_0(self, *args):
    td = TestData('mock_whl/file/mock-2.0.0-py2.py3-none-any.whl')
    wheel = whl.Wheel(td)
    self.assertEqual(['docs', 'test'], wheel.extras())
    self.assertEqual(set(wheel.dependencies(extra='docs')), set(['sphinx', 'Pygments', 'jinja2']))
    self.assertEqual(set(wheel.dependencies(extra='test')), set(['unittest2']))

  @patch('platform.python_version', return_value='2.7.13')
  def test_google_cloud_language_whl(self, *args):
    td = TestData('google_cloud_language_whl/file/' +
                  'google_cloud_language-0.29.0-py2.py3-none-any.whl')
    wheel = whl.Wheel(td)
    self.assertEqual(wheel.name(), 'google-cloud-language')
    self.assertEqual(wheel.distribution(), 'google_cloud_language')
    self.assertEqual(wheel.version(), '0.29.0')
    expected_deps = ['google-gax', 'google-cloud-core',
                     'googleapis-common-protos[grpc]', 'enum34']
    self.assertEqual(set(wheel.dependencies()),
                     set(expected_deps))
    self.assertEqual('pypi__google_cloud_language_0_29_0',
                     wheel.repository_name())
    self.assertEqual([], wheel.extras())

  @patch('platform.python_version', return_value='3.4.0')
  def test_google_cloud_language_whl_3_4(self, *args):
    td = TestData('google_cloud_language_whl/file/' +
                  'google_cloud_language-0.29.0-py2.py3-none-any.whl')
    wheel = whl.Wheel(td)
    expected_deps = ['google-gax', 'google-cloud-core',
                     'googleapis-common-protos[grpc]']
    self.assertEqual(set(wheel.dependencies()),
                     set(expected_deps))

if __name__ == '__main__':
  unittest.main()
