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

# Note the following pacakages are installed by pip install apache-beam
# apache-beam==2.13.0
# avro==1.9.0
# certifi==2019.3.9
# chardet==3.0.4
# crcmod==1.7
# dill==0.2.9
# docopt==0.6.2
# enum34==1.1.6
# fastavro==0.21.24
# funcsigs==1.0.2
# future==0.17.1
# futures==3.2.0
# grpcio==1.21.1
# hdfs==2.5.3
# httplib2==0.12.0
# idna==2.8
# mock==2.0.0
# numpy==1.16.4
# oauth2client==3.0.0
# pbr==5.2.1
# protobuf==3.8.0
# pyarrow==0.13.0
# pyasn1==0.4.5
# pyasn1-modules==0.2.5
# pydot==1.2.4
# pyparsing==2.4.0
# pytz==2019.1
# PyVCF==0.6.8
# PyYAML==3.13
# requests==2.22.0
# rsa==4.0
# six==1.12.0
# typing==3.6.6
# urllib3==1.25.3

import unittest
import apache_beam as beam
from apache_beam.testing import test_pipeline
from apache_beam.testing import util
from examples.dataflaw import dataflow


class HelloWorldTest(unittest.TestCase):

  def test_helloworld(self):
    p = test_pipeline.TestPipeline()
    output = p | beam.Create(["wow", "wow", "whatever"]) | beam.ParDo(
        dataflow.WordToOne()) | beam.GroupByKey() | beam.CombinePerKey(sum)
    util.assert_that(output, util.equal_to([("wow", 2), ("whatever", 1)]))


if __name__ == "__main__":
  unittest.main()
