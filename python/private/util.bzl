"""Functionality shared by multiple pieces of code."""

load("@bazel_skylib//lib:types.bzl", "types")

def copy_propagating_kwargs(from_kwargs, into_kwargs = None):
    """Copies args that must be compatible between two targets with a dependency relationship.

    This is intended for when one target depends on another, so they must have
    compatible settings such as `testonly` and `compatible_with`. This usually
    happens when a macro generates multiple targets, some of which depend
    on one another, so their settings must be compatible.

    Args:
        from_kwargs: keyword args dict whose common kwarg will be copied.
        into_kwargs: optional keyword args dict that the values from `from_kwargs`
            will be copied into. The values in this dict will take precedence
            over the ones in `from_kwargs` (i.e., if this has `testonly` already
            set, then it won't be overwritten).
            NOTE: THIS WILL BE MODIFIED IN-PLACE.

    Returns:
        Keyword args to use for the depender target derived from the dependency
        target. If `into_kwargs` was passed in, then that same object is
        returned; this is to facilitate easy `**` expansion.
    """
    if into_kwargs == None:
        into_kwargs = {}

    # Include tags because people generally expect tags to propagate.
    for attr in ("testonly", "tags", "compatible_with", "restricted_to"):
        if attr in from_kwargs and attr not in into_kwargs:
            into_kwargs[attr] = from_kwargs[attr]
    return into_kwargs

# The implementation of the macros and tagging mechanism follows the example
# set by rules_cc and rules_java.

_MIGRATION_TAG = "__PYTHON_RULES_MIGRATION_DO_NOT_USE_WILL_BREAK__"

def add_migration_tag(attrs):
    """Add a special tag to `attrs` to aid migration off native rles.

    Args:
        attrs: dict of keyword args. The `tags` key will be modified in-place.

    Returns:
        The same `attrs` object, but modified.
    """
    if "tags" in attrs and attrs["tags"] != None:
        tags = attrs["tags"]

        # Preserve the input type: this allows a test verifying the underlying
        # rule can accept the tuple for the tags argument.
        if types.is_tuple(tags):
            attrs["tags"] = tags + (_MIGRATION_TAG,)
        else:
            attrs["tags"] = tags + [_MIGRATION_TAG]
    else:
        attrs["tags"] = [_MIGRATION_TAG]
    return attrs
