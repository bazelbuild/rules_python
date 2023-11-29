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
def main():
    pass

if __name__ == "__main__":
    main()
"""
        self.assertTrue(parse.parse_main(content))


if __name__ == "__main__":
    unittest.main()
