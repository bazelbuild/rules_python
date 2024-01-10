import sys

for i, v in enumerate(sys.path):
    print(f"[{i}] {v}")

import rules_python
print(f'rules_python = {rules_python}')
import rules_python.python
print(f'rules_python.python = {rules_python.python}')
import rules_python.python.runfiles
print(f'rules_python.python.runfilse = {rules_python.python.runfiles}')

import python
print(f'python = {python}')

print("rules_python.python is python? -> ", rules_python.python is python)
