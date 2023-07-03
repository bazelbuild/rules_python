import argparse
import json
import sys
from pathlib import Path

from packaging.requirements import Requirement

def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--installation_report",
            required=True,
            type=Path)
    args = parser.parse_args(argv[1:])

    with args.installation_report.open() as file:
        report = json.load(file)

    for install in report["install"]:
        download_info = install["download_info"]
        metadata = install["metadata"]
        name = metadata["name"]
        requires_dist = metdata.get("requires_dist", [])

        for raw_requirement in requires_dist:
            requirement = Requirement(raw_requirement)

if __name__ == "__main__":
    sys.exit(main(sys.argv))
