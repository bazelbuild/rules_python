# Copyright 2018 The Bazel Authors. All rights reserved.
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
import zipfile


class WheelTest(unittest.TestCase):
    def test_py_library_wheel(self):
        filename = os.path.join(os.environ['TEST_SRCDIR'],
                                'io_bazel_rules_python', 'experimental',
                                'examples', 'wheel',
                                'example_minimal_library-0.0.1-py3-none-any.whl')
        with zipfile.ZipFile(filename) as zf:
            self.assertEquals(
                zf.namelist(),
                ['experimental/examples/wheel/lib/module_with_data.py',
                 'experimental/examples/wheel/lib/simple_module.py',
                 'example_minimal_library-0.0.1.dist-info/WHEEL',
                 'example_minimal_library-0.0.1.dist-info/METADATA',
                 'example_minimal_library-0.0.1.dist-info/RECORD'])

    def test_py_package_wheel(self):
        filename = os.path.join(os.environ['TEST_SRCDIR'],
                                'io_bazel_rules_python', 'experimental',
                                'examples', 'wheel',
                                'example_minimal_package-0.0.1-py3-none-any.whl')
        with zipfile.ZipFile(filename) as zf:
            self.assertEquals(
                zf.namelist(),
                ['experimental/examples/wheel/lib/data.txt',
                 'experimental/examples/wheel/lib/module_with_data.py',
                 'experimental/examples/wheel/lib/simple_module.py',
                 'experimental/examples/wheel/main.py',
                 'example_minimal_package-0.0.1.dist-info/WHEEL',
                 'example_minimal_package-0.0.1.dist-info/METADATA',
                 'example_minimal_package-0.0.1.dist-info/RECORD'])

    def test_customized_wheel(self):
        filename = os.path.join(os.environ['TEST_SRCDIR'],
                                'io_bazel_rules_python', 'experimental',
                                'examples', 'wheel',
                                'example_customized-0.0.1-py3-none-any.whl')
        with zipfile.ZipFile(filename) as zf:
            self.assertEquals(
                zf.namelist(),
                ['experimental/examples/wheel/lib/data.txt',
                 'experimental/examples/wheel/lib/module_with_data.py',
                 'experimental/examples/wheel/lib/simple_module.py',
                 'experimental/examples/wheel/main.py',
                 'example_customized-0.0.1.dist-info/WHEEL',
                 'example_customized-0.0.1.dist-info/METADATA',
                 'example_customized-0.0.1.dist-info/entry_points.txt',
                 'example_customized-0.0.1.dist-info/RECORD'])
            record_contents = zf.read(
                'example_customized-0.0.1.dist-info/RECORD')
            wheel_contents = zf.read(
                'example_customized-0.0.1.dist-info/WHEEL')
            metadata_contents = zf.read(
                'example_customized-0.0.1.dist-info/METADATA')
            # The entries are guaranteed to be sorted.
            self.assertEquals(record_contents, b"""\
example_customized-0.0.1.dist-info/METADATA,sha256=TeeEmokHE2NWjkaMcVJuSAq4_AXUoIad2-SLuquRmbg,372
example_customized-0.0.1.dist-info/RECORD,,
example_customized-0.0.1.dist-info/WHEEL,sha256=F01lGfVCzcXUzzQHzUkBmXAcu_TXd5zqMLrvrspncJo,85
example_customized-0.0.1.dist-info/entry_points.txt,sha256=olLJ8FK88aft2pcdj4BD05F8Xyz83Mo51I93tRGT2Yk,74
experimental/examples/wheel/lib/data.txt,sha256=9vJKEdfLu8bZRArKLroPZJh1XKkK3qFMXiM79MBL2Sg,12
experimental/examples/wheel/lib/module_with_data.py,sha256=K_IGAq_CHcZX0HUyINpD1hqSKIEdCn58d9E9nhWF2EA,636
experimental/examples/wheel/lib/simple_module.py,sha256=72-91Dm6NB_jw-7wYQt7shzdwvk5RB0LujIah8g7kr8,636
experimental/examples/wheel/main.py,sha256=E0xCyiPg6fCo4IrFmqo_tqpNGtk1iCewobqD0_KlFd0,935
""")
            self.assertEquals(wheel_contents, b"""\
Wheel-Version: 1.0
Generator: wheelmaker 1.0
Root-Is-Purelib: true
Tag: py3-none-any
""")
            self.assertEquals(metadata_contents, b"""\
Metadata-Version: 2.1
Name: example_customized
Version: 0.0.1
Author: Example Author with non-ascii characters: \xc5\xbc\xc3\xb3\xc5\x82w
Author-email: example@example.com
Home-page: www.example.com
License: Apache 2.0
Classifier: License :: OSI Approved :: Apache Software License
Classifier: Intended Audience :: Developers
Requires-Dist: pytest

This is a sample description of a wheel.
""")

    def test_custom_package_root_wheel(self):
        filename = os.path.join(os.environ['TEST_SRCDIR'],
                                'io_bazel_rules_python', 'experimental',
                                'examples', 'wheel',
                                'example_custom_package_root-0.0.1-py3-none-any.whl')

        with zipfile.ZipFile(filename) as zf:
            self.assertEquals(
                zf.namelist(),
                ['examples/wheel/lib/data.txt',
                 'examples/wheel/lib/module_with_data.py',
                 'examples/wheel/lib/simple_module.py',
                 'examples/wheel/main.py',
                 'example_custom_package_root-0.0.1.dist-info/WHEEL',
                 'example_custom_package_root-0.0.1.dist-info/METADATA',
                 'example_custom_package_root-0.0.1.dist-info/RECORD'])

    def test_custom_package_root_multi_prefix_wheel(self):
        filename = os.path.join(os.environ['TEST_SRCDIR'],
                                'io_bazel_rules_python', 'experimental',
                                'examples', 'wheel',
                                'example_custom_package_root_multi_prefix-0.0.1-py3-none-any.whl')

        with zipfile.ZipFile(filename) as zf:
            self.assertEquals(
                zf.namelist(),
                ['data.txt',
                 'module_with_data.py',
                 'simple_module.py',
                 'main.py',
                 'example_custom_package_root_multi_prefix-0.0.1.dist-info/WHEEL',
                 'example_custom_package_root_multi_prefix-0.0.1.dist-info/METADATA',
                 'example_custom_package_root_multi_prefix-0.0.1.dist-info/RECORD'])

    def test_custom_package_root_multi_prefix_reverse_order_wheel(self):
        filename = os.path.join(os.environ['TEST_SRCDIR'],
                                'io_bazel_rules_python', 'experimental',
                                'examples', 'wheel',
                                'example_custom_package_root_multi_prefix_reverse_order-0.0.1-py3-none-any.whl')

        with zipfile.ZipFile(filename) as zf:
            self.assertEquals(
                zf.namelist(),
                ['lib/data.txt',
                 'lib/module_with_data.py',
                 'lib/simple_module.py',
                 'main.py',
                 'example_custom_package_root_multi_prefix_reverse_order-0.0.1.dist-info/WHEEL',
                 'example_custom_package_root_multi_prefix_reverse_order-0.0.1.dist-info/METADATA',
                 'example_custom_package_root_multi_prefix_reverse_order-0.0.1.dist-info/RECORD'])


if __name__ == '__main__':
    unittest.main()
