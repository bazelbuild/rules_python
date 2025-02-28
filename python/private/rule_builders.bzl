"""Builders for creating rules, aspects, attributes et al.

When defining rules, Bazel only allows creating *immutable* objects that can't
be introspected. This makes it difficult to perform arbitrary customizations of
how a rule is defined.

These builders are, essentially, mutable and inspectable, wrappers for those
Bazel objects. This allow defining a rule where the values are mutable and
callers can customize to derive their own variant of the rule.

:::{important}
When using builders, all the values passed into them **must** be locally created
values, otherwise they won't be mutable. This is due to Bazel's implicit
immutability rules: after evaluating a `.bzl` file, its the global variables
are frozen.
:::

Example usage:

```
# File: foo_binary.bzl
def create_foo_binary_builder():
    r = RuleBuilder()
    r.implementation.set(_foo_binary_impl)
    r.attrs["srcs"] = LabelListAttrBuilder(...)
    return r

foo_binary = create_foo_binary_builder().build()

# File: custom_foo_binary.bzl
load(":foo_binary.bzl", "create_foo_binary_builder")

def create_custom_foo_binary():
    r = create_foo_binary_builder()
    r.attrs["srcs"].default.append("whatever.txt")
    return r.build()

custom_foo_binary = create_custom_foo_binary()
```
"""

load("@bazel_skylib//lib:types.bzl", "types")
load(":builders.bzl", "builders")

def _to_kwargs_get_pairs(kwargs, obj):
    ignore_names = {"extra_kwargs": None}
    pairs = []
    for name in dir(obj):
        if name in ignore_names or name in kwargs:
            continue
        value = getattr(obj, name)
        if types.is_function(value):
            continue  # Assume it's a method
        if _is_optional(value):
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
def _common_to_kwargs_nobuilders(self, kwargs = None):
    if kwargs == None:
        kwargs = {}
    kwargs.update(self.extra_kwargs)
    for name, value in _to_kwargs_get_pairs(kwargs, self):
        kwargs[name] = value

    return kwargs

def _Optional_typedef():
    """A wrapper for a re-assignable value that may or may not be set.

    This allows structs to have attributes whose values can be re-assigned,
    e.g. ints, strings, bools, or values where the presence matteres.
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
        _value = initial,
        present = lambda *a, **k: _Optional_present(self, *a, **k),
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
    if len(self._value) == 0:
        self._value.append(value)
    else:
        self._value[0] = value

def _Optional_get(self):
    """Gets the value of the optional, or error.

    Args:
        self: implicitly added

    Returns:
        The stored value, or error if not set.
    """
    if not len(self._value):
        fail("Value not present")
    return self._value[0]

def _Optional_present(self):
    """Tells if a value is present.

    Args:
        self: implicitly added

    Returns:
        {type}`bool` True if the value is set, False if not.
    """
    return len(self._value) > 0

def _is_optional(obj):
    return hasattr(obj, "present")

Optional = struct(
    TYPEDEF = _Optional_typedef,
    new = _Optional_new,
    get = _Optional_get,
    set = _Optional_set,
    present = _Optional_present,
)

def _ExecGroupBuilder_typedef():
    """Builder for {obj}`exec_group()`

    :::{field} toolchains
    :type: list[ToolchainTypeBuilder]
    :::

    :::{field} exec_compatible_with
    :type: list[str]
    :::

    :::{function} build() -> exec_group
    :::
    """

def _ExecGroupBuilder_new(**kwargs):
    self = struct(
        # List of ToolchainTypeBuilders
        toolchains = _kwargs_pop_list(kwargs, "toolchains"),
        # List of strings
        exec_compatible_with = _kwargs_pop_list(kwargs, "exec_compatible_with"),
        build = lambda: exec_group(**_common_to_kwargs_nobuilders(self)),
    )
    return self

ExecGroupBuilder = struct(
    TYPEDEF = _ExecGroupBuilder_typedef,
    new = _ExecGroupBuilder_new,
)

def _ToolchainTypeBuilder_typedef():
    """Builder for {obj}`config_common.toolchain_type()`

    :::{field} extra_kwargs
    :type: dict[str, object]
    :::

    :::{field} mandatory
    :type: Optional[bool]
    :::

    :::{field} name
    :type: Optional[str | Label]
    :::

    :::{function} build() -> config_common.toolchain_type
    :::
    """

def _ToolchainTypeBuilder_new(**kwargs):
    self = struct(
        build = lambda: config_common.toolchain_type(**_common_to_kwargs_nobuilders(self)),
        extra_kwargs = kwargs,
        mandatory = _Optional_new(kwargs, "mandatory"),
        name = _Optional_new(kwargs, "name"),
    )
    return self

ToolchainTypeBuilder = struct(
    TYPEDEF = _ToolchainTypeBuilder_typedef,
    new = _ToolchainTypeBuilder_new,
)

def _RuleCfgBuilder_typedef():
    """Wrapper for `rule.cfg` arg.

    :::{field} extra_kwargs
    :type: dict[str, object]
    :::

    :::{field} inputs
    :type: SetBuilder
    :::

    :::{field} outputs
    :type: SetBuilder
    :::
    """

def _RuleCfgBuilder_new(kwargs):
    if kwargs == None:
        kwargs = {}

    self = struct(
        _implementation = [kwargs.pop("implementation", None)],
        build = lambda: _RuleCfgBuilder_build(self),
        extra_kwargs = kwargs,
        implementation = lambda: _RuleCfgBuilder_implementation(self),
        # Bazel requires transition.inputs to have unique values, so use set
        # semantics so extenders of a transition can easily add/remove values.
        # TODO - Use set builtin instead of custom builder, when available.
        # https://bazel.build/rules/lib/core/set
        inputs = _SetBuilder(kwargs, "inputs"),
        # Bazel requires transition.outputs to have unique values, so use set
        # semantics so extenders of a transition can easily add/remove values.
        # TODO - Use set builtin instead of custom builder, when available.
        # https://bazel.build/rules/lib/core/set
        outputs = _SetBuilder(kwargs, "outputs"),
        set_implementation = lambda *a, **k: _RuleCfgBuilder_set_implementation(self, *a, **k),
    )
    return self

def _RuleCfgBuilder_set_implementation(self, value):
    """Set the implementation method.

    Args:
        self: implicitly added.
        value: {type}`str | function` a valid `rule.cfg` argument value.
    """
    self._implementation[0] = value

def _RuleCfgBuilder_implementation(self):
    """Returns the implementation name or function for the cfg transition.

    Returns:
        {type}`str | function`
    """
    return self._implementation[0]

def _RuleCfgBuilder_build(self):
    """Builds the rule cfg into the value rule.cfg arg value.

    Returns:
        {type}`transition` the transition object to apply to the rule.
    """
    impl = self._implementation[0]
    if impl == "target" or impl == None:
        return config.target()
    elif impl == "none":
        return config.none()
    elif types.is_function(impl):
        return transition(
            implementation = impl,
            inputs = self.inputs.build(),
            outputs = self.outputs.build(),
        )
    else:
        return impl

RuleCfgBuilder = struct(
    TYPEDEF = _RuleCfgBuilder_typedef,
    new = _RuleCfgBuilder_new,
    implementation = _RuleCfgBuilder_implementation,
    set_implementation = _RuleCfgBuilder_set_implementation,
    build = _RuleCfgBuilder_build,
)

def _RuleBuilder_typedef():
    """A builder to accumulate state for constructing a `rule` object.

    :::{field} attrs
    :type: AttrsDict
    :::

    :::{field} cfg
    :type: RuleCfgBuilder
    :::

    :::{field} exec_groups
    :type: dict[str, ExecGroupBuilder]
    :::

    :::{field} executable
    :type: Optional[bool]
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]

    Additional keyword arguments to use when constructing the rule. Their
    values have precedence when creating the rule kwargs.
    :::

    :::{field} fragments
    :type: list[str]
    :::

    :::{field} implementation
    :type: Optional[callable]
    :::

    :::{field} provides
    :type: list[Provider | list[Provider]]
    :::

    :::{field} test
    :type: Optional[bool]
    :::

    :::{field} toolchains
    :type: list[ToolchainTypeBuilder]
    :::
    """

def _RuleBuilder_new(implementation = None, **kwargs):
    """Builder for creating rules.

    Args:
        implementation: {type}`callable` The rule implementation function.
        **kwargs: The same as the `rule()` function, but using builders or
            dicts to specify sub-objects instead of the immutable Bazel
            objects.
    """

    # buildifier: disable=uninitialized
    self = struct(
        attrs = _AttrsDict_new(kwargs.pop("attrs", None)),
        cfg = _RuleCfgBuilder_new(kwargs.pop("cfg", None)),
        exec_groups = _kwargs_pop_dict(kwargs, "exec_groups"),
        executable = _Optional_new(kwargs, "executable"),
        fragments = _kwargs_pop_list(kwargs, "fragments"),
        implementation = _Optional_new(implementation),
        extra_kwargs = kwargs,
        provides = _kwargs_pop_list(kwargs, "provides"),
        test = _Optional_new(kwargs, "test"),
        toolchains = _kwargs_pop_list(kwargs, "toolchains"),
        build = lambda *a, **k: _RuleBuilder_build(self, *a, **k),
        to_kwargs = lambda *a, **k: _RuleBuilder_to_kwargs(self, *a, **k),
    )
    return self

def _RuleBuilder_build(self, debug = ""):
    """Builds a `rule` object

    Args:
        self: implicitly added
        debug: {type}`str` If set, prints the args used to create the rule.

    Returns:
        {type}`rule`
    """
    kwargs = self.to_kwargs()
    if debug:
        lines = ["=" * 80, "rule kwargs: {}:".format(debug)]
        for k, v in sorted(kwargs.items()):
            lines.append("  {}={}".format(k, v))
        print("\n".join(lines))  # buildifier: disable=print
    return rule(**kwargs)

def _RuleBuilder_to_kwargs(self):
    """Builds the arguments for calling `rule()`.

    This is added as an escape hatch to construct the final values `rule()`
    kwarg values in case callers want to manually change them.

    Args:
        self: implicitly added

    Returns:
        {type}`dict`
    """
    kwargs = dict(self.extra_kwargs)
    for name, value in _to_kwargs_get_pairs(kwargs, self):
        value = value.build() if hasattr(value, "build") else value
        kwargs[name] = value
    return kwargs

RuleBuilder = struct(
    TYPEDEF = _RuleBuilder_typedef,
    new = _RuleBuilder_new,
    build = _RuleBuilder_build,
    to_kwargs = _RuleBuilder_to_kwargs,
)

def _AttrsDict_typedef():
    """Builder for the dictionary of rule attributes.

    :::{field} values
    :type: dict[str, AttributeBuilder]

    The underlying dict of attributes. Directly accessible so that regular
    dict operations (e.g. `x in y`) can be performed, if necessary.
    :::

    :::{function} get(key, default=None)
    Get an entry from the dict. Convenience wrapper for `.values.get(...)`
    :::

    :::{function} items() -> list[tuple[str, object]]
    Returns a list of key-value tuples. Convenience wrapper for `.values.items()`
    :::
    """

def _AttrsDict_new(initial):
    self = struct(
        values = {},
        update = lambda *a, **k: _AttrsDict_update(self, *a, **k),
        get = lambda *a, **k: self.values.get(*a, **k),
        items = lambda: self.values.items(),
        build = lambda: _AttrsDict_build(self),
    )
    if initial:
        _AttrsDict_update(self, initial)
    return self

def _AttrsDict_update(self, other):
    """Merge `other` into this object.

    Args:
        other: {type}`dict[str, callable | AttributeBuilder]` the values to
            merge into this object. If the value a function, it is called
            with no args and expected to return an attribute builder. This
            allows defining dicts of common attributes (where the values are
            functions that create a builder) and merge them into the rule.
    """
    for k, v in other.items():
        # Handle factory functions that create builders
        if types.is_function(v):
            self.values[k] = v()
        else:
            self.values[k] = v

def _AttrsDict_build(self):
    """Build an attribute dict for passing to `rule()`.

    Returns:
        {type}`dict[str, attribute]` where the values are `attr.XXX` objects
    """
    attrs = {}
    for k, v in self.values.items():
        if hasattr(v, "build"):
            v = v.build()
        if not type(v) == "Attribute":
            fail("bad attr type:", k, type(v), v)
        attrs[k] = v
    return attrs

AttrsDict = struct(
    TYPEDEF = _AttrsDict_typedef,
    new = _AttrsDict_new,
    update = _AttrsDict_update,
    build = _AttrsDict_build,
)

def _SetBuilder(kwargs, name):
    """Builder for list of unique values.

    Args:
        kwargs: {type}`dict[str, Any]` kwargs to search for `name`
        name: {type}`str` A key in `kwargs` to initialize the value
            to. If present, kwargs will be modified in place.
        initial: {type}`list | None` The initial values.

    Returns:
        {type}`SetBuilder`
    """
    initial = {v: None for v in _kwargs_pop_list(kwargs, name)}

    # buildifier: disable=uninitialized
    self = struct(
        # TODO - Switch this to use set() builtin when available
        # https://bazel.build/rules/lib/core/set
        _values = initial,
        update = lambda *a, **k: _SetBuilder_update(self, *a, **k),
        build = lambda *a, **k: _SetBuilder_build(self, *a, **k),
    )
    return self

def _SetBuilder_build(self):
    """Builds the values into a list

    Returns:
        {type}`list`
    """
    return self._values.keys()

def _SetBuilder_update(self, *others):
    """Adds values to the builder.

    Args:
        self: implicitly added
        *others: {type}`list` values to add to the set.
    """
    for other in others:
        for value in other:
            if value not in self._values:
                self._values[value] = None

def _kwargs_pop_dict(kwargs, key):
    return dict(kwargs.pop(key, None) or {})

def _kwargs_pop_list(kwargs, key):
    return list(kwargs.pop(key, None) or [])

def _BoolAttrBuilder(**kwargs):
    """Create a builder for attributes.

    Returns:
        {type}`BoolAttrBuilder`
    """

    # buildifier: disable=uninitialized
    self = struct(
        default = _Optional_new(kwargs, "default"),
        doc = _Optional_new(kwargs, "doc"),
        mandatory = _Optional_new(kwargs, "mandatory"),
        extra_kwargs = kwargs,
        build = lambda: attr.bool(**_common_to_kwargs_nobuilders(self)),
    )
    return self

def _IntAttrBuilder(**kwargs):
    # buildifier: disable=uninitialized
    self = struct(
        default = _Optional_new(kwargs, "default"),
        doc = _Optional_new(kwargs, "doc"),
        mandatory = _Optional_new(kwargs, "mandatory"),
        values = kwargs.get("values") or [],
        build = lambda *a, **k: _IntAttrBuilder_build(self, *a, **k),
        extra_kwargs = kwargs,
    )
    return self

def _IntAttrBuilder_build(self):
    kwargs = _common_to_kwargs_nobuilders(self)
    return attr.int(**kwargs)

def _AttrCfgBuilder_typedef():
    """Builder for `cfg` arg of label attributes.

    :::{function} implementation() -> callable

    Returns the implementation function for using custom transition.
    :::

    :::{field} outputs
    :type: SetBuilder[str | Label]
    :::

    :::{field} inputs
    :type: SetBuilder[str | Label]
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]
    :::
    """

def _AttrCfgBuilder_new(outer_kwargs, name):
    """Creates an instance.

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
        {type}`AttrCfgBuilder`
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

    self = struct(
        # list of (value, bool is_exec)
        _implementation = [initial, is_exec],
        implementation = lambda: self._implementation[0],
        set_implementation = lambda *a, **k: _AttrCfgBuilder_set_implementation(self, *a, **k),
        set_exec = lambda *a, **k: _AttrCfgBuilder_set_exec(self, *a, **k),
        set_target = lambda: _AttrCfgBuilder_set_implementation(self, "target"),
        exec_group = lambda: _AttrCfgBuilder_exec_group(self),
        outputs = _SetBuilder(kwargs, "outputs"),
        inputs = _SetBuilder(kwargs, "inputs"),
        build = lambda: _AttrCfgBuilder_build(self),
        extra_kwargs = kwargs,
    )
    return self

def _AttrCfgBuilder_set_implementation(self, impl):
    """Sets a custom transition function to use.

    Args:
        impl: {type}`callable` a transition implementation function.
    """
    self._implementation[0] = impl
    self._implementation[1] = False

def _AttrCfgBuilder_set_exec(self, exec_group = None):
    """Sets to use an exec transition.

    Args:
        exec_group: {type}`str | None` the exec group name to use, if any.
    """
    self._implementation[0] = exec_group
    self._implementation[1] = True

def _AttrCfgBuilder_exec_group(self):
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

def _AttrCfgBuilder_build(self):
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
        return impl

AttrCfgBuilder = struct(
    TYPEDEF = _AttrCfgBuilder_typedef,
    new = _AttrCfgBuilder_new,
    set_implementation = _AttrCfgBuilder_set_implementation,
    set_exec = _AttrCfgBuilder_set_exec,
    exec_group = _AttrCfgBuilder_exec_group,
)

def _LabelAttrBuilder_typedef():
    """Builder for `attr.label` objects.

    :::{field} default
    :type: Optional[str | label | configuration_field | None]
    :::

    :::{field} doc
    :type: str
    :::

    :::{field} mandatory
    :type: Optional[bool]
    :::

    :::{field} executable
    :type: Optional[bool]
    :::

    :::{field} allow_files
    :type: Optional[bool | list[str]]
    :::

    :::{field} allow_single_file
    :type: Optional[bool]
    :::

    :::{field} providers
    :type: list[provider | list[provider]]
    :::

    :::{field} cfg
    :type: AttrCfgBuilder
    :::

    :::{field} aspects
    :type: list[aspect]
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]
    :::
    """

def _LabelAttrBuilder_new(**kwargs):
    """Creates an instance.

    Args:
        **kwargs: The same as `attr.label()`.

    Returns:
        {type}`LabelAttrBuilder`
    """

    # buildifier: disable=uninitialized
    self = struct(
        default = _Optional_new(kwargs, "default"),
        doc = _Optional_new(kwargs, "doc"),
        mandatory = _Optional_new(kwargs, "mandatory"),
        executable = _Optional_new(kwargs, "executable"),
        allow_files = _Optional_new(kwargs, "allow_files"),
        allow_single_file = _Optional_new(kwargs, "allow_single_file"),
        providers = _kwargs_pop_list(kwargs, "providers"),
        cfg = _AttrCfgBuilder_new(kwargs, "cfg"),
        aspects = _kwargs_pop_list(kwargs, "aspects"),
        build = lambda: _LabelAttrBuilder_build(self),
        extra_kwargs = kwargs,
    )
    return self

def _LabelAttrBuilder_build(self):
    kwargs = {
        "aspects": [v.build() for v in self.aspects],
    }
    _common_to_kwargs_nobuilders(self, kwargs)
    for name, value in kwargs.items():
        kwargs[name] = value.build() if hasattr(value, "build") else value
    return attr.label(**kwargs)

LabelAttrBuilder = struct(
    TYPEDEF = _LabelAttrBuilder_typedef,
    new = _LabelAttrBuilder_new,
    build = _LabelAttrBuilder_build,
)

def _LabelListAttrBuilder_typedef():
    """Builder for `attr.label_list`

    :::{field} default
    :type: Optional[list[str|Label] | configuration_field]
    :::

    :::{field} doc
    :type: Optional[str]
    :::

    :::{field} mandatory
    :type: Optional[bool]
    :::

    :::{field} executable
    :type: Optional[bool]
    :::

    :::{field} allow_files
    :type: Optional[bool | list[str]]
    :::

    :::{field} allow_empty
    :type: Optional[bool]
    :::

    :::{field} providers
    :type: list[provider | list[provider]]
    :::

    :::{field} cfg
    :type: AttrCfgBuilder
    :::

    :::{field} aspects
    :type: list[aspect]
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]
    :::
    """

def _LabelListAttrBuilder_new(**kwargs):
    self = struct(
        default = _kwargs_pop_list(kwargs, "default"),
        doc = _Optional_new(kwargs, "doc"),
        mandatory = _Optional_new(kwargs, "mandatory"),
        executable = _Optional_new(kwargs, "executable"),
        allow_empty = _Optional_new(kwargs, "allow_empty"),
        allow_files = _Optional_new(kwargs, "allow_files"),
        providers = _kwargs_pop_list(kwargs, "providers"),
        cfg = _AttrCfgBuilder_new(kwargs, "cfg"),
        aspects = _kwargs_pop_list(kwargs, "aspects"),
        build = lambda: _LabelListAttrBuilder_build(self),
        extra_kwargs = kwargs,
    )
    return self

def _LabelListAttrBuilder_build(self):
    kwargs = _common_to_kwargs_nobuilders(self)
    for key, value in kwargs.items():
        kwargs[key] = value.build() if hasattr(value, "build") else value
    return attr.label_list(**kwargs)

LabelListAttrBuilder = struct(
    TYPEDEF = _LabelListAttrBuilder_typedef,
    new = _LabelListAttrBuilder_new,
    build = _LabelListAttrBuilder_build,
)

def _StringListAttrBuilder_typedef():
    """Builder for `attr.string_list`

    :::{field} default
    :type: Optiona[list[str] | configuration_field]
    :::

    :::{field} doc
    :type: Optional[str]
    :::

    :::{field} mandatory
    :type: Optional[bool]
    :::

    :::{field} allow_empty
    :type: Optional[bool]
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]
    :::

    :::{function} build() -> attr.string_list
    :::
    """

def _StringListAttrBuilder_new(**kwargs):
    self = struct(
        default = _Optional_new(kwargs, "default"),
        doc = _Optional_new(kwargs, "doc"),
        mandatory = _Optional_new(kwargs, "mandatory"),
        allow_empty = _Optional_new(kwargs, "allow_empty"),
        build = lambda *a, **k: attr.string_list(**_common_to_kwargs_nobuilders(self, *a, **k)),
        extra_kwargs = kwargs,
    )
    return self

StringListBuilder = struct(
    TYPEDEF = _StringListBuilder_typedef,
    new = _StringListBuilder_new,
)

def _StringAttrBuilder_typedef():
    """Builder for `attr.string`

    :::{field} default
    :type: Optiona[str]
    :::

    :::{field} doc
    :type: Optiona[str]
    :::
    :::{field} mandatory
    :type: Optiona[bool]
    :::

    :::{field} allow_empty
    :type: Optiona[bool]
    :::

    :::{function} build() -> attr.string
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]
    :::

    :::{field} values
    :type: list[str]
    :::
    """

def _StringAttrBuilder_new(**kwargs):
    self = struct(
        default = _Optional_new(kwargs, "default"),
        doc = _Optional_new(kwargs, "doc"),
        mandatory = _Optional_new(kwargs, "mandatory"),
        # True, False, or list
        allow_empty = _Optional_new(kwargs, "allow_empty"),
        build = lambda *a, **k: attr.string(**_common_to_kwargs_nobuilders(self, *a, **k)),
        extra_kwargs = kwargs,
        values = _kwargs_pop_list(kwargs, "values"),
    )
    return self

StringAttrBuilder = struct(
    TYPEDEF = _StringAttrBuilder_typedef,
    new = _StringAttrBuilder_new,
)

def _StringDictAttrBuilder_typedef():
    """Builder for `attr.string_dict`

    :::{field} default
    :type: dict[str, str],
    :::

    :::{field} doc
    :type: Optional[str]
    :::

    :::{field} mandatory
    :type: Optional[bool]
    :::

    :::{field} allow_empty
    :type: Optional[bool]
    :::

    :::{function} build() -> attr.string_dict
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]
    :::
    """

def _StringDictAttrBuilder_new(**kwargs):
    """Creates an instance.

    Args:
        **kwargs: {type}`dict` The same args as for `attr.string_dict`.

    Returns:
        {type}`StringDictAttrBuilder`
    """
    self = struct(
        default = _kwargs_pop_dict(kwargs, "default"),
        doc = _Optional_new(kwargs, "doc"),
        mandatory = _Optional_new(kwargs, "mandatory"),
        allow_empty = _Optional_new(kwargs, "allow_empty"),
        build = lambda: attr.string_dict(**_common_to_kwargs_nobuilders(self)),
        extra_kwargs = kwargs,
    )
    return self

StringDictAttrBuilder = struct(
    TYPEDEF = _StringDictAttrBuilder_typedef,
    new = _StringDictAttrBuilder_new,
)

# todo: remove Builder suffixes on all these?
rule_builders = struct(
    RuleBuilder = _RuleBuilder_new,
    LabelAttrBuilder = _LabelAttrBuilder_new,
    LabelListAttrBuilder = _LabelListAttrBuilder,
    IntAttrBuilder = _IntAttrBuilder,
    StringListAttrBuilder = _StringListAttrBuilder,
    StringAttrBuilder = _StringAttrBuilder,
    StringDictAttrBuilder = _StringDictAttrBuilder,
    BoolAttrBuilder = _BoolAttrBuilder,
    AttrCfgBuilder = _AttrCfgBuilder,
)
