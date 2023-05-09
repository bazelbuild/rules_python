# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import os
import shutil


def create_link(source, destination, fallback_copy=False):
    copy_function = _copy if fallback_copy else _link
    try:
        if os.path.isdir(source):
            os.makedirs(destination, exist_ok=True)
            shutil.copytree(
                source,
                destination,
                copy_function=copy_function,
                symlinks=True,
                dirs_exist_ok=True,
            )
        else:
            os.makedirs(os.path.dirname(destination), exist_ok=True)
            copy_function(source, destination)
    except OSError as e:
        if not fallback_copy:
            return create_link(source, destination, fallback_copy=True)
        print(f"Error creating link: {e}")


def _link(source, destination):
    os.link(source, destination, follow_symlinks=True)


def _copy(source, destination):
    shutil.copyfile(source, destination)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Create a hard link from --source to --destination"
    )
    parser.add_argument(
        "--source", required=True, help="Path to the source file or directory."
    )
    parser.add_argument(
        "--destination", required=True, help="Path to the destination hard link."
    )

    args = parser.parse_args()

    create_link(args.source, args.destination)
