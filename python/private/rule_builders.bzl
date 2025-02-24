"""Builders specific for creating rules, aspects, attributes et al."""

load("@bazel_skylib//lib:types.bzl", "types")
load(":builders.bzl", "builders")

def _Optional(*initial):
    """A wrapper for a re-assignable value that may or may not be set.

    This allows structs to have attributes that aren't inherently mutable
    and must be re-assigned to have their value updated.

    Args:
        *initial: Either zero, one, or two positional args to set the
            initial value stored for the optional.
            If zero args, then no value is stored.
            If one arg, then the arg is the value stored.
            If two args, then the first arg is a kwargs dict, and the
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

def _RuleCfgBuilder(**kwargs):
    self = struct(
        _implementation = [kwargs.pop("implementation", None)],
        set_implementation = lambda *a, **k: _RuleCfgBuilder_set_implementation(self, *a, **k),
        implementation = lambda: _RuleCfgBuilder_implementation(self),
        outputs = _SetBuilder(_kwargs_pop_list(kwargs, "outputs")),
        inputs = _SetBuilder(_kwargs_pop_list(kwargs, "inputs")),
        build = lambda *a, **k: _RuleCfgBuilder_build(self, *a, **k),
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
    impl = self._implementation[0]

    # todo: move these strings into an enum
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

def _RuleBuilder(implementation = None, **kwargs):
    """Builder for creating rules.

    Args:
        implementation: {type}`callable` The rule implementation function.
        **kwargs: The same as the `rule()` function, but using builders
            for the non-mutable Bazel objects.
    """

    # buildifier: disable=uninitialized
    self = struct(
        attrs = _AttrsDict(kwargs.pop("attrs", None)),
        cfg = kwargs.pop("cfg", None) or _RuleCfgBuilder(),
        # todo: create ExecGroupBuilder (allows mutation) or ExecGroup (allows introspection)
        exec_groups = _kwargs_pop_dict(kwargs, "exec_groups"),
        executable = _Optional(kwargs, "executable"),
        fragments = list(kwargs.pop("fragments", None) or []),
        implementation = _Optional(implementation),
        extra_kwargs = kwargs,
        provides = _kwargs_pop_list(kwargs, "provides"),
        test = _Optional(kwargs, "test"),
        # todo: create ToolchainTypeBuilder or ToolchainType
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

def _Builder_get_pairs(kwargs, obj):
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

# This function isn't allowed to call builders to prevent recursion
def _Builder_to_kwargs_nobuilders(self, kwargs = None):
    if kwargs == None:
        kwargs = {}
    kwargs.update(self.extra_kwargs)
    for name, value in _Builder_get_pairs(kwargs, self):
        kwargs[name] = value
    return kwargs

def _RuleBuilder_to_kwargs(self):
    """Builds the arguments for calling `rule()`.

    Args:
        self: implicitly added

    Returns:
        {type}`dict`
    """
    kwargs = dict(self.extra_kwargs)
    for name, value in _Builder_get_pairs(kwargs, self):
        value = value.build() if hasattr(value, "build") else value
        kwargs[name] = value
    return kwargs

def _AttrsDict(initial):
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
    for k, v in other.items():
        # Handle factory functions that create builders
        if types.is_function(v):
            self.values[k] = v()
        else:
            self.values[k] = v

def _AttrsDict_build(self):
    attrs = {}
    for k, v in self.values.items():
        if hasattr(v, "build"):
            v = v.build()
        if not type(v) == "Attribute":
            fail("bad attr type:", k, type(v), v)
        attrs[k] = v
    return attrs

def _SetBuilder(initial = None):
    """Builder for list of unique values.

    Args:
        initial: {type}`list | None` The initial values.

    Returns:
        {type}`SetBuilder`
    """
    initial = {} if not initial else {v: None for v in initial}

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

def _TransitionBuilder(implementation = None, inputs = None, outputs = None, **kwargs):
    """Builder for transition objects.

    Args:
        implementation: {type}`callable` the transition implementation function.
        inputs: {type}`list[str]` the inputs for the transition.
        outputs: {type}`list[str]` the outputs of the transition.
        **kwargs: Extra keyword args to use when building.

    Returns:
        {type}`TransitionBuilder`
    """

    # todo: accept string | exec_group | config.name | config.target |
    # transition

    # buildifier: disable=uninitialized
    self = struct(
        implementation = _Optional(implementation),
        # Bazel requires transition.inputs to have unique values, so use set
        # semantics so extenders of a transition can easily add/remove values.
        # TODO - Use set builtin instead of custom builder, when available.
        # https://bazel.build/rules/lib/core/set
        inputs = _SetBuilder(inputs),
        # Bazel requires transition.inputs to have unique values, so use set
        # semantics so extenders of a transition can easily add/remove values.
        # TODO - Use set builtin instead of custom builder, when available.
        # https://bazel.build/rules/lib/core/set
        outputs = _SetBuilder(outputs),
        extra_kwargs = kwargs,
        build = lambda *a, **k: _TransitionBuilder_build(self, *a, **k),
    )
    return self

def _TransitionBuilder_build(self):
    """Creates a transition from the builder.

    Returns:
        {type}`transition`
    """
    return transition(
        implementation = self.implementation.get(),
        inputs = self.inputs.build(),
        outputs = self.outputs.build(),
        **self.extra_kwargs
    )

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
        default = _Optional(kwargs, "default"),
        doc = _Optional(kwargs, "doc"),
        mandatory = _Optional(kwargs, "mandatory"),
        extra_kwargs = kwargs,
        build = lambda: attr.bool(**_Builder_to_kwargs_nobuilders(self)),
    )
    return self

def _IntAttrBuilder(**kwargs):
    # buildifier: disable=uninitialized
    self = struct(
        default = _Optional(kwargs, "default"),
        doc = _Optional(kwargs, "doc"),
        mandatory = _Optional(kwargs, "mandatory"),
        values = kwargs.get("values") or [],
        build = lambda *a, **k: _IntAttrBuilder_build(self, *a, **k),
        extra_kwargs = kwargs,
    )
    return self

def _IntAttrBuilder_build(self):
    kwargs = _Builder_to_kwargs_nobuilders(self)
    return attr.int(**kwargs)

def _AttrCfgBuilder(**kwargs):
    # todo: For attributes, cfg can be:
    # string | transition | config.exec(...) | config.target() | config.none()
    self = struct(
        _implementation = [None],
        implementation = lambda: self._implementation[0],
        set_implementation = lambda *a, **k: _AttrCfgBuilder_set_implementation(self, *a, **k),
        outputs = _SetBuilder(_kwargs_pop_list(kwargs, "outputs")),
        inputs = _SetBuilder(_kwargs_pop_list(kwargs, "inputs")),
        build = lambda: _AttrCfgBuilder_build(self),
    )
    return self

def _AttrCfgBuilder_set_implementation(self, value):
    self._implementation[0] = value

def _AttrCfgBuilder_build(self):
    impl = self._implementation[0]
    if impl == None:
        return None
    elif impl == "target":
        return config.target()
    elif impl == "exec":
        return config.exec()
    elif impl == "???":
        return config.exec(impl)
    elif types.is_function(impl):
        return transition(
            implementation = impl,
            inputs = self.inputs.build(),
            outputs = self.outputs.build(),
        )
    else:
        return impl

def _LabelAttrBuilder(**kwargs):
    # buildifier: disable=uninitialized
    self = struct(
        # value or configuration_field
        default = _Optional(kwargs, "default"),
        doc = _Optional(kwargs, "doc"),
        mandatory = _Optional(kwargs, "mandatory"),
        executable = _Optional(kwargs, "executable"),
        # True, False, or list
        allow_files = _Optional(kwargs, "allow_files"),
        allow_single_file = _Optional(kwargs, "allow_single_file"),
        providers = kwargs.pop("providers", None) or [],
        cfg = _Optional(kwargs, "cfg"),
        aspects = kwargs.pop("aspects", None) or [],
        build = lambda *a, **k: _LabelAttrBuilder_build(self, *a, **k),
        extra_kwargs = kwargs,
    )
    return self

def _LabelAttrBuilder_build(self):
    kwargs = {
        "aspects": [v.build() for v in self.aspects],
    }
    _Builder_to_kwargs_nobuilders(self, kwargs)
    for name, value in kwargs.items():
        kwargs[name] = value.build() if hasattr(value, "build") else value
    return attr.label(**kwargs)

def _LabelListAttrBuilder(**kwargs):
    self = struct(
        default = _Optional(kwargs, "default"),
        doc = _Optional(kwargs, "doc"),
        mandatory = _Optional(kwargs, "mandatory"),
        executable = _Optional(kwargs, "executable"),
        allow_empty = _Optional(kwargs, "allow_empty"),
        # True, False, or list
        allow_files = _Optional(kwargs, "allow_files"),
        providers = kwargs.pop("providers", None) or [],
        # string, config.exec_group, config.none, config.target, or transition
        # For the latter, it's a builder
        cfg = _Optional(kwargs, "cfg"),
        aspects = kwargs.pop("aspects", None) or [],
        build = lambda *a, **k: attr.label_list(**_Builder_to_kwargs_nobuilders(self, *a, **k)),
        extra_kwargs = kwargs,
    )
    return self

def _StringListAttrBuilder(**kwargs):
    self = struct(
        default = _Optional(kwargs, "default"),
        doc = _Optional(kwargs, "doc"),
        mandatory = _Optional(kwargs, "mandatory"),
        allow_empty = _Optional(kwargs, "allow_empty"),
        # True, False, or list
        build = lambda *a, **k: attr.string_list(**_Builder_to_kwargs_nobuilders(self, *a, **k)),
        extra_kwargs = kwargs,
    )
    return self

def _StringAttrBuilder(**kwargs):
    self = struct(
        default = _Optional(kwargs, "default"),
        doc = _Optional(kwargs, "doc"),
        mandatory = _Optional(kwargs, "mandatory"),
        # True, False, or list
        allow_empty = _Optional(kwargs, "allow_empty"),
        build = lambda *a, **k: attr.string(**_Builder_to_kwargs_nobuilders(self, *a, **k)),
        extra_kwargs = kwargs,
        values = kwargs.get("values") or [],
    )
    return self

def _StringDictAttrBuilder(**kwargs):
    self = struct(
        default = _kwargs_pop_dict(kwargs, "default"),
        doc = _Optional(kwargs, "doc"),
        mandatory = _Optional(kwargs, "mandatory"),
        allow_empty = _Optional(kwargs, "allow_empty"),
        build = lambda: attr.string_dict(**_Builder_to_kwargs_nobuilders(self)),
        extra_kwargs = kwargs,
    )
    return self

def _Buildable(builder_factory, kwargs_fn = None, ATTR = None, ABSTRACT = False):
    if kwargs_fn:
        kwargs = kwargs_fn()
        built = builder_factory(**kwargs_fn())
        to_builder = struct(build_kwargs = builder_factory, kwargs_fn = kwargs_fn)
    else:
        to_builder = builder_factory
        if not ABSTRACT:
            builder = builder_factory()
            if hasattr(builder, "build"):
                built = builder.build()
            elif types.is_dict(builder) and "@build" in builder:
                built = builder["@build"](**{k: v for k, v in builder.items() if k != "@build"})
            elif hasattr(builder, "build_kwargs"):
                built = builder.build_kwargs(**builder.kwargs_fn())
            else:
                fail("bad builder factory:", builder_factory, "->", builder)
    if ABSTRACT:
        return struct(
            build = to_builder().build,  # might be recursive issue?
            to_builder = to_builder,
        )
    return struct(
        built = built,
        to_builder = to_builder,
    )

rule_builders = struct(
    RuleBuilder = _RuleBuilder,
    TransitionBuilder = _TransitionBuilder,
    SetBuilder = _SetBuilder,
    Optional = _Optional,
    LabelAttrBuilder = _LabelAttrBuilder,
    LabelListAttrBuilder = _LabelListAttrBuilder,
    Buildable = _Buildable,
    IntAttrBuilder = _IntAttrBuilder,
    StringListAttrBuilder = _StringListAttrBuilder,
    StringAttrBuilder = _StringAttrBuilder,
    StringDictAttrBuilder = _StringDictAttrBuilder,
    BoolAttrBuilder = _BoolAttrBuilder,
    RuleCfgBuilder = _RuleCfgBuilder,
)
