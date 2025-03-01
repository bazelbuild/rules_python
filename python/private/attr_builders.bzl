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

"""Builders for creating attributes et al."""

load("@bazel_skylib//lib:types.bzl", "types")
load(
    ":builders_util.bzl",
    "Optional",
    "UniqueList",
    "Value",
    "common_to_kwargs_nobuilders",
    "kwargs_pop_dict",
    "kwargs_pop_doc",
    "kwargs_pop_list",
    "kwargs_pop_mandatory",
)

def _kwargs_pop_allow_empty(kwargs):
    return Value.kwargs(kwargs, "allow_empty", True)

def _AttrCfg_typedef():
    """Builder for `cfg` arg of label attributes.

    :::{function} implementation() -> callable | None

    Returns the implementation function when a custom transition is being used.
    :::

    :::{field} outputs
    :type: UniqueList[Label]
    :::

    :::{field} inputs
    :type: UniqueList[str | Label]
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]
    :::
    """

def _AttrCfg_new(outer_kwargs, name):
    """Creates a builder for the `attr.cfg` attribute.

    Args:
        outer_kwargs: {type}`dict` the kwargs to look for `name` within.
        name: {type}`str` a key to look for in `outer_kwargs` for the
            values to initilize from. If present in `outer_kwargs`, it
            will be removed and the value initializes the builder. The value
            is allowed to be one of:
            - The string `exec` or `target`
            - A dict with key `implementation`, which is a transition
              implementation function.
            - A dict with key `exec_group`, which is a string name for an
              exec group to use for an exec transition.

    Returns:
        {type}`AttrCfg`
    """
    cfg = outer_kwargs.pop(name, None)
    if cfg == None:
        kwargs = {}
    elif types.is_string(cfg):
        kwargs = {"cfg": cfg}
    else:
        # Assume its a dict
        kwargs = cfg

    if "cfg" in kwargs:
        initial = kwargs.pop("cfg")
        is_exec = False
    elif "exec_group" in kwargs:
        initial = kwargs.pop("exec_group")
        is_exec = True
    else:
        initial = None
        is_exec = False

    # buildifier: disable=uninitialized
    self = struct(
        # list of (value, bool is_exec)
        _implementation = [initial, is_exec],
        implementation = lambda: self._implementation[0],
        set_implementation = lambda *a, **k: _AttrCfg_set_implementation(self, *a, **k),
        set_exec = lambda *a, **k: _AttrCfg_set_exec(self, *a, **k),
        set_target = lambda: _AttrCfg_set_implementation(self, "target"),
        exec_group = lambda: _AttrCfg_exec_group(self),
        outputs = UniqueList.new(kwargs, "outputs"),
        inputs = UniqueList.new(kwargs, "inputs"),
        build = lambda: _AttrCfg_build(self),
        extra_kwargs = kwargs,
    )
    return self

def _AttrCfg_set_implementation(self, impl):
    """Sets a custom transition function to use.

    Args:
        impl: {type}`callable` a transition implementation function.
    """
    self._implementation[0] = impl
    self._implementation[1] = False

def _AttrCfg_set_exec(self, exec_group = None):
    """Sets to use an exec transition.

    Args:
        exec_group: {type}`str | None` the exec group name to use, if any.
    """
    self._implementation[0] = exec_group
    self._implementation[1] = True

def _AttrCfg_exec_group(self):
    """Tells the exec group to use if an exec transition is being used.

    Args:
        self: implicitly added.

    Returns:
        {type}`str | None` the name of the exec group to use if any.

    """
    if self._implementation[1]:
        return self._implementation[0]
    else:
        return None

def _AttrCfg_build(self):
    value, is_exec = self._implementation
    if value == None:
        return None
    elif is_exec:
        return config.exec(value)
    elif value == "target":
        return config.target()
    elif types.is_function(value):
        return transition(
            implementation = value,
            inputs = self.inputs.build(),
            outputs = self.outputs.build(),
        )
    else:
        # Otherwise, just assume the value is valid and whoever set it
        # knows what they're doing.
        return value

AttrCfg = struct(
    TYPEDEF = _AttrCfg_typedef,
    new = _AttrCfg_new,
    set_implementation = _AttrCfg_set_implementation,
    set_exec = _AttrCfg_set_exec,
    exec_group = _AttrCfg_exec_group,
)

def _Bool_typedef():
    """Builder fo attr.bool.

    :::{function} build() -> attr.bool
    :::

    :::{field} default
    :type: Value[bool]
    :::

    :::{field} doc
    :type: Value[str]
    :::

    :::{field} mandatory
    :type: Value[bool]
    :::

    :::{field} extra_kwargs
    :type: dict[str, object]
    :::
    """

def _Bool_new(**kwargs):
    """Creates a builder for `attr.bool`.

    Args:
        **kwargs: Same kwargs as {obj}`attr.bool`

    Returns:
        {type}`Bool`
    """

    # buildifier: disable=uninitialized
    self = struct(
        default = Value.kwargs(kwargs, "default", False),
        doc = kwargs_pop_doc(kwargs),
        mandatory = kwargs_pop_mandatory(kwargs),
        extra_kwargs = kwargs,
        build = lambda: attr.bool(**common_to_kwargs_nobuilders(self)),
    )
    return self

Bool = struct(
    TYPEDEF = _Bool_typedef,
    new = _Bool_new,
)

def _Int_typedef():
    """Builder for attr.int.

    :::{function} build() -> attr.int
    :::

    :::{field} default
    :type: Value[int]
    :::

    :::{field} doc
    :type: Value[str]
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]
    :::

    :::{field} mandatory
    :type: Value[bool]
    :::

    :::{field} values
    :type: list[int]
    :::
    """

def _Int_new(**kwargs):
    """Creates a builder for `attr.int`.

    Args:
        **kwargs: Same kwargs as {obj}`attr.int`

    Returns:
        {type}`Int`
    """

    # buildifier: disable=uninitialized
    self = struct(
        build = lambda: attr.int(**common_to_kwargs_nobuilders(self)),
        default = Value.kwargs(kwargs, "default", 0),
        doc = kwargs_pop_doc(kwargs),
        extra_kwargs = kwargs,
        mandatory = kwargs_pop_mandatory(kwargs),
        values = kwargs_pop_list(kwargs, "values"),
    )
    return self

Int = struct(
    TYPEDEF = _Int_typedef,
    new = _Int_new,
)

def _IntList_typedef():
    """Builder for attr.int_list.

    :::{field} allow_empty
    :type: Value[bool]
    :::

    :::{function} build() -> attr.int_list
    :::

    :::{field} default
    :type: list[int]
    :::

    :::{field} doc
    :type: Value[str]
    :::

    :::{field} extra_kwargs
    :type: dict[str, object]
    :::

    :::{field} mandatory
    :type: Value[bool]
    :::
    """

def _IntList_new(**kwargs):
    """Creates a builder for `attr.int_list`.

    Args:
        **kwargs: Same as {obj}`attr.int_list`.

    Returns:
        {type}`IntList`
    """

    # buildifier: disable=uninitialized
    self = struct(
        allow_empty = _kwargs_pop_allow_empty(kwargs),
        build = lambda: attr.int_list(**common_to_kwargs_nobuilders(self)),
        default = kwargs_pop_list(kwargs, "default"),
        doc = kwargs_pop_doc(kwargs),
        extra_kwargs = kwargs,
        mandatory = kwargs_pop_mandatory(kwargs),
    )
    return self

IntList = struct(
    TYPEDEF = _IntList_typedef,
    new = _IntList_new,
)

def _Label_typedef():
    """Builder for `attr.label` objects.

    :::{field} default
    :type: Value[str | label | configuration_field | None]
    :::

    :::{field} doc
    :type: Value[str]
    :::

    :::{field} mandatory
    :type: Value[bool]
    :::

    :::{field} executable
    :type: Value[bool]
    :::

    :::{field} allow_files
    :type: Optional[bool | list[str] | None]

    Note that `allow_files` is mutually exclusive with `allow_single_file`.
    Only one of the two can have a value set.
    :::

    :::{field} allow_single_file
    :type: Optional[bool | None]

    Note that `allow_single_file` is mutually exclusive with `allow_files`.
    Only one of the two can have a value set.
    :::

    :::{field} providers
    :type: list[provider | list[provider]]
    :::

    :::{field} cfg
    :type: AttrCfg
    :::

    :::{field} aspects
    :type: list[aspect]
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]
    :::
    """

def _Label_new(**kwargs):
    """Creates a builder for `attr.label`.

    Args:
        **kwargs: The same as {obj}`attr.label()`.

    Returns:
        {type}`Label`
    """

    # buildifier: disable=uninitialized
    self = struct(
        default = Value.kwargs(kwargs, "default", None),
        doc = kwargs_pop_doc(kwargs),
        mandatory = kwargs_pop_mandatory(kwargs),
        executable = Value.kwargs(kwargs, "executable", False),
        allow_files = Optional.new(kwargs, "allow_files"),
        allow_single_file = Optional.new(kwargs, "allow_single_file"),
        providers = kwargs_pop_list(kwargs, "providers"),
        cfg = _AttrCfg_new(kwargs, "cfg"),
        aspects = kwargs_pop_list(kwargs, "aspects"),
        build = lambda: _Label_build(self),
        extra_kwargs = kwargs,
    )
    return self

def _Label_build(self):
    kwargs = dict(self.extra_kwargs)
    if "aspects" not in kwargs:
        kwargs["aspects"] = [v.build() for v in self.aspects]

    common_to_kwargs_nobuilders(self, kwargs)
    for name, value in kwargs.items():
        kwargs[name] = value.build() if hasattr(value, "build") else value
    return attr.label(**kwargs)

Label = struct(
    TYPEDEF = _Label_typedef,
    new = _Label_new,
    build = _Label_build,
)

def _LabelKeyedStringDict_typedef():
    """Builder for attr.label_keyed_string_dict.

    :::{field} aspects
    :type: list[aspect]
    :::

    :::{field} allow_files
    :type: Value[bool | list[str]]
    :::

    :::{field} allow_empty
    :type: Value[bool]
    :::

    :::{field} cfg
    :type: AttrCfg
    :::

    :::{field} default
    :type: Value[dict[str|Label, str] | callable]
    :::

    :::{field} doc
    :type: Value[str]
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]
    :::

    :::{field} mandatory
    :type: Value[bool]
    :::

    :::{field} providers
    :type: list[provider | list[provider]]
    :::
    """

def _LabelKeyedStringDict_new(**kwargs):
    """Creates a builder for `attr.label_keyed_string_dict`.

    Args:
        **kwargs: Same as {obj}`attr.label_keyed_string_dict`.

    Returns:
        {type}`LabelKeyedStringDict`
    """

    # buildifier: disable=uninitialized
    self = struct(
        allow_empty = _kwargs_pop_allow_empty(kwargs),
        allow_files = Value.kwargs(kwargs, "allow_files", False),
        aspects = kwargs_pop_list(kwargs, "aspects"),
        build = lambda: _LabelList_build(self),
        cfg = _AttrCfg_new(kwargs, "cfg"),
        default = Value.kwargs(kwargs, "default", {}),
        doc = kwargs_pop_doc(kwargs),
        extra_kwargs = kwargs,
        mandatory = kwargs_pop_mandatory(kwargs),
        providers = kwargs_pop_list(kwargs, "providers"),
    )
    return self

LabelKeyedStringDict = struct(
    TYPEDEF = _LabelKeyedStringDict_typedef,
    new = _LabelKeyedStringDict_new,
)

def _LabelList_typedef():
    """Builder for `attr.label_list`

    :::{field} aspects
    :type: list[aspect]
    :::

    :::{field} allow_files
    :type: Value[bool | list[str]]
    :::

    :::{field} allow_empty
    :type: Value[bool]
    :::

    :::{field} cfg
    :type: AttrCfg
    :::

    :::{field} default
    :type: Value[list[str|Label] | configuration_field | callable]
    :::

    :::{field} doc
    :type: Value[str]
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]
    :::

    :::{field} mandatory
    :type: Value[bool]
    :::

    :::{field} providers
    :type: list[provider | list[provider]]
    :::
    """

def _LabelList_new(**kwargs):
    """Creates a builder for `attr.label_list`.

    Args:
        **kwargs: Same as {obj}`attr.label_list`.

    Returns:
        {type}`LabelList`
    """

    # buildifier: disable=uninitialized
    self = struct(
        allow_empty = _kwargs_pop_allow_empty(kwargs),
        allow_files = Value.kwargs(kwargs, "allow_files", False),
        aspects = kwargs_pop_list(kwargs, "aspects"),
        build = lambda: _LabelList_build(self),
        cfg = _AttrCfg_new(kwargs, "cfg"),
        default = Value.kwargs(kwargs, "default", []),
        doc = kwargs_pop_doc(kwargs),
        extra_kwargs = kwargs,
        mandatory = kwargs_pop_mandatory(kwargs),
        providers = kwargs_pop_list(kwargs, "providers"),
    )
    return self

def _LabelList_build(self):
    """Creates a {obj}`attr.label_list`."""

    kwargs = common_to_kwargs_nobuilders(self)
    for key, value in kwargs.items():
        kwargs[key] = value.build() if hasattr(value, "build") else value
    return attr.label_list(**kwargs)

LabelList = struct(
    TYPEDEF = _LabelList_typedef,
    new = _LabelList_new,
    build = _LabelList_build,
)

def _Output_typedef():
    """Builder for attr.output

    :::{function} build() -> attr.output
    :::

    :::{field} doc
    :type: Value[str]
    :::

    :::{field} extra_kwargs
    :type: dict[str, object]
    :::

    :::{field} mandatory
    :type: Value[bool]
    :::
    """

def _Output_new(**kwargs):
    """Creates a builder for `attr.output`.

    Args:
        **kwargs: Same as {obj}`attr.output`.

    Returns:
        {type}`Output`
    """

    # buildifier: disable=uninitialized
    self = struct(
        build = lambda: attr.output(**common_to_kwargs_nobuilders(self)),
        doc = kwargs_pop_doc(kwargs),
        extra_kwargs = kwargs,
        mandatory = kwargs_pop_mandatory(kwargs),
    )
    return self

Output = struct(
    TYPEDEF = _Output_typedef,
    new = _Output_new,
)

def _OutputList_typedef():
    """Builder for attr.output_list

    :::{field} allow_empty
    :type: Value[bool]
    :::

    :::{function} build() -> attr.output
    :::

    :::{field} doc
    :type: Value[str]
    :::

    :::{field} extra_kwargs
    :type: dict[str, object]
    :::

    :::{field} mandatory
    :type: Value[bool]
    :::
    """

def _OutputList_new(**kwargs):
    """Creates a builder for `attr.output_list`.

    Args:
        **kwargs: Same as {obj}`attr.output_list`.

    Returns:
        {type}`OutputList`
    """

    # buildifier: disable=uninitialized
    self = struct(
        allow_empty = _kwargs_pop_allow_empty(kwargs),
        build = lambda: attr.output_list(**common_to_kwargs_nobuilders(self)),
        doc = kwargs_pop_doc(kwargs),
        extra_kwargs = kwargs,
        mandatory = kwargs_pop_mandatory(kwargs),
    )
    return self

OutputList = struct(
    TYPEDEF = _OutputList_typedef,
    new = _OutputList_new,
)

def _String_typedef():
    """Builder for `attr.string`

    :::{function} build() -> attr.string
    :::

    :::{field} default
    :type: Value[str | configuration_field]
    :::

    :::{field} doc
    :type: Value[str]
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]
    :::

    :::{field} mandatory
    :type: Value[bool]
    :::

    :::{field} values
    :type: list[str]
    :::
    """

def _String_new(**kwargs):
    """Creates a builder for `attr.string`.

    Args:
        **kwargs: Same as {obj}`attr.string`.

    Returns:
        {type}`String`
    """

    # buildifier: disable=uninitialized
    self = struct(
        default = Value.kwargs(kwargs, "default", ""),
        doc = kwargs_pop_doc(kwargs),
        mandatory = kwargs_pop_mandatory(kwargs),
        build = lambda *a, **k: attr.string(**common_to_kwargs_nobuilders(self, *a, **k)),
        extra_kwargs = kwargs,
        values = kwargs_pop_list(kwargs, "values"),
    )
    return self

String = struct(
    TYPEDEF = _String_typedef,
    new = _String_new,
)

def _StringDict_typedef():
    """Builder for `attr.string_dict`

    :::{field} default
    :type: dict[str, str]
    :::

    :::{field} doc
    :type: Value[str]
    :::

    :::{field} mandatory
    :type: Value[bool]
    :::

    :::{field} allow_empty
    :type: Value[bool]
    :::

    :::{function} build() -> attr.string_dict
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]
    :::
    """

def _StringDict_new(**kwargs):
    """Creates a builder for `attr.string_dict`.

    Args:
        **kwargs: The same args as for `attr.string_dict`.

    Returns:
        {type}`StringDict`
    """

    # buildifier: disable=uninitialized
    self = struct(
        allow_empty = _kwargs_pop_allow_empty(kwargs),
        build = lambda: attr.string_dict(**common_to_kwargs_nobuilders(self)),
        default = kwargs_pop_dict(kwargs, "default"),
        doc = kwargs_pop_doc(kwargs),
        extra_kwargs = kwargs,
        mandatory = kwargs_pop_mandatory(kwargs),
    )
    return self

StringDict = struct(
    TYPEDEF = _StringDict_typedef,
    new = _StringDict_new,
)

def _StringKeyedLabelDict_typedef():
    """Builder for attr.string_keyed_label_dict.

    :::{field} allow_empty
    :type: Value[bool]
    :::

    :::{function} build() -> attr.string_list
    :::

    :::{field} default
    :type: dict[str, Label]
    :::

    :::{field} doc
    :type: Value[str]
    :::

    :::{field} mandatory
    :type: Value[bool]
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]
    :::
    """

def _StringKeyedLabelDict_new(**kwargs):
    """Creates a builder for `attr.string_keyed_label_dict`.

    Args:
        **kwargs: Same as {obj}`attr.string_keyed_label_dict`.

    Returns:
        {type}`StringKeyedLabelDict`
    """

    # buildifier: disable=uninitialized
    self = struct(
        allow_empty = _kwargs_pop_allow_empty(kwargs),
        build = lambda *a, **k: attr.string_list(**common_to_kwargs_nobuilders(self, *a, **k)),
        default = kwargs_pop_dict(kwargs, "default"),
        doc = kwargs_pop_doc(kwargs),
        extra_kwargs = kwargs,
        mandatory = kwargs_pop_mandatory(kwargs),
    )
    return self

StringKeyedLabelDict = struct(
    TYPEDEF = _StringKeyedLabelDict_typedef,
    new = _StringKeyedLabelDict_new,
)

def _StringList_typedef():
    """Builder for `attr.string_list`

    :::{field} allow_empty
    :type: Value[bool]
    :::

    :::{function} build() -> attr.string_list
    :::

    :::{field} default
    :type: Value[list[str] | configuration_field]
    :::

    :::{field} doc
    :type: Value[str]
    :::

    :::{field} mandatory
    :type: Value[bool]
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]
    :::
    """

def _StringList_new(**kwargs):
    """Creates a builder for `attr.string_list`.

    Args:
        **kwargs: Same as {obj}`attr.string_list`.

    Returns:
        {type}`StringList`
    """

    # buildifier: disable=uninitialized
    self = struct(
        allow_empty = _kwargs_pop_allow_empty(kwargs),
        build = lambda: attr.string_list(**common_to_kwargs_nobuilders(self)),
        default = Value.kwargs(kwargs, "default", []),
        doc = kwargs_pop_doc(kwargs),
        extra_kwargs = kwargs,
        mandatory = kwargs_pop_mandatory(kwargs),
    )
    return self

StringList = struct(
    TYPEDEF = _StringList_typedef,
    new = _StringList_new,
)

def _StringListDict_typedef():
    """Builder for attr.string_list_dict.

    :::{field} allow_empty
    :type: Value[bool]
    :::

    :::{function} build() -> attr.string_list
    :::

    :::{field} default
    :type: dict[str, list[str]]
    :::

    :::{field} doc
    :type: Value[str]
    :::

    :::{field} mandatory
    :type: Value[bool]
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]
    :::
    """

def _StringListDict_new(**kwargs):
    """Creates a builder for `attr.string_list_dict`.

    Args:
        **kwargs: Same as {obj}`attr.string_list_dict`.

    Returns:
        {type}`StringListDict`
    """

    # buildifier: disable=uninitialized
    self = struct(
        allow_empty = _kwargs_pop_allow_empty(kwargs),
        build = lambda: attr.string_list(**common_to_kwargs_nobuilders(self)),
        default = kwargs_pop_dict(kwargs, "default"),
        doc = kwargs_pop_doc(kwargs),
        extra_kwargs = kwargs,
        mandatory = kwargs_pop_mandatory(kwargs),
    )
    return self

StringListDict = struct(
    TYPEDEF = _StringListDict_typedef,
    new = _StringListDict_new,
)

attrb = struct(
    Bool = _Bool_new,
    Int = _Int_new,
    IntList = _IntList_new,
    Label = _Label_new,
    LabelKeyedStringDict = _LabelKeyedStringDict_new,
    LabelList = _LabelList_new,
    Output = _Output_new,
    OutputList = _OutputList_new,
    String = _String_new,
    StringDict = _StringDict_new,
    StringKeyedLabelDict = _StringKeyedLabelDict_new,
    StringList = _StringList_new,
    StringListDict = _StringListDict_new,
)
