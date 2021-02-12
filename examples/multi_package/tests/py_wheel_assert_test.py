# Copyright 2021 The Bazel Authors. All rights reserved.
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

# This file is executed at runtime during test to assert the installed multi_package distribution
# works as expected.

import foo
import bar


def main():
    print("instantiating Foo")
    f = foo.Foo()
    print("asserting foo()")
    assert(f.foo() == 'foo')
    print("instantiating Bar")
    b = bar.Bar()
    print("asserting bar()")
    assert(b.bar() == 'bar')


if __name__ == '__main__':
    main()
