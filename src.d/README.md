# What is this directory

This directory is intended to be the sole entry added to sys.path for
the rules_python repo.

It's name, `src.d`, is chosen instead of the idiomatic `src` to help avoid
conflicting with consumer repos who happen to also have have directory
named "src" from which they might import code. Such a style isn't a good idea,
but rules_python, as a low-level dependency, is trying to avoid breaking things.
Because the name `src.d` isn't a valid Python module name, it's very unlikely
to occur in an import statement.
