# Copyright 2022 The Bazel Authors. All rights reserved.
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

import unittest


class TestNativeExtension(unittest.TestCase):
    def test_scipy_integrate(self):
        import scipy.integrate as integrate
        import scipy.special as special

        (y, _) = integrate.quad(lambda x: special.jv(2.5, x), 0, 4.5)
        self.assertEqual(round(y, 4), 1.1178)


class TestCtypes(unittest.TestCase):
    def test_import_ctypes(self):
        from _ctypes import Array, Structure, Union

        self.assertIsNotNone(Union)
        self.assertIsNotNone(Structure)
        self.assertIsNotNone(Array)


if __name__ == "__main__":
    unittest.main()
