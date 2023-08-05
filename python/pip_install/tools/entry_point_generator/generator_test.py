#!/usr/bin/env python3
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

import pathlib
import tempfile
import textwrap
import unittest

from python.pip_install.tools.entry_point_generator.generator import run


class RunTest(unittest.TestCase):
    def test_no_entry_point(self):
        with self.assertRaises(RuntimeError) as cm:
            run(
                dist_info_files=[pathlib.Path(__file__)],
                out=pathlib.Path(__file__),
                script=None,
                shebang="#!/dev/null",
            )

        self.assertEqual(
            "The package does not provide any entry_points.txt file in it's dist-info",
            cm.exception.args[0],
        )

    def test_no_console_scripts_error(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir = pathlib.Path(tmpdir)
            given_contents = (
                textwrap.dedent(
                    """
            [non_console_scripts]
            foo = foo.bar:fizz
            """
                ).strip()
                + "\n"
            )
            entry_points = tmpdir / "entry_points.txt"
            entry_points.write_text(given_contents)

            with self.assertRaises(RuntimeError) as cm:
                run(
                    dist_info_files=[entry_points],
                    out=pathlib.Path(__file__),
                    script=None,
                    shebang="#!/dev/null",
                )

        self.assertEqual(
            "The package does not provide any console_scripts in it's entry_points.txt",
            cm.exception.args[0],
        )

    def test_no_entry_point_selected_error(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir = pathlib.Path(tmpdir)
            given_contents = (
                textwrap.dedent(
                    """
            [console_scripts]
            foo = foo.bar:fizz
            bar = foo.bar:buzz
            """
                ).strip()
                + "\n"
            )
            entry_points = tmpdir / "entry_points.txt"
            entry_points.write_text(given_contents)

            with self.assertRaises(RuntimeError) as cm:
                run(
                    dist_info_files=[entry_points],
                    out=pathlib.Path(__file__),
                    script=None,
                    shebang="#!/dev/null",
                )

        self.assertEqual(
            "Please select one of the following console scripts: foo, bar",
            cm.exception.args[0],
        )

    def test_a_single_entry_point(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir = pathlib.Path(tmpdir)
            given_contents = (
                textwrap.dedent(
                    """
            [console_scripts]
            foo = foo.bar:baz
            """
                ).strip()
                + "\n"
            )
            entry_points = tmpdir / "entry_points.txt"
            entry_points.write_text(given_contents)
            out = tmpdir / "out.py"

            run(
                dist_info_files=[entry_points],
                out=out,
                script=None,
                shebang="#!/dev/null",
            )

            got = out.read_text()

        want = textwrap.dedent(
            """\
        #!/dev/null
        import sys
        # Drop the first entry in the sys.path, because it will point to our workspace
        # where we are generating the entry_point script and it seems that some package
        # break due to this reason (e.g. pylint). This means that we should not use this
        # script to ever generate entry points for scripts within the main workspace,
        # but that is fine, we can create a separate generator or a boolean flag for
        # that.
        if sys.path[0].endswith(".runfiles"):
            sys.path = sys.path[1:]

        from foo.bar import baz

        if __name__ == "__main__":
            sys.exit(baz())
        """
        )
        self.assertEqual(want, got)

    def test_a_second_entry_point_class_method(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir = pathlib.Path(tmpdir)
            given_contents = (
                textwrap.dedent(
                    """
            [console_scripts]
            foo = foo.bar:Bar.baz
            bar = foo.baz:Bar.baz
            """
                ).strip()
                + "\n"
            )
            entry_points = tmpdir / "entry_points.txt"
            entry_points.write_text(given_contents)
            out = tmpdir / "out.py"

            run(
                dist_info_files=[entry_points],
                out=out,
                script="bar",
                shebang="#!/dev/null",
            )

            got = out.read_text()

        want = textwrap.dedent(
            """\
        #!/dev/null
        import sys
        # Drop the first entry in the sys.path, because it will point to our workspace
        # where we are generating the entry_point script and it seems that some package
        # break due to this reason (e.g. pylint). This means that we should not use this
        # script to ever generate entry points for scripts within the main workspace,
        # but that is fine, we can create a separate generator or a boolean flag for
        # that.
        if sys.path[0].endswith(".runfiles"):
            sys.path = sys.path[1:]

        from foo.baz import Bar

        if __name__ == "__main__":
            sys.exit(Bar.baz())
        """
        )
        self.assertEqual(want, got)


if __name__ == "__main__":
    unittest.main()
