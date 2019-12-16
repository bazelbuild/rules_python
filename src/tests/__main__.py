import unittest


if __name__ == '__main__':
    loader = unittest.TestLoader()
    start_dir = '.'
    suite = loader.discover(start_dir)

    runner = unittest.TextTestRunner()
    result = runner.run(suite)
    if result.errors or result.failures:
        exit(1)
