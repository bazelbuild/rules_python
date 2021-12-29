# parse.py is a long-living program that communicates over STDIN and STDOUT.
# STDIN receives filepaths, one per line. For each parsed file, it outputs to
# STDOUT the modules parsed out of the import statements.

import ast
import json
import sys
from io import BytesIO
from tokenize import COMMENT, tokenize


def parse_import_statements(content):
    modules = list()
    tree = ast.parse(content)
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for subnode in node.names:
                module = {
                    "name": subnode.name,
                    "lineno": node.lineno,
                }
                modules.append(module)
        elif isinstance(node, ast.ImportFrom) and node.level == 0:
            module = {
                "name": node.module,
                "lineno": node.lineno,
            }
            modules.append(module)
    return modules


def parse_comments(content):
    comments = list()
    g = tokenize(BytesIO(content.encode("utf-8")).readline)
    for toknum, tokval, _, _, _ in g:
        if toknum == COMMENT:
            comments.append(tokval)
    return comments


def parse(stdout, filepath):
    with open(filepath, "r") as file:
        content = file.read()
        modules = parse_import_statements(content)
        comments = parse_comments(content)
        output = {
            "modules": modules,
            "comments": comments,
        }
        print(json.dumps(output), end="", file=stdout)
        stdout.flush()
        stdout.buffer.write(bytes([0]))
        stdout.flush()


def main(stdin, stdout):
    for filepath in stdin:
        filepath = filepath.rstrip()
        parse(stdout, filepath)


if __name__ == "__main__":
    exit(main(sys.stdin, sys.stdout))
