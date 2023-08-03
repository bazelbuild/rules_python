import unittest
import prefixed.pricetag_with_prefix_pb2


class TestCase(unittest.TestCase):
    def test_pricetag(self):
        got = prefixed.pricetag_with_prefix_pb2.PriceTag(
            name="dollar",
            cost=5.00,
        )
        self.assertIsNotNone(got)


if __name__ == "__main__":
    unittest.main()
