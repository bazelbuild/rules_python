import foo
from baz import baz as another_baz
from foo.bar import baz
from one.two import two
from package1.subpackage1.module1 import find_me

assert not hasattr(foo, "foo")
assert baz() == "baz from foo/bar.py"
assert another_baz() == "baz from baz.py"
assert two() == "two"
assert find_me() == "found"
