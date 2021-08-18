import os

import boto3
from bar import bar
from bar.baz import baz
from foo import foo

_ = boto3

if __name__ == "__main__":
    INIT_FILENAME = "__init__.py"
    dirname = os.path.dirname(os.path.abspath(__file__))
    assert bar() == os.path.join(dirname, "bar", INIT_FILENAME)
    assert baz() == os.path.join(dirname, "bar", "baz", INIT_FILENAME)
    assert foo() == os.path.join(dirname, "foo", INIT_FILENAME)
