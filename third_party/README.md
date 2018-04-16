# Vendored third_party software

All software is licensed and copyrighted as described by appropriate
license and copyright notices in its subdirectory.

## Implementation note

This directory intentionally does not have an `__init__.py` file.

## Updates

Run the following commands to update a third-party package:

``` shell
rm -r third_party/package_name*
pip install --target=third_party package_name
```

Then edit the files `tools/*wrapper.py`, updating the version number checks
under the line `# Sanity check that vendoring logic worked`.
