import os

import websockets


def websockets_relative_path():
    return os.path.relpath(websockets.__file__, start=os.curdir)
