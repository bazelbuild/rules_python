import websockets


def websockets_is_for_python_version(sanitized_version_check):
    return f"pypi_{sanitized_version_check}_websockets" in websockets.__file__
