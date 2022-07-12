import unittest

from __init__ import main


class ExampleTest(unittest.TestCase):
    def test_main(self):
        self.assertEquals("http://google.com", main("http://google.com"))


if __name__ == "__main__":
    unittest.main()
