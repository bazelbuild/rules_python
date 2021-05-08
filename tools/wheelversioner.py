import argparse
import sys


def get_version(version, info_file, version_file):
    if not version.startswith('{'):
        return version
    tag = version[1:-1]

    for candidate_file in [info_file, version_file]:
        with open(candidate_file, 'r') as stream:
            for line in stream:
                line_parts = line.split(' ')
                if line_parts[0] == tag:
                    return line_parts[1].rstrip()
    sys.exit(f'Failed to find \'{tag}\' in the workspace status!')


def main():
    parser = argparse.ArgumentParser(description='Versions a Python wheel')
    parser.add_argument('--version', type=str)
    parser.add_argument('--bazel_info_file', type=str)
    parser.add_argument('--bazel_version_file', type=str)
    parser.add_argument('--out', type=str)
    args = parser.parse_args()

    version = get_version(args.version, args.bazel_info_file,
                          args.bazel_version_file)

    with open(args.out, 'w') as stream:
        stream.write(version)


if __name__ == '__main__':
    main()
