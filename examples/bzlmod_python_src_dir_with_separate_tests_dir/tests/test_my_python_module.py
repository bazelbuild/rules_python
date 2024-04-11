import unittest

from my_package import my_python_module


class TestMyFunc(unittest.TestCase):
    def test_good_values(self) -> None:
        got = my_python_module.my_func(0)
        self.assertEqual(got, 5)

    def test_bad_values(self) -> None:
        with self.assertRaises(TypeError):
            my_python_module.my_func(int)


if __name__ == "__main__":
    unittest.main()
