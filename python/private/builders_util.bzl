# Copyright 2025 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load("@bazel_skylib//lib:types.bzl", "types")

def kwargs_pop_dict(kwargs, key):
    """Get a dict value for a kwargs key.

    """
    existing = kwargs.pop(key, None)
    if existing == None:
        return {}
    else:
        return {
            k: v() if types.is_function(v) else v
            for k, v in existing.items()
        }

def kwargs_pop_list(kwargs, key):
    existing = kwargs.pop(key, None)
    if existing == None:
        return []
    else:
        return [
            v() if types.is_function(v) else v
            for v in existing
        ]

def kwargs_pop_doc(kwargs):
    return _Value_kwargs(kwargs, "doc", "")

def kwargs_pop_mandatory(kwargs):
    return _Value_kwargs(kwargs, "mandatory", False)

def to_kwargs_get_pairs(obj, existing_kwargs):
    """Partially converts attributes of `obj` to kwarg values.

    This is not a recursive function. Callers must manually handle:
    * Attributes that are lists/dicts of non-primitive values.
    * Attributes that are builders.

    Args:
        obj: A struct whose attributes to turn into kwarg vales.
        existing_kwargs: Existing kwarg values that should are already
            computed and this function should ignore.

    Returns:
        {type}`list[tuple[str, object | Builder]]` a list of key-value
        tuples, where the keys are kwarg names, and the values are
        a builder for the final value or the final kwarg value.
    """
    ignore_names = {"extra_kwargs": None}
    pairs = []
    for name in dir(obj):
        if name in ignore_names or name in existing_kwargs:
            continue
        value = getattr(obj, name)
        if types.is_function(value):
            continue  # Assume it's a method
        if _is_value_wrapper(value):
            value = value.get()
        elif _is_optional(value):
            if not value.present():
                continue
            else:
                value = value.get()

        # NOTE: We can't call value.build() here: it would likely lead to
        # recursion.
        pairs.append((name, value))
    return pairs

# To avoid recursion, this function shouldn't call `value.build()`.
# Recall that Bazel identifies recursion based on the (line, column) that
# a function (or lambda) is **defined** at -- the closure of variables
# is ignored. Thus, Bazel's recursion detection can be incidentally
# triggered if X.build() calls helper(), which calls Y.build(), which
# then calls helper() again -- helper() is indirectly recursive.
def common_to_kwargs_nobuilders(self, kwargs = None):
    """Convert attributes of `self` to kwargs.

    Args:
        self: the object whose attributes to convert.
        kwargs: An existing kwargs dict to populate.

    Returns:
        {type}`dict[str, object]` A new kwargs dict, or the passed-in `kwargs`
        if one was passed in.
    """
    if kwargs == None:
        kwargs = {}
    kwargs.update(self.extra_kwargs)
    for name, value in to_kwargs_get_pairs(self, kwargs):
        kwargs[name] = value

    return kwargs

def _Optional_typedef():
    """A wrapper for a re-assignable value that may or may not exist at all.

    This allows structs to have attributes whose values can be re-assigned,
    e.g. ints, strings, bools, or values where the presence matters.

    This is like {obj}`Value`, except it supports not having a value specified
    at all. This allows entirely omitting an argument when the arguments
    are constructed for calling e.g. `rule()`

    :::{function} clear()
    :::
    """

def _Optional_new(*initial):
    """Creates an instance.

    Args:
        *initial: Either zero, one, or two positional args to set the
            initial value stored for the optional.
            - If zero args, then no value is stored.
            - If one arg, then the arg is the value stored.
            - If two args, then the first arg is a kwargs dict, and the
              second arg is a name in kwargs to look for. If the name is
              present in kwargs, it is removed from kwargs and its value
              stored, otherwise kwargs is unmodified and no value is stored.

    Returns:
        {type}`Optional`
    """
    if len(initial) > 2:
        fail("Only zero, one, or two positional args allowed, but got: {}".format(initial))

    if len(initial) == 2:
        kwargs, name = initial
        if name in kwargs:
            initial = [kwargs.pop(name)]
        else:
            initial = []
    else:
        initial = list(initial)

    # buildifier: disable=uninitialized
    self = struct(
        # Length zero when no value; length one when has value.
        # NOTE: This name is load bearing: it indicates this is a Value
        # object; see _is_optional()
        _Optional_value = initial,
        present = lambda *a, **k: _Optional_present(self, *a, **k),
        clear = lambda: self.Optional_value.clear(),
        set = lambda *a, **k: _Optional_set(self, *a, **k),
        get = lambda *a, **k: _Optional_get(self, *a, **k),
    )
    return self

def _Optional_set(self, value):
    """Sets the value of the optional.

    Args:
        self: implicitly added
        value: the value to set.
    """
    if len(self._Optional_value) == 0:
        self._Optional_value.append(value)
    else:
        self._Optional_value[0] = value

def _Optional_get(self):
    """Gets the value of the optional, or error.

    Args:
        self: implicitly added

    Returns:
        The stored value, or error if not set.
    """
    if not len(self._Optional_value):
        fail("Value not present")
    return self._Optional_value[0]

def _Optional_present(self):
    """Tells if a value is present.

    Args:
        self: implicitly added

    Returns:
        {type}`bool` True if the value is set, False if not.
    """
    return len(self._Optional_value) > 0

def _is_optional(obj):
    return hasattr(obj, "_Optional_value")

Optional = struct(
    TYPEDEF = _Optional_typedef,
    new = _Optional_new,
    get = _Optional_get,
    set = _Optional_set,
    present = _Optional_present,
)

def _Value_typedef():
    """A wrapper for a re-assignable value that always has some value.

    This allows structs to have attributes whose values can be re-assigned,
    e.g. ints, strings, bools, etc.

    This is similar to Optional, except it will always have *some* value
    as a default (e.g. None, empty string, empty list, etc) that is OK to pass
    onto the rule(), attribute, etc function.

    :::{function} get() -> object
    :::
    """

def _Value_new(initial):
    # buildifier: disable=uninitialized
    self = struct(
        # NOTE: This name is load bearing: it indicates this is a Value
        # object; see _is_value_wrapper()
        _Value_value = [initial],
        get = lambda: self._Value_value[0],
        set = lambda v: _Value_set(self, v),
    )
    return self

def _Value_kwargs(kwargs, name, default):
    if name in kwargs:
        initial = kwargs[name]
    else:
        initial = default
    return _Value_new(initial)

def _Value_set(self, v):
    """Sets the value.

    Args:
        v: the value to set.
    """
    self._Value_value[0] = v

def _is_value_wrapper(obj):
    return hasattr(obj, "_Value_value")

Value = struct(
    TYPEDEF = _Value_typedef,
    new = _Value_new,
    kwargs = _Value_kwargs,
    set = _Value_set,
)

def _UniqueList_typedef():
    """A mutable list of unique values.

    Value are kept in insertion order.

    :::{function} update(*others) -> None
    :::

    :::{function} build() -> list
    """

def _UniqueList_new(kwargs, name):
    """Builder for list of unique values.

    Args:
        kwargs: {type}`dict[str, Any]` kwargs to search for `name`
        name: {type}`str` A key in `kwargs` to initialize the value
            to. If present, kwargs will be modified in place.
        initial: {type}`list | None` The initial values.

    Returns:
        {type}`UniqueList`
    """

    # TODO - Use set builtin instead of dict, when available.
    # https://bazel.build/rules/lib/core/set
    initial = {v: None for v in kwargs_pop_list(kwargs, name)}

    # buildifier: disable=uninitialized
    self = struct(
        _values = initial,
        update = lambda *a, **k: _UniqueList_update(self, *a, **k),
        build = lambda *a, **k: _UniqueList_build(self, *a, **k),
    )
    return self

def _UniqueList_build(self):
    """Builds the values into a list

    Returns:
        {type}`list`
    """
    return self._values.keys()

def _UniqueList_update(self, *others):
    """Adds values to the builder.

    Args:
        self: implicitly added
        *others: {type}`list` values to add to the set.
    """
    for other in others:
        for value in other:
            if value not in self._values:
                self._values[value] = None

UniqueList = struct(
    TYPEDEF = _UniqueList_typedef,
    new = _UniqueList_new,
)
