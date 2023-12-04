import contextlib
import errno
import os
import sys
from http import server


def main(argv):
    build_workspace_directory = os.environ["BUILD_WORKSPACE_DIRECTORY"]
    docs_directory = argv[1]
    serve_directory = os.path.join(build_workspace_directory, docs_directory)

    class DirectoryHandler(server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(directory=serve_directory, *args, **kwargs)

    address = ("0.0.0.0", 8000)
    # with server.ThreadingHTTPServer(address, DirectoryHandler) as (ip, port, httpd):
    with _start_server(DirectoryHandler, "0.0.0.0", 8000) as (ip, port, httpd):
        print(f"Serving...")
        print(f"  Address: http://{ip}:{port}")
        print(f"  Serving directory: {serve_directory}")
        print(f"  CWD: {os.getcwd()}")
        print()
        print("*** You do not need to restart this server to see changes ***")
        print()
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
    return 0


@contextlib.contextmanager
def _start_server(handler, ip, start_port):
    for port in range(start_port, start_port + 10):
        try:
            with server.ThreadingHTTPServer((ip, port), handler) as httpd:
                yield ip, port, httpd
        except OSError as e:
            if e.errno == errno.EADDRINUSE:
                pass
            else:
                raise
    raise ValueError("Unable to find an available port")


if __name__ == "__main__":
    sys.exit(main(sys.argv))
