#! /usr/bin/env python3

# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""
Provides an `id` implementation.
"""

from __future__ import annotations

from argparse import ArgumentParser
from os import getuid


def main():
    parser = ArgumentParser(
        prog="id", description="Print real and effective user and group IDs."
    )
    parser.add_argument(
        "-u",
        "--user",
        help="Print only the effective user ID.",
        action="store_true",
        required=True,
    )
    args = parser.parse_args()
    assert args.user

    print(getuid())


if __name__ == "__main__":
    main()
