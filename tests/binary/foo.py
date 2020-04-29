
import sys

with open("foo_result", "w") as f:
    print("%s has come and gone" % sys.argv[1], file=f)
