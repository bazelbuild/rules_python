import unittest
import main


class ExampleTest(unittest.TestCase):
    def test_main(self):
        self.assertEqual("2.24.0", main.version())
        self.assertTrue(len(main.requests_wheels()))


if __name__ == '__main__':
    unittest.main()
