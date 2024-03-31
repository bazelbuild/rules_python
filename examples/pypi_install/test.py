# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import unittest

import main


class ExampleTest(unittest.TestCase):
    def test_main(self):
        self.assertEqual("1.0", main.pkg_a_version())

    def test_original(self):
        self.assertEqual("This is pkg_a", main.pkg_a_function())

    #def test_patch(self):
    #    self.assertEqual("Hello from a patch", main.patched_hello())


if __name__ == "__main__":
    unittest.main()
