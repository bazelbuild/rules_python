import argparse
import multiprocessing
import subprocess
import sys
from datetime import datetime

mutex = multiprocessing.Lock()


def build(wheel):
    print("{}: building {}".format(datetime.now(), wheel), file=sys.stderr)
    process = subprocess.run(
        [sys.executable, "-m", "build", "--wheel", "--no-isolation"], cwd=wheel
    )
    if process.returncode != 0:
        # If the build without isolation fails, try to build it again with
        # isolation. We need to protect this following logic in two ways:
        #   1. Only build one at a time in this process.
        #   2. Retry a few times to get around flakiness.
        success = False
        for _ in range(0, 3):
            with mutex:
                process = subprocess.run(
                    [sys.executable, "-m", "build", "--wheel"],
                    encoding="utf-8",
                    cwd=wheel,
                    capture_output=True,
                )
                if process.returncode != 0:
                    continue
                success = True
                break
        if not success:
            print("STDOUT:", file=sys.stderr)
            print(process.stdout, file=sys.stderr)
            print("STDERR:", file=sys.stderr)
            print(process.stderr, file=sys.stderr)
            raise RuntimeError(
                "{}: ERROR: failed to build {}".format(datetime.now(), wheel)
            )


def main(jobs, wheels):
    with multiprocessing.Pool(jobs) as pool:
        results = []
        for wheel in wheels:
            result = pool.apply_async(build, args=(wheel,))
            results.append(result)
        pool.close()
        for result in results:
            result.get()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Builds Python wheels.")
    parser.add_argument(
        "wheels",
        metavar="wheel",
        type=str,
        nargs="+",
        help="A path to the extracted wheel directory.",
    )
    parser.add_argument(
        "--jobs",
        type=int,
        default=8,
        help="The number of concurrent build jobs to be executed.",
    )
    args = parser.parse_args()
    exit(main(args.jobs, args.wheels))
