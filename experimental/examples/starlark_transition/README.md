This is a proof-of-concept for how the Python version could be set by a
Starlark-defined transition. This is not production ready for two reasons:

1) I believe Starlark-Based Configurations (SBC) aren't fully enabled yet.

2) SBC transitions append a config hash to the output directory name, unlike
   the native Python transition. This may lead to files appearing in a
   different place than the user expects.

Nonetheless, I'm putting it here for reference if we want to use it. Try
running `blaze run :bar` in this directory. Then switch which data dep is
commented out in `BUILD`, and rerun the command.
