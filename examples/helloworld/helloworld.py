# Copyright 2017 The Bazel Authors. All rights reserved.
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

from concurrent import futures


class HelloWorld(object):
  def __init__(self):
    self._threadpool = futures.ThreadPoolExecutor(max_workers=5)

  def SayHello(self):
    print("Hello World")

  def SayHelloAsync(self):
    self._threadpool.submit(self.SayHello)

  def Stop(self):
    self._threadpool.shutdown(wait = True)
