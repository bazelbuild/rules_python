# Copyright 2022 The Bazel Authors. All rights reserved.
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

"""The Python versions we use for the toolchains.
"""

# Values returned by https://bazel.build/rules/lib/repository_os.
MACOS_NAME = "mac os"
LINUX_NAME = "linux"
WINDOWS_NAME = "windows"

DEFAULT_RELEASE_BASE_URL = "https://github.com/indygreg/python-build-standalone/releases/download"

# When updating the versions and releases, run the following command to get
# the hashes:
#   bazel run //python/private:print_toolchains_checksums
#
# Note, to users looking at how to specify their tool versions, coverage_tool version for each
# interpreter can be specified by:
#   "3.8.10": {
#       "url": "20210506/cpython-{python_version}-{platform}-pgo+lto-20210506T0943.tar.zst",
#       "sha256": {
#           "x86_64-apple-darwin": "8d06bec08db8cdd0f64f4f05ee892cf2fcbc58cfb1dd69da2caab78fac420238",
#           "x86_64-unknown-linux-gnu": "aec8c4c53373b90be7e2131093caa26063be6d9d826f599c935c0e1042af3355",
#       },
#       "coverage_tool": {
#           "x86_64-apple-darwin": "<label_for_darwin>"",
#           "x86_64-unknown-linux-gnu": "<label_for_linux>"",
#       },
#       "strip_prefix": "python",
#   },
#
# It is possible to provide lists in "url".
#
# buildifier: disable=unsorted-dict-items
TOOL_VERSIONS = {
    "3.8.10": {
        "url": "20210506/cpython-{python_version}-{platform}-pgo+lto-20210506T0943.tar.zst",
        "sha256": {
            "x86_64-apple-darwin": "8d06bec08db8cdd0f64f4f05ee892cf2fcbc58cfb1dd69da2caab78fac420238",
            "x86_64-unknown-linux-gnu": "aec8c4c53373b90be7e2131093caa26063be6d9d826f599c935c0e1042af3355",
        },
        "strip_prefix": "python",
    },
    "3.8.12": {
        "url": "20220227/cpython-{python_version}+20220227-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "f9a3cbb81e0463d6615125964762d133387d561b226a30199f5b039b20f1d944",
            # no aarch64-unknown-linux-gnu build available for 3.8.12
            "x86_64-apple-darwin": "f323fbc558035c13a85ce2267d0fad9e89282268ecb810e364fff1d0a079d525",
            "x86_64-pc-windows-msvc": "4658e08a00d60b1e01559b74d58ff4dd04da6df935d55f6268a15d6d0a679d74",
            "x86_64-unknown-linux-gnu": "5be9c6d61e238b90dfd94755051c0d3a2d8023ebffdb4b0fa4e8fedd09a6cab6",
        },
        "strip_prefix": "python",
    },
    "3.8.13": {
        "url": "20220802/cpython-{python_version}+20220802-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "ae4131253d890b013171cb5f7b03cadc585ae263719506f7b7e063a7cf6fde76",
            # no aarch64-unknown-linux-gnu build available for 3.8.13
            "x86_64-apple-darwin": "cd6e7c0a27daf7df00f6882eaba01490dd963f698e99aeee9706877333e0df69",
            "x86_64-pc-windows-msvc": "f20643f1b3e263a56287319aea5c3888530c09ad9de3a5629b1a5d207807e6b9",
            "x86_64-unknown-linux-gnu": "fb566629ccb5f76ef56d275a3f8017d683f1c20c5beb5d5f38b155ed11e16187",
        },
        "strip_prefix": "python",
    },
    "3.8.15": {
        "url": "20221106/cpython-{python_version}+20221106-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "1e0a92d1a4f5e6d4a99f86b1cbf9773d703fe7fd032590f3e9c285c7a5eeb00a",
            "aarch64-unknown-linux-gnu": "886ab33ced13c84bf59ce8ff79eba6448365bfcafea1bf415bd1d75e21b690aa",
            "x86_64-apple-darwin": "70b57f28c2b5e1e3dd89f0d30edd5bc414e8b20195766cf328e1b26bed7890e1",
            "x86_64-pc-windows-msvc": "2fdc3fa1c95f982179bbbaedae2b328197658638799b6dcb63f9f494b0de59e2",
            "x86_64-unknown-linux-gnu": "e47edfb2ceaf43fc699e20c179ec428b6f3e497cf8e2dcd8e9c936d4b96b1e56",
        },
        "strip_prefix": "python",
    },
    "3.8.16": {
        "url": "20230116/cpython-{python_version}+20230116-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "d1f408569d8807c1053939d7822b082a17545e363697e1ce3cfb1ee75834c7be",
            "aarch64-unknown-linux-gnu": "15d00bc8400ed6d94c665a797dc8ed7a491ae25c5022e738dcd665cd29beec42",
            "x86_64-apple-darwin": "484ba901f64fc7888bec5994eb49343dc3f9d00ed43df17ee9c40935aad4aa18",
            "x86_64-pc-windows-msvc": "b446bec833eaba1bac9063bb9b4aeadfdf67fa81783b4487a90c56d408fb7994",
            "x86_64-unknown-linux-gnu": "c890de112f1ae31283a31fefd2061d5c97bdd4d1bdd795552c7abddef2697ea1",
        },
        "strip_prefix": "python",
    },
    "3.8.17": {
        "url": "20230826/cpython-{python_version}+20230826-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "c6f7a130d0044a78e39648f4dae56dcff5a41eba91888a99f6e560507162e6a1",
            "aarch64-unknown-linux-gnu": "9f6d585091fe26906ff1dbb80437a3fe37a1e3db34d6ecc0098f3d6a78356682",
            "x86_64-apple-darwin": "155b06821607bae1a58ecc60a7d036b358c766f19e493b8876190765c883a5c2",
            "x86_64-pc-windows-msvc": "6428e1b4e0b4482d390828de7d4c82815257443416cb786abe10cb2466ca68cd",
            "x86_64-unknown-linux-gnu": "8d3e1826c0bb7821ec63288038644808a2d45553245af106c685ef5892fabcd8",
        },
        "strip_prefix": "python",
    },
    "3.8.18": {
        "url": "20231002/cpython-{python_version}+20231002-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "1825b1f7220bc93ff143f2e70b5c6a79c6469e0eeb40824e07a7277f59aabfda",
            "aarch64-unknown-linux-gnu": "236a300f386ead02ca98dbddbc026ff4ef4de6701a394106e291ff8b75445ee1",
            "x86_64-apple-darwin": "fcf04532e644644213977242cd724fe5e84c0a5ac92ae038e07f1b01b474fca3",
            "x86_64-pc-windows-msvc": "a9d203e78caed94de368d154e841610cef6f6b484738573f4ae9059d37e898a5",
            "x86_64-unknown-linux-gnu": "1e8a3babd1500111359b0f5675d770984bcbcb2cc8890b117394f0ed342fb9ec",
        },
        "strip_prefix": "python",
    },
    "3.9.10": {
        "url": "20220227/cpython-{python_version}+20220227-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "ad66c2a3e7263147e046a32694de7b897a46fb0124409d29d3a93ede631c8aee",
            "aarch64-unknown-linux-gnu": "12dd1f125762f47975990ec744532a1cf3db74ad60f4dfb476ca42deb7f78ca4",
            "x86_64-apple-darwin": "fdaf594142446029e314a9beb91f1ac75af866320b50b8b968181e592550cd68",
            "x86_64-pc-windows-msvc": "c145d9d8143ce163670af124b623d7a2405143a3708b033b4d33eed355e61b24",
            "x86_64-unknown-linux-gnu": "455089cc576bd9a58db45e919d1fc867ecdbb0208067dffc845cc9bbf0701b70",
        },
        "strip_prefix": "python",
    },
    "3.9.12": {
        "url": "20220502/cpython-{python_version}+20220502-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "8dee06c07cc6429df34b6abe091a4684a86f7cec76f5d1ccc1c3ce2bd11168df",
            "aarch64-unknown-linux-gnu": "2ee1426c181e65133e57dc55c6a685cb1fb5e63ef02d684b8a667d5c031c4203",
            "x86_64-apple-darwin": "2453ba7f76b3df3310353b48c881d6cff622ba06e30d2b6ae91588b2bc9e481a",
            "x86_64-pc-windows-msvc": "3024147fd987d9e1b064a3d94932178ff8e0fe98cfea955704213c0762fee8df",
            "x86_64-unknown-linux-gnu": "ccca12f698b3b810d79c52f007078f520d588232a36bc12ede944ec3ea417816",
        },
        "strip_prefix": "python",
    },
    "3.9.13": {
        "url": "20220802/cpython-{python_version}+20220802-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "d9603edc296a2dcbc59d7ada780fd12527f05c3e0b99f7545112daf11636d6e5",
            "aarch64-unknown-linux-gnu": "80415aac1b96255b9211f6a4c300f31e9940c7e07a23d0dec12b53aa52c0d25e",
            "x86_64-apple-darwin": "9540a7efb7c8a54a48aff1cb9480e49588d9c0a3f934ad53f5b167338174afa3",
            "x86_64-pc-windows-msvc": "b538127025a467c64b3351babca2e4d2ea7bdfb7867d5febb3529c34456cdcd4",
            "x86_64-unknown-linux-gnu": "ce1cfca2715e7e646dd618a8cb9baff93000e345ccc979b801fc6ccde7ce97df",
        },
        "strip_prefix": "python",
    },
    "3.9.15": {
        "url": "20221106/cpython-{python_version}+20221106-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "64dc7e1013481c9864152c3dd806c41144c79d5e9cd3140e185c6a5060bdc9ab",
            "aarch64-unknown-linux-gnu": "52a8c0a67fb919f80962d992da1bddb511cdf92faf382701ce7673e10a8ff98f",
            "x86_64-apple-darwin": "f2bcade6fc976c472f18f2b3204d67202d43ae55cf6f9e670f95e488f780da08",
            "x86_64-pc-windows-msvc": "022daacab215679b87f0d200d08b9068a721605fa4721ebeda38220fc641ccf6",
            "x86_64-unknown-linux-gnu": "cdc3a4cfddcd63b6cebdd75b14970e02d8ef0ac5be4d350e57ab5df56c19e85e",
        },
        "strip_prefix": "python",
    },
    "3.9.16": {
        "url": "20230507/cpython-{python_version}+20230507-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "c1de1d854717a6245f45262ef1bb17b09e2c587590e7e3f406593c143ff875bd",
            "aarch64-unknown-linux-gnu": "f629b75ebfcafe9ceee2e796b7e4df5cf8dbd14f3c021afca078d159ab797acf",
            "ppc64le-unknown-linux-gnu": "ff3ac35c58f67839aff9b5185a976abd3d1abbe61af02089f7105e876c1fe284",
            "x86_64-apple-darwin": "3abc4d5fbbc80f5f848f280927ac5d13de8dc03aabb6ae65d8247cbb68e6f6bf",
            "x86_64-pc-windows-msvc": "cdabb47204e96ce7ea31fbd0b5ed586114dd7d8f8eddf60a509a7f70b48a1c5e",
            "x86_64-unknown-linux-gnu": "2b6e146234a4ef2a8946081fc3fbfffe0765b80b690425a49ebe40b47c33445b",
        },
        "strip_prefix": "python",
    },
    "3.9.17": {
        "url": "20230726/cpython-{python_version}+20230726-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "73dbe2d702210b566221da9265acc274ba15275c5d0d1fa327f44ad86cde9aa1",
            "aarch64-unknown-linux-gnu": "b77012ddaf7e0673e4aa4b1c5085275a06eee2d66f33442b5c54a12b62b96cbe",
            "ppc64le-unknown-linux-gnu": "c591a28d943dce5cf9833e916125fdfbeb3120270c4866ee214493ccb5b83c3c",
            "s390x-unknown-linux-gnu": "01454d7cc7c9c2fccde42ba868c4f372eaaafa48049d49dd94c9cf2875f497e6",
            "x86_64-apple-darwin": "dfe1bea92c94b9cb779288b0b06e39157c5ff7e465cdd24032ac147c2af485c0",
            "x86_64-pc-windows-msvc": "9b9a1e21eff29dcf043cea38180cf8ca3604b90117d00062a7b31605d4157714",
            "x86_64-unknown-linux-gnu": "26c4a712b4b8e11ed5c027db5654eb12927c02da4857b777afb98f7a930ce637",
        },
        "strip_prefix": "python",
    },
    "3.9.18": {
        "url": "20231002/cpython-{python_version}+20231002-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "fdc4054837e37b69798c2ef796222a480bc1f80e8ad3a01a95d0168d8282a007",
            "aarch64-unknown-linux-gnu": "1e0a3e8ce8e58901a259748c0ab640d2b8294713782d14229e882c6898b2fb36",
            "ppc64le-unknown-linux-gnu": "101c38b22fb2f5a0945156da4259c8e9efa0c08de9d7f59afa51e7ce6e22a1cc",
            "s390x-unknown-linux-gnu": "eee31e55ffbc1f460d7b17f05dd89e45a2636f374a6f8dc29ea13d0497f7f586",
            "x86_64-apple-darwin": "82231cb77d4a5c8081a1a1d5b8ae440abe6993514eb77a926c826e9a69a94fb1",
            "x86_64-pc-windows-msvc": "02ea7bb64524886bd2b05d6b6be4401035e4ba4319146f274f0bcd992822cd75",
            "x86_64-unknown-linux-gnu": "f3ff38b1ccae7dcebd8bbf2e533c9a984fac881de0ffd1636fbb61842bd924de",
        },
        "strip_prefix": "python",
    },
    "3.10.2": {
        "url": "20220227/cpython-{python_version}+20220227-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "1409acd9a506e2d1d3b65c1488db4e40d8f19d09a7df099667c87a506f71c0ef",
            "aarch64-unknown-linux-gnu": "8f351a8cc348bb45c0f95b8634c8345ec6e749e483384188ad865b7428342703",
            "x86_64-apple-darwin": "8146ad4390710ec69b316a5649912df0247d35f4a42e2aa9615bffd87b3e235a",
            "x86_64-pc-windows-msvc": "a1d9a594cd3103baa24937ad9150c1a389544b4350e859200b3e5c036ac352bd",
            "x86_64-unknown-linux-gnu": "9b64eca2a94f7aff9409ad70bdaa7fbbf8148692662e764401883957943620dd",
        },
        "strip_prefix": "python",
    },
    "3.10.4": {
        "url": "20220502/cpython-{python_version}+20220502-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "2c99983d1e83e4b6e7411ed9334019f193fba626344a50c36fba6c25d4de78a2",
            "aarch64-unknown-linux-gnu": "d8098c0c54546637e7516f93b13403b11f9db285def8d7abd825c31407a13d7e",
            "x86_64-apple-darwin": "f2711eaffff3477826a401d09a013c6802f11c04c63ab3686aa72664f1216a05",
            "x86_64-pc-windows-msvc": "bee24a3a5c83325215521d261d73a5207ab7060ef3481f76f69b4366744eb81d",
            "x86_64-unknown-linux-gnu": "f6f871e53a7b1469c13f9bd7920ad98c4589e549acad8e5a1e14760fff3dd5c9",
        },
        "strip_prefix": "python",
    },
    "3.10.6": {
        "url": "20220802/cpython-{python_version}+20220802-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "efaf66acdb9a4eb33d57702607d2e667b1a319d58c167a43c96896b97419b8b7",
            "aarch64-unknown-linux-gnu": "81625f5c97f61e2e3d7e9f62c484b1aa5311f21bd6545451714b949a29da5435",
            "x86_64-apple-darwin": "7718411adf3ea1480f3f018a643eb0550282aefe39e5ecb3f363a4a566a9398c",
            "x86_64-pc-windows-msvc": "91889a7dbdceea585ff4d3b7856a6bb8f8a4eca83a0ff52a73542c2e67220eaa",
            "x86_64-unknown-linux-gnu": "55aa2190d28dcfdf414d96dc5dcea9fe048fadcd583dc3981fec020869826111",
        },
        "strip_prefix": "python",
    },
    "3.10.8": {
        "url": "20221106/cpython-{python_version}+20221106-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "d52b03817bd245d28e0a8b2f715716cd0fcd112820ccff745636932c76afa20a",
            "aarch64-unknown-linux-gnu": "33170bef18c811906b738be530f934640491b065bf16c4d276c6515321918132",
            "x86_64-apple-darwin": "525b79c7ce5de90ab66bd07b0ac1008bafa147ddc8a41bef15ffb7c9c1e9e7c5",
            "x86_64-pc-windows-msvc": "f2b6d2f77118f06dd2ca04dae1175e44aaa5077a5ed8ddc63333c15347182bfe",
            "x86_64-unknown-linux-gnu": "6c8db44ae0e18e320320bbaaafd2d69cde8bfea171ae2d651b7993d1396260b7",
        },
        "strip_prefix": "python",
    },
    "3.10.9": {
        "url": "20230116/cpython-{python_version}+20230116-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "018d05a779b2de7a476f3b3ff2d10f503d69d14efcedd0774e6dab8c22ef84ff",
            "aarch64-unknown-linux-gnu": "2003750f40cd09d4bf7a850342613992f8d9454f03b3c067989911fb37e7a4d1",
            "x86_64-apple-darwin": "0e685f98dce0e5bc8da93c7081f4e6c10219792e223e4b5886730fd73a7ba4c6",
            "x86_64-pc-windows-msvc": "59c6970cecb357dc1d8554bd0540eb81ee7f6d16a07acf3d14ed294ece02c035",
            "x86_64-unknown-linux-gnu": "d196347aeb701a53fe2bb2b095abec38d27d0fa0443f8a1c2023a1bed6e18cdf",
        },
        "strip_prefix": "python",
    },
    "3.10.11": {
        "url": "20230507/cpython-{python_version}+20230507-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "8348bc3c2311f94ec63751fb71bd0108174be1c4def002773cf519ee1506f96f",
            "aarch64-unknown-linux-gnu": "c7573fdb00239f86b22ea0e8e926ca881d24fde5e5890851339911d76110bc35",
            "ppc64le-unknown-linux-gnu": "73a9d4c89ed51be39dd2de4e235078281087283e9fdedef65bec02f503e906ee",
            "x86_64-apple-darwin": "bd3fc6e4da6f4033ebf19d66704e73b0804c22641ddae10bbe347c48f82374ad",
            "x86_64-pc-windows-msvc": "9c2d3604a06fcd422289df73015cd00e7271d90de28d2c910f0e2309a7f73a68",
            "x86_64-unknown-linux-gnu": "c5bcaac91bc80bfc29cf510669ecad12d506035ecb3ad85ef213416d54aecd79",
        },
        "strip_prefix": "python",
    },
    "3.10.12": {
        "url": "20230726/cpython-{python_version}+20230726-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "bc66c706ea8c5fc891635fda8f9da971a1a901d41342f6798c20ad0b2a25d1d6",
            "aarch64-unknown-linux-gnu": "fee80e221663eca5174bd794cb5047e40d3910dbeadcdf1f09d405a4c1c15fe4",
            "ppc64le-unknown-linux-gnu": "bb5e8cb0d2e44241725fa9b342238245503e7849917660006b0246a9c97b1d6c",
            "s390x-unknown-linux-gnu": "8d33d435ae6fb93ded7fc26798cc0a1a4f546a4e527012a1e2909cc314b332df",
            "x86_64-apple-darwin": "8a6e3ed973a671de468d9c691ed9cb2c3a4858c5defffcf0b08969fba9c1dd04",
            "x86_64-pc-windows-msvc": "c1a31c353ca44de7d1b1a3b6c55a823e9c1eed0423d4f9f66e617bdb1b608685",
            "x86_64-unknown-linux-gnu": "a476dbca9184df9fc69fe6309cda5ebaf031d27ca9e529852437c94ec1bc43d3",
        },
        "strip_prefix": "python",
    },
    "3.10.13": {
        "url": "20231002/cpython-{python_version}+20231002-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "fd027b1dedf1ea034cdaa272e91771bdf75ddef4c8653b05d224a0645aa2ca3c",
            "aarch64-unknown-linux-gnu": "8675915ff454ed2f1597e27794bc7df44f5933c26b94aa06af510fe91b58bb97",
            "ppc64le-unknown-linux-gnu": "f3f9c43eec1a0c3f72845d0b705da17a336d3906b7df212d2640b8f47e8ff375",
            "s390x-unknown-linux-gnu": "859f6cfe9aedb6e8858892fdc124037e83ab05f28d42a7acd314c6a16d6bd66c",
            "x86_64-apple-darwin": "be0b19b6af1f7d8c667e5abef5505ad06cf72e5a11bb5844970c395a7e5b1275",
            "x86_64-pc-windows-msvc": "b8d930ce0d04bda83037ad3653d7450f8907c88e24bb8255a29b8dab8930d6f1",
            "x86_64-unknown-linux-gnu": "5d0429c67c992da19ba3eb58b3acd0b35ec5e915b8cae9a4aa8ca565c423847a",
        },
        "strip_prefix": "python",
    },
    "3.11.1": {
        "url": "20230116/cpython-{python_version}+20230116-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "4918cdf1cab742a90f85318f88b8122aeaa2d04705803c7b6e78e81a3dd40f80",
            "aarch64-unknown-linux-gnu": "debf15783bdcb5530504f533d33fda75a7b905cec5361ae8f33da5ba6599f8b4",
            "x86_64-apple-darwin": "20a4203d069dc9b710f70b09e7da2ce6f473d6b1110f9535fb6f4c469ed54733",
            "x86_64-pc-windows-msvc": "edc08979cb0666a597466176511529c049a6f0bba8adf70df441708f766de5bf",
            "x86_64-unknown-linux-gnu": "02a551fefab3750effd0e156c25446547c238688a32fabde2995c941c03a6423",
        },
        "strip_prefix": "python",
    },
    "3.11.3": {
        "url": "20230507/cpython-{python_version}+20230507-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "09e412506a8d63edbb6901742b54da9aa7faf120b8dbdce56c57b303fc892c86",
            "aarch64-unknown-linux-gnu": "8190accbbbbcf7620f1ff6d668e4dd090c639665d11188ce864b62554d40e5ab",
            "ppc64le-unknown-linux-gnu": "767d24f3570b35fedb945f5ac66224c8983f2d556ab83c5cfaa5f3666e9c212c",
            "x86_64-apple-darwin": "f710b8d60621308149c100d5175fec39274ed0b9c99645484fd93d1716ef4310",
            "x86_64-pc-windows-msvc": "24741066da6f35a7ff67bee65ce82eae870d84e1181843e64a7076d1571e95af",
            "x86_64-unknown-linux-gnu": "da50b87d1ec42b3cb577dfd22a3655e43a53150f4f98a4bfb40757c9d7839ab5",
        },
        "strip_prefix": "python",
    },
    "3.11.4": {
        "url": "20230726/cpython-{python_version}+20230726-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "cb6d2948384a857321f2aa40fa67744cd9676a330f08b6dad7070bda0b6120a4",
            "aarch64-unknown-linux-gnu": "2e84fc53f4e90e11963281c5c871f593abcb24fc796a50337fa516be99af02fb",
            "ppc64le-unknown-linux-gnu": "df7b92ed9cec96b3bb658fb586be947722ecd8e420fb23cee13d2e90abcfcf25",
            "s390x-unknown-linux-gnu": "e477f0749161f9aa7887964f089d9460a539f6b4a8fdab5166f898210e1a87a4",
            "x86_64-apple-darwin": "47e1557d93a42585972772e82661047ca5f608293158acb2778dccf120eabb00",
            "x86_64-pc-windows-msvc": "878614c03ea38538ae2f758e36c85d2c0eb1eaaca86cd400ff8c76693ee0b3e1",
            "x86_64-unknown-linux-gnu": "e26247302bc8e9083a43ce9e8dd94905b40d464745b1603041f7bc9a93c65d05",
        },
        "strip_prefix": "python",
    },
    "3.11.5": {
        "url": "20230826/cpython-{python_version}+20230826-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "dab64b3580118ad2073babd7c29fd2053b616479df5c107d31fe2af1f45e948b",
            "aarch64-unknown-linux-gnu": "bb5c5d1ea0f199fe2d3f0996fff4b48ca6ddc415a3dbd98f50bff7fce48aac80",
            "ppc64le-unknown-linux-gnu": "14121b53e9c8c6d0741f911ae00102a35adbcf5c3cdf732687ef7617b7d7304d",
            "s390x-unknown-linux-gnu": "fe459da39874443579d6fe88c68777c6d3e331038e1fb92a0451879fb6beb16d",
            "x86_64-apple-darwin": "4a4efa7378c72f1dd8ebcce1afb99b24c01b07023aa6b8fea50eaedb50bf2bfc",
            "x86_64-pc-windows-msvc": "00f002263efc8aea896bcfaaf906b1f4dab3e5cd3db53e2b69ab9a10ba220b97",
            "x86_64-unknown-linux-gnu": "fbed6f7694b2faae5d7c401a856219c945397f772eea5ca50c6eb825cbc9d1e1",
        },
        "strip_prefix": "python",
    },
    "3.11.6": {
        "url": "20231002/cpython-{python_version}+20231002-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "916c35125b5d8323a21526d7a9154ca626453f63d0878e95b9f613a95006c990",
            "aarch64-unknown-linux-gnu": "3e26a672df17708c4dc928475a5974c3fb3a34a9b45c65fb4bd1e50504cc84ec",
            "ppc64le-unknown-linux-gnu": "7937035f690a624dba4d014ffd20c342e843dd46f89b0b0a1e5726b85deb8eaf",
            "s390x-unknown-linux-gnu": "f9f19823dba3209cedc4647b00f46ed0177242917db20fb7fb539970e384531c",
            "x86_64-apple-darwin": "178cb1716c2abc25cb56ae915096c1a083e60abeba57af001996e8bc6ce1a371",
            "x86_64-pc-windows-msvc": "3933545e6d41462dd6a47e44133ea40995bc6efeed8c2e4cbdf1a699303e95ea",
            "x86_64-unknown-linux-gnu": "ee37a7eae6e80148c7e3abc56e48a397c1664f044920463ad0df0fc706eacea8",
        },
        "strip_prefix": "python",
    },
    "3.12.0": {
        "url": "20231002/cpython-{python_version}+20231002-{platform}-{build}.tar.gz",
        "sha256": {
            "aarch64-apple-darwin": "4734a2be2becb813830112c780c9879ac3aff111a0b0cd590e65ec7465774d02",
            "aarch64-unknown-linux-gnu": "bccfe67cf5465a3dfb0336f053966e2613a9bc85a6588c2fcf1366ef930c4f88",
            "ppc64le-unknown-linux-gnu": "b5dae075467ace32c594c7877fe6ebe0837681f814601d5d90ba4c0dfd87a1f2",
            "s390x-unknown-linux-gnu": "5681621349dd85d9726d1b67c84a9686ce78f72e73a6f9e4cc4119911655759e",
            "x86_64-apple-darwin": "5a9e88c8aa52b609d556777b52ebde464ae4b4f77e4aac4eb693af57395c9abf",
            "x86_64-pc-windows-msvc": "facfaa1fbc8653f95057f3c4a0f8aa833dab0e0b316e24ee8686bc761d4b4f8d",
            "x86_64-unknown-linux-gnu": "e51a5293f214053ddb4645b2c9f84542e2ef86870b8655704367bd4b29d39fe9",
        },
        "strip_prefix": "python",
    },
}

# buildifier: disable=unsorted-dict-items
MINOR_MAPPING = {
    "3.8": "3.8.18",
    "3.9": "3.9.18",
    "3.10": "3.10.13",
    "3.11": "3.11.6",
    "3.12": "3.12.0",
}

PLATFORMS = {
    "aarch64-apple-darwin": struct(
        compatible_with = [
            "@platforms//os:macos",
            "@platforms//cpu:aarch64",
        ],
        os_name = MACOS_NAME,
        # Matches the value returned from:
        # repository_ctx.execute(["uname", "-m"]).stdout.strip()
        arch = "arm64",
    ),
    "aarch64-unknown-linux-gnu": struct(
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:aarch64",
        ],
        os_name = LINUX_NAME,
        # Note: this string differs between OSX and Linux
        # Matches the value returned from:
        # repository_ctx.execute(["uname", "-m"]).stdout.strip()
        arch = "aarch64",
    ),
    "ppc64le-unknown-linux-gnu": struct(
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:ppc",
        ],
        os_name = LINUX_NAME,
        # Note: this string differs between OSX and Linux
        # Matches the value returned from:
        # repository_ctx.execute(["uname", "-m"]).stdout.strip()
        arch = "ppc64le",
    ),
    "s390x-unknown-linux-gnu": struct(
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:s390x",
        ],
        os_name = LINUX_NAME,
        # Note: this string differs between OSX and Linux
        # Matches the value returned from:
        # repository_ctx.execute(["uname", "-m"]).stdout.strip()
        arch = "s390x",
    ),
    "x86_64-apple-darwin": struct(
        compatible_with = [
            "@platforms//os:macos",
            "@platforms//cpu:x86_64",
        ],
        os_name = MACOS_NAME,
        arch = "x86_64",
    ),
    "x86_64-pc-windows-msvc": struct(
        compatible_with = [
            "@platforms//os:windows",
            "@platforms//cpu:x86_64",
        ],
        os_name = WINDOWS_NAME,
        arch = "x86_64",
    ),
    "x86_64-unknown-linux-gnu": struct(
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
        os_name = LINUX_NAME,
        arch = "x86_64",
    ),
}

def get_release_info(platform, python_version, base_url = DEFAULT_RELEASE_BASE_URL, tool_versions = TOOL_VERSIONS):
    """Resolve the release URL for the requested interpreter version

    Args:
        platform: The platform string for the interpreter
        python_version: The version of the intterpreter to get
        base_url: The URL to prepend to the 'url' attr in the tool_versions dict
        tool_versions: A dict listing the interpreter versions, their SHAs and URL

    Returns:
        A tuple of (filename, url, and archive strip prefix)
    """

    url = tool_versions[python_version]["url"]

    if type(url) == type({}):
        url = url[platform]

    if type(url) != type([]):
        url = [url]

    strip_prefix = tool_versions[python_version].get("strip_prefix", None)
    if type(strip_prefix) == type({}):
        strip_prefix = strip_prefix[platform]

    release_filename = None
    rendered_urls = []
    for u in url:
        release_filename = u.format(
            platform = platform,
            python_version = python_version,
            build = "shared-install_only" if (WINDOWS_NAME in platform) else "install_only",
        )
        if "://" in release_filename:  # is absolute url?
            rendered_urls.append(release_filename)
        else:
            rendered_urls.append("/".join([base_url, release_filename]))

    if release_filename == None:
        fail("release_filename should be set by now; were any download URLs given?")

    patches = tool_versions[python_version].get("patches", [])
    if type(patches) == type({}):
        if platform in patches.keys():
            patches = patches[platform]
        else:
            patches = []

    return (release_filename, rendered_urls, strip_prefix, patches)

def print_toolchains_checksums(name):
    native.genrule(
        name = name,
        srcs = [],
        outs = ["print_toolchains_checksums.sh"],
        cmd = """\
cat > "$@" <<'EOF'
#!/bin/bash

set -o errexit -o nounset -o pipefail

echo "Fetching hashes..."

{commands}
EOF
        """.format(
            commands = "\n".join([
                _commands_for_version(python_version)
                for python_version in TOOL_VERSIONS.keys()
            ]),
        ),
        executable = True,
    )

def _commands_for_version(python_version):
    return "\n".join([
        "echo \"{python_version}: {platform}: $$(curl --location --fail {release_url_sha256} 2>/dev/null || curl --location --fail {release_url} 2>/dev/null | shasum -a 256 | awk '{{ print $$1 }}')\"".format(
            python_version = python_version,
            platform = platform,
            release_url = release_url,
            release_url_sha256 = release_url + ".sha256",
        )
        for platform in TOOL_VERSIONS[python_version]["sha256"].keys()
        for release_url in get_release_info(platform, python_version)[1]
    ])

def gen_python_config_settings(name = ""):
    for platform in PLATFORMS.keys():
        native.config_setting(
            name = "{name}{platform}".format(name = name, platform = platform),
            constraint_values = PLATFORMS[platform].compatible_with,
        )
