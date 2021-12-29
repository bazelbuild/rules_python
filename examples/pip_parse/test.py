import unittest

import main


class ExampleTest(unittest.TestCase):
    def test_main(self):
        self.assertEqual("2.25.1", main.version())


if __name__ == "__main__":
    unittest.main()
