# gazelle:ignore abcdefg1,abcdefg2
# gazelle:ignore abcdefg3

import abcdefg1
import abcdefg2
import abcdefg3
import foo

_ = abcdefg1
_ = abcdefg2
_ = abcdefg3
_ = foo

try:
    # gazelle:ignore grpc
    import grpc

    grpc_available = True
except ImportError:
    grpc_available = False

_ = grpc
