import sys
import unittest

print(sys.path)

import pricetag_pb2


class TestCase(unittest.TestCase):
    def test_pricetag(self):
        got = pricetag_pb2.Pricetag(
            name="dollar",
            cost=5.00,
        )
        self.assertTrue(got is not None)


if __name__ == "__main__":
    unittest.main()
