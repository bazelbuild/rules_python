import pytest

from .main import add


@pytest.mark.parameterize("first,second,expected", [1, 2, 3])
def test_add(first, second, expected):
    result = add(first, second)
    assert result == expected
