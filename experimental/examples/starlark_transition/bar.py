import sys
print("I am bar! I use Python " + str(sys.version_info[0]))

from bazel_tools.tools.python.runfiles import runfiles

r = runfiles.Create()

p = r.Rlocation("__main__/pkg/foo2.txt")
if p is not None:
    with open(p, "rt") as f:
        print("My foo2 data dep: " + str(f.read()))

p = r.Rlocation("__main__/pkg/foo3.txt")
if p is not None:
    with open(p, "rt") as f:
        print("My foo3 data dep: " + str(f.read()))
