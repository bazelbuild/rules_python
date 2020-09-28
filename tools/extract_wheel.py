import os
import sys
import argparse
from packaging.whl import Wheel


def main():
    parser = argparse.ArgumentParser(
        description='Extract wheels to directory.')

    parser.add_argument('--output', action='store',
                        help=('Output folder.'))

    parser.add_argument('wheels', nargs='+',
                        help=('Wheels to be extracted.'))

    args = parser.parse_args()

    for file in args.wheels:
        w = Wheel(file)
        w.expand(args.output)

    return 0


if __name__ == "__main__":
    sys.exit(main())
