try:
    import grpc

    grpc_available = True
except ImportError:
    grpc_available = False

_ = grpc
