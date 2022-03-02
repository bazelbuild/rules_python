# parse.py is a long-living program that communicates over STDIN and STDOUT.
# STDIN receives parse requests, one per line. It outputs the parsed modules and
# comments from all the files from each request.

import ast
import concurrent.futures
import json
import os
import sys
from io import BytesIO
from tokenize import COMMENT, tokenize


def parse_import_statements(content, filepath):
    modules = list()
    tree = ast.parse(content)
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for subnode in node.names:
                module = {
                    "name": subnode.name,
                    "lineno": node.lineno,
                    "filepath": filepath,
                }
                modules.append(module)
        elif isinstance(node, ast.ImportFrom) and node.level == 0:
            module = {
                "name": node.module,
                "lineno": node.lineno,
                "filepath": filepath,
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


def parse(repo_root, rel_package_path, filename):
    rel_filepath = os.path.join(rel_package_path, filename)
    abs_filepath = os.path.join(repo_root, rel_filepath)
    with open(abs_filepath, "r") as file:
        content = file.read()
       # From simple benchmarks, 2 workers gave the best performance here.
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
            modules_future = executor.submit(parse_import_statements, content, rel_filepath)
            comments_future = executor.submit(parse_comments, content)
        modules = modules_future.result()
        comments = comments_future.result()
        output = {
            "modules": modules,
            "comments": comments,
        }
        return output


def main(stdin, stdout):
    with concurrent.futures.ProcessPoolExecutor() as executor:
        for parse_request in stdin:
            parse_request = json.loads(parse_request)
            repo_root = parse_request["repo_root"]
            rel_package_path = parse_request["rel_package_path"]
            filenames = parse_request["filenames"]
            outputs = list()
            if len(filenames) == 1:
                outputs.append(parse(repo_root, rel_package_path, filenames[0]))
            else:
                futures = [
                    executor.submit(parse, repo_root, rel_package_path, filename)
                    for filename in filenames
                    if filename != ""
                ]
                for future in concurrent.futures.as_completed(futures):
                    outputs.append(future.result())
            print(json.dumps(outputs), end="", file=stdout, flush=True)
            stdout.buffer.write(bytes([0]))
            stdout.flush()


if __name__ == "__main__":
    exit(main(sys.stdin, sys.stdout))
