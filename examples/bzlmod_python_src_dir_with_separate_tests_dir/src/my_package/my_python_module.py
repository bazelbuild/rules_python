# A import something small and benign so that we can showcase installing packages from pip
import pathspec

# Satisfy linters by ignoring the import.
del pathspec


def my_func(a: int) -> int:
    return a + 5
