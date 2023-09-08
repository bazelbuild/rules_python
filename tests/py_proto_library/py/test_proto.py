import unittest

class TestProto(unittest.TestCase):
    def test_import_one(self):
        from proto.one_pb2 import DESCRIPTOR

if __name__ == "__main__":
    unittest.main()