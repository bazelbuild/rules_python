import unittest

import parse


class TestParse(unittest.TestCase):
    def test_not_has_main(self):
        content = "a = 1\nb = 2"
        self.assertFalse(parse.parse_main(content))

    def test_has_main_in_function(self):
        content = """
def foo():
    if __name__ == "__main__":
        a = 3
"""
        self.assertFalse(parse.parse_main(content))

    def test_has_main(self):
        content = """
import unittest

from lib import main


class ExampleTest(unittest.TestCase):
    def test_main(self):
        self.assertEqual(
            "",
            main([["A", 1], ["B", 2]]),
        )


if __name__ == "__main__":
    unittest.main()
"""
        self.assertTrue(parse.parse_main(content))


if __name__ == "__main__":
    unittest.main()
