import unittest

import main


class ExampleTest(unittest.TestCase):
    def test_main(self):
        self.assertIn("set_stream_logger", main.the_dir())


if __name__ == "__main__":
    unittest.main()
