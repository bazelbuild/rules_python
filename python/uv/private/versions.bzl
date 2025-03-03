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

"""Version and integrity information for downloaded artifacts"""

UV_PLATFORMS = {
    "aarch64-apple-darwin": struct(
        default_repo_name = "uv_darwin_aarch64",
        compatible_with = [
            "@platforms//os:macos",
            "@platforms//cpu:aarch64",
        ],
    ),
    "aarch64-unknown-linux-gnu": struct(
        default_repo_name = "uv_linux_aarch64",
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:aarch64",
        ],
    ),
    "powerpc64le-unknown-linux-gnu": struct(
        default_repo_name = "uv_linux_ppc",
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:ppc",
        ],
    ),
    "s390x-unknown-linux-gnu": struct(
        default_repo_name = "uv_linux_s390x",
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:s390x",
        ],
    ),
    "x86_64-apple-darwin": struct(
        default_repo_name = "uv_darwin_x86_64",
        compatible_with = [
            "@platforms//os:macos",
            "@platforms//cpu:x86_64",
        ],
    ),
    "x86_64-pc-windows-msvc": struct(
        default_repo_name = "uv_windows_x86_64",
        compatible_with = [
            "@platforms//os:windows",
            "@platforms//cpu:x86_64",
        ],
    ),
    "x86_64-unknown-linux-gnu": struct(
        default_repo_name = "uv_linux_x86_64",
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
    ),
}

# From: https://github.com/astral-sh/uv/releases
UV_TOOL_VERSIONS = {
    "0.6.3": {
        "aarch64-apple-darwin": struct(
            sha256 = "51b84818bbfe08358a298ba3389c6d448d3ddc0f2601a2d63c5a62cb7b704062",
        ),
        "aarch64-unknown-linux-gnu": struct(
            sha256 = "447726788204106ffd8ecc59396fccc75fae7aca998555265b5ea6950b00160c",
        ),
        "powerpc64le-unknown-linux-gnu": struct(
            sha256 = "e41eec560bd166f5bd155772ef120ec7220a80dcb4b70e71d8f4781276c5d102",
        ),
        "s390x-unknown-linux-gnu": struct(
            sha256 = "2c3c03d95c20adb2e521efaeddf6f9947c427c5e8140e38585595f3c947cebed",
        ),
        "x86_64-apple-darwin": struct(
            sha256 = "a675d2d0fcf533f89f4b584bfa8ee3173a1ffbc87d9d1d48fcc3abb8c55d946d",
        ),
        "x86_64-pc-windows-msvc": struct(
            sha256 = "40b50b3da3cf74dc5717802acd076b4669b6d7d2c91c4482875b4e5e46c62ba3",
        ),
        "x86_64-unknown-linux-gnu": struct(
            sha256 = "b7a37a33d62cb7672716c695226450231e8c02a8eb2b468fa61cd28a8f86eab2",
        ),
    },
    "0.6.2": {
        "aarch64-apple-darwin": struct(
            sha256 = "4af802a1216053650dd82eee85ea4241994f432937d41c8b0bc90f2639e6ae14",
        ),
        "aarch64-unknown-linux-gnu": struct(
            sha256 = "ca4c08724764a2b6c8f2173c4e3ca9dcde0d9d328e73b4d725cfb6b17a925eed",
        ),
        "powerpc64le-unknown-linux-gnu": struct(
            sha256 = "f341fd4874d2d007135626a0657d1478f331a78991d8a1a06aaa0d52fbe16183",
        ),
        "s390x-unknown-linux-gnu": struct(
            sha256 = "17fd89bd8de75da9c91baf918b8079c1f1f92bb6a398f0cfbc5ddefe0c7f0ee5",
        ),
        "x86_64-apple-darwin": struct(
            sha256 = "2b9e78b2562aea93f13e42df1177cb07c59a4d4f1c8ff8907d0c31f3a5e5e8db",
        ),
        "x86_64-pc-windows-msvc": struct(
            sha256 = "5f33c3cc5c183775cc51b3e661a0d2ce31142d32a50406a67c7ad0321fc841d9",
        ),
        "x86_64-unknown-linux-gnu": struct(
            sha256 = "37ea31f099678a3bee56f8a757d73551aad43f8025d377a8dde80dd946c1b7f2",
        ),
    },
    "0.6.1": {
        "aarch64-apple-darwin": struct(
            sha256 = "90e10cc7f26cbaf3eaa867cf99344ffd550e942fd4b660e88f2f91c23022dc5a",
        ),
        "aarch64-unknown-linux-gnu": struct(
            sha256 = "f355989fb5ecf47c9f9087a0b21e2ee7d7c802bc3d0cf6edae07560d4297751f",
        ),
        "powerpc64le-unknown-linux-gnu": struct(
            sha256 = "becf4913112c475b2713df01a8c0536b38dc2c48f04b1d603cd6f0a74f88caa2",
        ),
        "s390x-unknown-linux-gnu": struct(
            sha256 = "ee687d56ba1e359a7a2e20e301b992b83882df5ffb1409d301e1b0d21b3fa16a",
        ),
        "x86_64-apple-darwin": struct(
            sha256 = "d8609b53f280d5e784a7586bf7a3fd90c557656af109cee8572b24a0c1443191",
        ),
        "x86_64-pc-windows-msvc": struct(
            sha256 = "32de1730597db0a7c5f34e2257ab491b660374b22c016c3d9a59ae279d837697",
        ),
        "x86_64-unknown-linux-gnu": struct(
            sha256 = "0dcad9831d3f10f3bc4dcd7678948dfc74c0b3ab3f07aa684eb9e5135b971a58",
        ),
    },
    "0.6.0": {
        "aarch64-apple-darwin": struct(
            sha256 = "ff4f1ec24a3adb3dd251f9523e4b7a7cba379e9896ae6ed1efa163fcdcd6af8a",
        ),
        "aarch64-unknown-linux-gnu": struct(
            sha256 = "47fa7ada7352f69a5efd19628b86b83c0bbda34541de3a4254ba75a188414953",
        ),
        "powerpc64le-unknown-linux-gnu": struct(
            sha256 = "d782751a6ec8a0775aa57087275225b6562a115004c1f41935bec1609765508d",
        ),
        "s390x-unknown-linux-gnu": struct(
            sha256 = "664f4165767a0cd808d1784d1d70243da4789024ec5cd779a861201b54a479b7",
        ),
        "x86_64-apple-darwin": struct(
            sha256 = "530ef3b6f563448e8e017a8cd6693d6c72c146fb0a3c43440bb0e93fcf36264f",
        ),
        "x86_64-pc-windows-msvc": struct(
            sha256 = "65836dae55d3a63e5fc1d51ae52e6ea175aaab1c82c4a6660d46462b27d19c2a",
        ),
        "x86_64-unknown-linux-gnu": struct(
            sha256 = "1a26ce241f7ff1f52634d869f86db533fffba21e528597029ee9d1423bf3df18",
        ),
    },
    "0.5.31": {
        "aarch64-apple-darwin": struct(
            sha256 = "396c9bd6acd98466fdb585da2ed040eecea15228e580d4bd649c09215b490bf9",
        ),
        "aarch64-unknown-linux-gnu": struct(
            sha256 = "e7f358efb0718bd8f98dc0c29fd0902323b590381ca765537063a2ca23ed34c7",
        ),
        "powerpc64le-unknown-linux-gnu": struct(
            sha256 = "e292dc0a7b23fab01bbf2b6fdddf8bb0c531805b1dbc3905637af70a88ff1f5f",
        ),
        "s390x-unknown-linux-gnu": struct(
            sha256 = "66232646bd15a38cf6877c6af6bf8668fadb2af910d7cf7a1159885487a15e70",
        ),
        "x86_64-apple-darwin": struct(
            sha256 = "5316b82da14fab9a76b3521c901e7c0a7d641fb9d28eb07874e26a00b0ac2725",
        ),
        "x86_64-pc-windows-msvc": struct(
            sha256 = "1ad54dace424c259b603ecd36262cb235af2bc8d6f280e24063d57919545f593",
        ),
        "x86_64-unknown-linux-gnu": struct(
            sha256 = "017ce7ed02c967f1b0489f09162e19ee3df4586a44e681211d16206e007fce62",
        ),
    },
    "0.5.30": {
        "aarch64-apple-darwin": struct(
            sha256 = "654c3e010c9c53b024fa752d08b949e0f80f10ec4e3a1acea9437a1d127a1053",
        ),
        "aarch64-unknown-linux-gnu": struct(
            sha256 = "d1ea4a2299768b2c8263db0abd8ea0de3b8052a34a51f5cf73094051456d4de2",
        ),
        "powerpc64le-unknown-linux-gnu": struct(
            sha256 = "b10ba261377f89e598322f3329beeada6b868119581e2a7294e7585351d3733f",
        ),
        "s390x-unknown-linux-gnu": struct(
            sha256 = "7341e6d62b0e02fbd33fe6ce0158e9f68617f43e5ec42fc6904d246bda5f6d34",
        ),
        "x86_64-apple-darwin": struct(
            sha256 = "42c4a5d3611928613342958652ab16943d05980b1ab5057bb47e4283ef7e890d",
        ),
        "x86_64-pc-windows-msvc": struct(
            sha256 = "43d6b97d2e283f6509a9199fd32411d67a64d5b5dca3e6e63e45ec2faec68f73",
        ),
        "x86_64-unknown-linux-gnu": struct(
            sha256 = "9d82816c14c44054f0c679f2bcaecfd910c75f207e08874085cb27b482f17776",
        ),
    },
    "0.5.29": {
        "aarch64-apple-darwin": struct(
            sha256 = "c89e96bde40402cc4db2f59bcb886882ab69e557235279283a2db9dea61135c3",
        ),
        "aarch64-unknown-linux-gnu": struct(
            sha256 = "d1f716e8362d7da654a154b8331054a987c1fc16562bd719190a42458e945785",
        ),
        "powerpc64le-unknown-linux-gnu": struct(
            sha256 = "0e38436e4068eec23498f88a5c1b721411986e6a983f243680a60b716b7c301c",
        ),
        "s390x-unknown-linux-gnu": struct(
            sha256 = "6a42886dd10c6437a1a56982cd0c116d063f05483aa7db1cc0343f705ef96f91",
        ),
        "x86_64-apple-darwin": struct(
            sha256 = "2f13ef5a82b91ba137fd6441f478c406a0a8b0df41e9573d1e61551a1de5a3a2",
        ),
        "x86_64-pc-windows-msvc": struct(
            sha256 = "2453b17df889822a5b8dcd3467dd6b75a410d61f5e6504362e3852fb3175c19c",
        ),
        "x86_64-unknown-linux-gnu": struct(
            sha256 = "46d3fcf04d64be42bded914d648657cd62d968172604e3aaf8386142c09d2317",
        ),
    },
    "0.5.28": {
        "aarch64-apple-darwin": struct(
            sha256 = "57cbf655a5bc5c1ffa7315c0b25ff342f44a919fa099311c0d994914011b421e",
        ),
        "aarch64-unknown-linux-gnu": struct(
            sha256 = "fe3c481940c5542d034a863239f23d64ee45abcd636c480c1ea0f34469a66c86",
        ),
        "powerpc64le-unknown-linux-gnu": struct(
            sha256 = "74bc6aacea26c67305910bcbe4b6178b96fefe643b2002567cc094ad2c209ef1",
        ),
        "s390x-unknown-linux-gnu": struct(
            sha256 = "b3f49b0268ab971ff7f39ca924fb8291ce3d8ffe8f6c0d7ff16bc12055cd1e85",
        ),
        "x86_64-apple-darwin": struct(
            sha256 = "36484907ec1988f1553bdc7de659d8bc0b46b8eaca09b0f67359b116caac170d",
        ),
        "x86_64-pc-windows-msvc": struct(
            sha256 = "31053741c49624726d5ce8cb1ab8f5fc267ed0333ab8257450bd71a7c2a68d05",
        ),
        "x86_64-unknown-linux-gnu": struct(
            sha256 = "1f2a654627e02fed5f8b883592439b842e74d98091bbafe9e71c7101f4f97d74",
        ),
    },
    "0.5.27": {
        "aarch64-apple-darwin": struct(
            sha256 = "efe367393fc02b8e8609c38bce78d743261d7fc885e5eabfbd08ce881816aea3",
        ),
        "aarch64-unknown-linux-gnu": struct(
            sha256 = "7b8175e7370056efa6e8f4c8fec854f3a026c0ecda628694f5200fdf666167fa",
        ),
        "powerpc64le-unknown-linux-gnu": struct(
            sha256 = "b63051bdd5392fa6a3d8d98c661b395c62a2a05a0e96ae877047c4c7be1b92ff",
        ),
        "s390x-unknown-linux-gnu": struct(
            sha256 = "07377ed611dbf1548f06b65ad6d2bb84f3ff1ccce936ba972d7b7f5492e47d30",
        ),
        "x86_64-apple-darwin": struct(
            sha256 = "a75c9d77c90c4ac367690134cd471108c09b95226c62cd6422ca0db8bbea2197",
        ),
        "x86_64-pc-windows-msvc": struct(
            sha256 = "195d43f6578c33838523bf4f3c80d690914496592b2946bda8598b8500e744f6",
        ),
        "x86_64-unknown-linux-gnu": struct(
            sha256 = "27261ddf7654d4f34ed4600348415e0c30de2a307cc6eff6a671a849263b2dcf",
        ),
    },
    "0.5.26": {
        "aarch64-apple-darwin": struct(
            sha256 = "3b503c630dc65b991502e1d9fe0ffc410ae50c503e8df6d4900f23b9ad436366",
        ),
        "aarch64-unknown-linux-gnu": struct(
            sha256 = "6ce061c2f14bf2f0b12c2b7a0f80c65408bf2dcee9743c4fc4ec1f30b85ecb98",
        ),
        "powerpc64le-unknown-linux-gnu": struct(
            sha256 = "fe1d770840110b59554228b12382881abefc1ab2d2ca009adc1502179422bc0d",
        ),
        "s390x-unknown-linux-gnu": struct(
            sha256 = "086c8d03ee4aff702a32d58086accf971ce58a2f000323414935e0f50e816c04",
        ),
        "x86_64-apple-darwin": struct(
            sha256 = "7cf20dd534545a74290a244d3e8244d1010ba38d2d5950f504b6c93fab169f57",
        ),
        "x86_64-pc-windows-msvc": struct(
            sha256 = "a938eebb7433eb7097ae1cf3d53f9bb083edd4c746045f284a1c8904af1a1a11",
        ),
        "x86_64-unknown-linux-gnu": struct(
            sha256 = "555f17717e7663109104b62976e9da6cfda1ad84213407b437fd9c8f573cc0ef",
        ),
    },
    "0.4.25": {
        "aarch64-apple-darwin": struct(
            sha256 = "bb2ff4348114ef220ca52e44d5086640c4a1a18f797a5f1ab6f8559fc37b1230",
        ),
        "aarch64-unknown-linux-gnu": struct(
            sha256 = "4485852eb8013530c4275cd222c0056ce123f92742321f012610f1b241463f39",
        ),
        "powerpc64le-unknown-linux-gnu": struct(
            sha256 = "32421c61e8d497243171b28c7efd74f039251256ae9e57ce4a457fdd7d045e24",
        ),
        "s390x-unknown-linux-gnu": struct(
            sha256 = "9afa342d87256f5178a592d3eeb44ece8a93e9359db37e31be1b092226338469",
        ),
        "x86_64-apple-darwin": struct(
            sha256 = "f0ec1f79f4791294382bff242691c6502e95853acef080ae3f7c367a8e1beb6f",
        ),
        "x86_64-pc-windows-msvc": struct(
            sha256 = "c5c7fa084ae4e8ac9e3b0b6c4c7b61e9355eb0c86801c4c7728c0cb142701f38",
        ),
        "x86_64-unknown-linux-gnu": struct(
            sha256 = "6cb6eaf711cd7ce5fb1efaa539c5906374c762af547707a2041c9f6fd207769a",
        ),
    },
}

