
import sys

with open("foo_result", "w") as f:
    print(f"{sys.argv[1]} has come and gone", file=f)
