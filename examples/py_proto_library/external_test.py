import sys
import unittest

import external_workspace.external_pricetag_pb2


class TestCase(unittest.TestCase):
    def test_pricetag(self):
        got = external_workspace.external_pricetag_pb2.PriceTag(
            name="dollar",
            cost=5.00,
        )
        self.assertIsNotNone(got)


if __name__ == "__main__":
    unittest.main()
