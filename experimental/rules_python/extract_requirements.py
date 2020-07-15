"""Parse bazel BUILD files and extract direct pip dependencies."""
import re
import ast
import argparse
import glob
import os
import sys


def parse_enclosed_expression(source, start, opening_token):
    """Parse an expression enclosed by a token and its counterpart.
    Args:
        source (str): Source code of a Bazel BUILD file, for example.
        start (int): Index at which an expression starts.
        opening_token (str): A character '(' or '[' that opens an expression.
    Returns:
        expression (str): The whole expression that contains the opening and closing tokens.
    Raises:
        NotImplementedError: If parsing is not implemented for the given opening token.
    """
    if opening_token == "(":
        closing_token = ")"
    elif opening_token == "[":
        closing_token = "]"
    else:
        raise NotImplementedError("No closing token defined for %s." % opening_token)

    start2 = source.find(opening_token, start)
    assert start2 > start, "Could not locate the opening token %s." % opening_token
    open_tokens = 0
    end = None

    for end_idx, char in enumerate(source[start2:], start2):
        if char == opening_token:
            open_tokens += 1
        elif char == closing_token:
            open_tokens -= 1

        if open_tokens == 0:
            end = end_idx + 1
            break

    assert end, "Could not locate the closing token %s." % closing_token

    expression = source[start:end]

    return expression, end


def parse_build_file(text):
    """Find rules and extract srcs and deps."""
    text = " ".join([x for x in text.splitlines() if not x.startswith("#")])
    source_deps = {}
    start = 0
    expressions = []
    expression, start = parse_enclosed_expression(text, start, "(")
    expressions.append(expression)
    while True:
        try:
            expression, start = parse_enclosed_expression(text, start, "(")
            expressions.append(expression)
        except AssertionError:
            break

    for rule in expressions:
        for srcs in re.findall(r"srcs\s*=\s*\[(.*?)\]", rule):
            for src in srcs.split(","):
                src = ast.literal_eval(src.strip())
                if src not in source_deps:
                    source_deps[src] = set()
                for dep in re.findall(r"deps\s*=\s*\[(.*?)\]", rule):
                    req = re.findall(r"requirement\((.*?)\)", dep)
                    source_deps[src] = source_deps[src] | {
                        ast.literal_eval(r.strip()) for r in req
                    }

    return source_deps


def filter_dependencies(source_code, direct_dependencies, all_dependencies):
    """Limit dependencies to direct dependencies.
    Args:
        source_code: Set[str] source code in srcs attribute used to identify BUILD targets.
        direct_dependencies: Dict[str Set[str]] source code (key) direct dependencies (values)
        all_dependencies: List[Tuple[str, str]] all dependencies ( direct + transitive ) from py_wheel rule.
    Return
        Set[str] direct dependencies only
    """

    required_dependencies = set()
    for src in source_code:
        for direct_dep in direct_dependencies:
            if src in direct_dep:
                required_dependencies = required_dependencies | direct_dep[src]
    return [dep for dep in all_dependencies if dep[0] in required_dependencies]


def main():
    parser = argparse.ArgumentParser(
        description="Extract dependencies from python rule"
    )
    parser.add_argument("--output", type=str, required=True, help="requirement file")
    parser.add_argument(
        "--requirement",
        type=str,
        action="append",
        help="List of dependencies . Can be supplied multiple times.",
    )
    args = parser.parse_args(sys.argv[1:])
    runfiles_dir = os.environ["RUNFILES_DIR"]

    # This seems fragile. Need a better way to infer `bazel info output_base`
    # Will break if not using sandbox
    output_dir = runfiles_dir.split("sandbox")[0]
    external = os.path.join(output_dir, "external")
    source_dir = os.path.join(output_dir, "execroot")
    requirements = set()
    direct_dependencies = list()
    source_code = set()

    for requirement in args.requirement:
        src, src_dir = os.path.basename(requirement), os.path.dirname(requirement)
        source_code.add(src)
        build_file = os.path.join(source_dir, src_dir, "BUILD")
        if os.path.exists(build_file):
            with open(build_file) as file_object:
                text = file_object.read()
                direct_dependencies.append(parse_build_file(text))
        file_path = os.path.join(external, requirement)
        if not os.path.exists(file_path):
            continue
        if os.path.isfile(file_path):
            continue
        meta_data_dict = {}
        for meta_data in glob.glob(
            os.path.join(file_path, "**/METADATA"), recursive=True
        ):
            with open(meta_data) as fhandle:
                for line in fhandle.read().splitlines():
                    if line.startswith(("Name:", "Version:")):
                        key, value = line.split(":")
                        meta_data_dict[key.strip()] = value.strip()
        if not meta_data_dict:
            continue
        requirements.add((meta_data_dict["Name"], meta_data_dict["Version"]))

    requirement_txt = ""
    requirements = filter_dependencies(source_code, direct_dependencies, requirements)
    for name, version in requirements:
        requirement_txt = "{requirement_txt}\n{name}=={version}".format(
            requirement_txt=requirement_txt, name=name, version=version
        )

    with open(args.output, "w") as fhandle:
        fhandle.write(requirement_txt)


if __name__ == "__main__":
    main()
