import argparse
import os
import sys
import tempfile

import requests
import twine.cli
import twine.exceptions


def main():
    parser = argparse.ArgumentParser(description='Pushes a Python wheel')
    parser.add_argument('--distribution', type=str)
    parser.add_argument('--python_tag', type=str)
    parser.add_argument('--abi', type=str)
    parser.add_argument('--platform', type=str)
    parser.add_argument('--wheel_file', type=str)
    parser.add_argument('--version_file', type=str)
    parser.add_argument('--repository', type=str)
    parser.add_argument('--repository_url', type=str)
    parser.add_argument('--non_interactive',
                        default=False,
                        action='store_true')
    parser.add_argument('--skip_existing', default=False, action='store_true')
    parser.add_argument('--verbose', default=False, action='store_true')
    args = parser.parse_args()

    with open(args.version_file, 'r') as stream:
        version = stream.read()

    compliant_wheel_file_name = '-'.join([
        args.distribution,
        version,
        args.python_tag,
        args.abi,
        args.platform,
    ]) + '.whl'

    if os.path.exists(compliant_wheel_file_name):
        os.remove(compliant_wheel_file_name)
    wheel_symlink = compliant_wheel_file_name
    os.symlink(args.wheel_file, wheel_symlink)

    twine_args = ['upload', compliant_wheel_file_name]

    if args.repository:
        twine_args.extend(['--repository', args.repository])
    if args.repository_url:
        twine_args.extend(['--repository-url', args.repository_url])
    if args.non_interactive:
        twine_args.append('--non-interactive')
        twine_args.extend(['--password', '""'])
    if args.skip_existing:
        twine_args.append('--skip-existing')
    if args.verbose:
        twine_args.append('--verbose')

    try:
        twine.cli.dispatch(twine_args)
    except (requests.HTTPError, twine.exceptions.TwineException) as ex:
        sys.exit(f'Failed to push the wheel! Reason: {ex}')


if __name__ == '__main__':
    main()
