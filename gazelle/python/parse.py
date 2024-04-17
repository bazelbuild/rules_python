# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# parse.py is a long-living program that communicates over STDIN and STDOUT.
# STDIN receives parse requests, one per line. It outputs the parsed modules and
# comments from all the files from each request.

import ast
import concurrent.futures
import json
import os
import platform
import sys
from io import BytesIO
from tokenize import COMMENT, NAME, OP, STRING, tokenize


def parse_import_statements(content, filepath):
    modules = list()
    tree = ast.parse(content, filename=filepath)
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for subnode in node.names:
                module = {
                    "name": subnode.name,
                    "lineno": node.lineno,
                    "filepath": filepath,
                    "from": "",
                }
                modules.append(module)
        elif isinstance(node, ast.ImportFrom) and node.level == 0:
            for subnode in node.names:
                module = {
                    "name": f"{node.module}.{subnode.name}",
                    "lineno": node.lineno,
                    "filepath": filepath,
                    "from": node.module,
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


def parse_main(content):
    g = tokenize(BytesIO(content.encode("utf-8")).readline)
    for token_type, token_val, start, _, _ in g:
        if token_type != NAME or token_val != "if" or start[1] != 0:
            continue
        try:
            token_type, token_val, start, _, _ = next(g)
            if token_type != NAME or token_val != "__name__":
                continue
            token_type, token_val, start, _, _ = next(g)
            if token_type != OP or token_val != "==":
                continue
            token_type, token_val, start, _, _ = next(g)
            if token_type != STRING or token_val.strip("\"'") != '__main__':
                continue
            token_type, token_val, start, _, _ = next(g)
            if token_type != OP or token_val != ":":
                continue
            return True
        except StopIteration:
            break
    return False


def parse(repo_root, rel_package_path, filename):
    rel_filepath = os.path.join(rel_package_path, filename)
    abs_filepath = os.path.join(repo_root, rel_filepath)
    with open(abs_filepath, "r") as file:
        content = file.read()
        # From simple benchmarks, 2 workers gave the best performance here.
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
            modules_future = executor.submit(
                parse_import_statements, content, rel_filepath
            )
            comments_future = executor.submit(parse_comments, content)
            main_future = executor.submit(parse_main, content)
        modules = modules_future.result()
        comments = comments_future.result()
        has_main = main_future.result()

        output = {
            "filename": filename,
            "modules": modules,
            "comments": comments,
            "has_main": has_main,
        }
        return output


def create_main_executor():
    # We cannot use ProcessPoolExecutor on macOS, because the fork start method should be considered unsafe as it can
    # lead to crashes of the subprocess as macOS system libraries may start threads. Meanwhile, the 'spawn' and
    # 'forkserver' start methods generally cannot be used with “frozen” executables (i.e., Python zip file) on POSIX
    # systems. Therefore, there is no good way to use ProcessPoolExecutor on macOS when we distribute this program with
    # a zip file.
    # Ref: https://docs.python.org/3/library/multiprocessing.html#contexts-and-start-methods
    if platform.system() == "Darwin":
        return concurrent.futures.ThreadPoolExecutor()
    return concurrent.futures.ProcessPoolExecutor()

def main(stdin, stdout):
    with create_main_executor() as executor:
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
