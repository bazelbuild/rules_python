Downloaded wheels are removed after extraction when their original archive can
be fetched independently. The existing `whl` and `whl_file` targets fetch the
archive from a separate repository on demand. Patched wheels and wheels built
from source retain their existing archive behavior.
