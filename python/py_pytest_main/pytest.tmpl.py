import sys
import os

import pytest

if __name__ == "__main__":
    $$CHDIR$$

    os.environ["ENV"] = "testing"

    args = [
        "--verbose",
        "--ignore=external/",
        # Avoid loading of the plugin "cacheprovider".
        "-p",
        "no:cacheprovider",
    ]

    junit_xml_out = os.environ.get("XML_OUTPUT_FILE")
    if junit_xml_out is not None:
        args.append(f"--junitxml={junit_xml_out}")

    test_filter = os.environ.get("TESTBRIDGE_TEST_ONLY")
    if test_filter is not None:
        args.append(f"-k={test_filter}")

    user_args = [$$FLAGS$$]
    if len(user_args) > 0:
        args.extend(user_args)

    cli_args = sys.argv[1:]
    if len(cli_args) > 0:
        args.extend(cli_args)

    exit_code = pytest.main(args)

    if exit_code != 0:
        print("Pytest exit code: " + str(exit_code), file=sys.stderr)
        print("Ran pytest.main with " + str(args), file=sys.stderr)

    sys.exit(exit_code)
