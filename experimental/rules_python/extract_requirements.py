import argparse
import glob
import os
import sys


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
    # This seems fragile. Need a better way to infer `bazel info output_base`
    OUTPUT_DIR = os.environ["RUNFILES_DIR"].split("sandbox")[0]
    EXTERNAL = os.path.join(OUTPUT_DIR, "external")
    requirements = set()
    for requirement in args.requirement:
        file_path = os.path.join(EXTERNAL, requirement)
        if not os.path.exists(file_path):
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
        requirements.add((meta_data_dict["Name"], meta_data_dict["Version"]))

    requirement_txt = ""
    for name, version in requirements:
        requirement_txt = "{requirement_txt}\n{name}=={version}".format(
            requirement_txt=requirement_txt, name=name, version=version
        )

    with open(args.output, "w") as fhandle:
        fhandle.write(requirement_txt)

if __name__ == "__main__":
    main()
