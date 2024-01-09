raise ImportError(
    "@rules_python//src:__init__.py should not be imported or importable. "
    'You likely meant "import rules_python"'
)
