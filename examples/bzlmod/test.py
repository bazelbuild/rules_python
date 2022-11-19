import unittest

from __init__ import main


class ExampleTest(unittest.TestCase):
    def test_main(self):
        self.assertEquals(
            """\
-  -
A  1
B  2
-  -""",
            main([["A", 1], ["B", 2]]),
        )


if __name__ == "__main__":
    unittest.main()
