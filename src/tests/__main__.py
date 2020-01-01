import os
import sys
import unittest


if __name__ == "__main__":
    loader = unittest.TestLoader()
    cur_dir = os.path.dirname(os.path.realpath(__file__))

    suite = loader.discover(cur_dir)

    runner = unittest.TextTestRunner()
    result = runner.run(suite)
    if result.errors or result.failures:
        exit(1)
