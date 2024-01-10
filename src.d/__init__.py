raise ImportError(
    "@rules_python//src.d:__init__.py should not be imported or importable. "
    'You likely meant "import rules_python"'
)
