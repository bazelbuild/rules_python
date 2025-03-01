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

"""Builders for creating rules, aspects et al.

When defining rules, Bazel only allows creating *immutable* objects that can't
be introspected. This makes it difficult to perform arbitrary customizations of
how a rule is defined, which makes extending a rule implementation prone to
copy/paste issues and version skew.

These builders are, essentially, mutable and inspectable wrappers for those
Bazel objects. This allows defining a rule where the values are mutable and
callers can customize them to derive their own variant of the rule while still
inheriting everything else about the rule.

To that end, the builders are not strict in how they handle values. They
generally assume that the values provided are valid and provide ways to
override their logic and force particular values to be used when they are
eventually converted to the args for calling e.g. `rule()`.

:::{important}
When using builders, most lists, dicts, et al passed into them **must** be
locally created values, otherwise they won't be mutable. This is due to Bazel's
implicit immutability rules: after evaluating a `.bzl` file, its global
variables are frozen.
:::

:::{tip}
To aid defining reusable pieces, many APIs accept no-arg callable functions
that create a builder. For example, common attributes can be stored
in a `dict[str, lambda]`, e.g. `ATTRS = {"srcs": lambda: LabelList(...)}`.
:::

Example usage:

```

load(":rule_builders.bzl", "ruleb")
load(":attr_builders.bzl", "attrb")

# File: foo_binary.bzl
_COMMON_ATTRS = {
    "srcs": lambda: attrb.LabelList(...),
}

def create_foo_binary_builder():
    foo = ruleb.Rule(
        executable = True,
    )
    foo.implementation.set(_foo_binary_impl)
    foo.attrs.update(COMMON_ATTRS)
    return foo

def create_foo_test_builder():
    foo = create_foo_binary_build()

    binary_impl = foo.implementation.get()
    def foo_test_impl(ctx):
      binary_impl(ctx)
      ...

    foo.implementation.set(foo_test_impl)
    foo.executable.set(False)
    foo.test.test(True)
    foo.attrs.update(
        _coverage = attrb.Label(default="//:coverage")
    )
    return foo

foo_binary = create_foo_binary_builder().build()
foo_test = create_foo_test_builder().build()

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
load(
    ":builders_util.bzl",
    "UniqueList",
    "Value",
    "common_to_kwargs_nobuilders",
    "kwargs_pop_dict",
    "kwargs_pop_doc",
    "kwargs_pop_list",
    "to_kwargs_get_pairs",
)

def _ExecGroup_typedef():
    """Builder for {external:bzl:obj}`exec_group`

    :::{field} toolchains
    :type: list[ToolchainType]
    :::

    :::{field} exec_compatible_with
    :type: list[str]
    :::

    :::{field} extra_kwargs
    :type: dict[str, object]
    :::

    :::{function} build() -> exec_group
    :::
    """

def _ExecGroup_new(**kwargs):
    """Creates a builder for {external:bzl:obj}`exec_group`.

    Args:
        **kwargs: Same as {external:bzl:obj}`exec_group`

    Returns:
        {type}`ExecGroup`
    """
    self = struct(
        toolchains = kwargs_pop_list(kwargs, "toolchains"),
        exec_compatible_with = kwargs_pop_list(kwargs, "exec_compatible_with"),
        extra_kwargs = kwargs,
        build = lambda: exec_group(**common_to_kwargs_nobuilders(self)),
    )
    return self

ExecGroup = struct(
    TYPEDEF = _ExecGroup_typedef,
    new = _ExecGroup_new,
)

def _ToolchainType_typedef():
    """Builder for {obj}`config_common.toolchain_type()`

    :::{field} extra_kwargs
    :type: dict[str, object]
    :::

    :::{field} mandatory
    :type: Value[bool]
    :::

    :::{field} name
    :type: Value[str | Label | None]
    :::
    """

def _ToolchainType_new(name = None, **kwargs):
    """Creates a builder for `config_common.toolchain_type`.

    Args:
        name: {type}`str | Label` the `toolchain_type` target this creates
            a dependency to.
        **kwargs: Same as {obj}`config_common.toolchain_type`

    Returns:
        {type}`ToolchainType`
    """
    self = struct(
        build = lambda: _ToolchainType_build(self),
        extra_kwargs = kwargs,
        mandatory = Value.kwargs(kwargs, "mandatory", True),
        name = Value.new(name),
    )
    return self

def _ToolchainType_build(self):
    """Builds a `config_common.toolchain_type`

    Args:
        self: implicitly added

    Returns:
        {type}`config_common.toolchain_type`
    """
    kwargs = common_to_kwargs_nobuilders(self)
    name = kwargs.pop("name")  # Name must be positional
    return config_common.toolchain_type(name, **kwargs)

ToolchainType = struct(
    TYPEDEF = _ToolchainType_typedef,
    new = _ToolchainType_new,
    build = _ToolchainType_build,
)

def _RuleCfg_typedef():
    """Wrapper for `rule.cfg` arg.

    :::{field} extra_kwargs
    :type: dict[str, object]
    :::

    :::{field} inputs
    :type: UniqueList[Label]
    :::

    :::{field} outputs
    :type: UniqueList[Label]
    :::
    """

def _RuleCfg_new(kwargs):
    """Creates a builder for the `rule.cfg` arg.

    Args:
        kwargs: Same args as `rule.cfg`

    Returns:
        {type}`RuleCfg`
    """
    if kwargs == None:
        kwargs = {}

    self = struct(
        _implementation = [kwargs.pop("implementation", None)],
        build = lambda: _RuleCfg_build(self),
        extra_kwargs = kwargs,
        implementation = lambda: _RuleCfg_implementation(self),
        inputs = UniqueList.new(kwargs, "inputs"),
        outputs = UniqueList.new(kwargs, "outputs"),
        set_implementation = lambda *a, **k: _RuleCfg_set_implementation(self, *a, **k),
    )
    return self

def _RuleCfg_set_implementation(self, value):
    """Set the implementation method.

    Args:
        self: implicitly added.
        value: {type}`str | function` a valid `rule.cfg` argument value.
    """
    self._implementation[0] = value

def _RuleCfg_implementation(self):
    """Returns the implementation name or function for the cfg transition.

    Returns:
        {type}`str | function`
    """
    return self._implementation[0]

def _RuleCfg_build(self):
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

RuleCfg = struct(
    TYPEDEF = _RuleCfg_typedef,
    new = _RuleCfg_new,
    implementation = _RuleCfg_implementation,
    set_implementation = _RuleCfg_set_implementation,
    build = _RuleCfg_build,
)

def _Rule_typedef():
    """A builder to accumulate state for constructing a `rule` object.

    :::{field} attrs
    :type: AttrsDict
    :::

    :::{field} cfg
    :type: RuleCfg
    :::

    :::{field} doc
    :type: Value[str]
    :::

    :::{field} exec_groups
    :type: dict[str, ExecGroup]
    :::

    :::{field} executable
    :type: Value[bool]
    :::

    :::{field} extra_kwargs
    :type: dict[str, Any]

    Additional keyword arguments to use when constructing the rule. Their
    values have precedence when creating the rule kwargs. This is, essentially,
    an escape hatch for manually overriding or inserting values into
    the args passed to `rule()`.
    :::

    :::{field} fragments
    :type: list[str]
    :::

    :::{field} implementation
    :type: Value[callable | None]
    :::

    :::{field} provides
    :type: list[Provider | list[Provider]]
    :::

    :::{field} test
    :type: Value[bool]
    :::

    :::{field} toolchains
    :type: list[ToolchainType]
    :::
    """

def _Rule_new(implementation = None, **kwargs):
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
        cfg = _RuleCfg_new(kwargs.pop("cfg", None)),
        doc = kwargs_pop_doc(kwargs),
        exec_groups = kwargs_pop_dict(kwargs, "exec_groups"),
        executable = Value.kwargs(kwargs, "executable", False),
        fragments = kwargs_pop_list(kwargs, "fragments"),
        implementation = Value.new(implementation),
        extra_kwargs = kwargs,
        provides = kwargs_pop_list(kwargs, "provides"),
        test = Value.kwargs(kwargs, "test", False),
        toolchains = kwargs_pop_list(kwargs, "toolchains"),
        build = lambda *a, **k: _Rule_build(self, *a, **k),
        to_kwargs = lambda *a, **k: _Rule_to_kwargs(self, *a, **k),
    )
    return self

def _Rule_build(self, debug = ""):
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

def _Rule_to_kwargs(self):
    """Builds the arguments for calling `rule()`.

    This is added as an escape hatch to construct the final values `rule()`
    kwarg values in case callers want to manually change them.

    Args:
        self: implicitly added

    Returns:
        {type}`dict`
    """

    kwargs = dict(self.extra_kwargs)
    if "exec_groups" not in kwargs:
        for k, v in self.exec_groups.items():
            if not hasattr(v, "build"):
                fail("bad execgroup", k, v)
        kwargs["exec_groups"] = {
            k: v.build()
            for k, v in self.exec_groups.items()
        }
    if "toolchains" not in kwargs:
        kwargs["toolchains"] = [
            v.build()
            for v in self.toolchains
        ]

    for name, value in to_kwargs_get_pairs(self, kwargs):
        value = value.build() if hasattr(value, "build") else value
        kwargs[name] = value
    return kwargs

Rule = struct(
    TYPEDEF = _Rule_typedef,
    new = _Rule_new,
    build = _Rule_build,
    to_kwargs = _Rule_to_kwargs,
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
    """Creates a builder for the `rule.attrs` dict.

    Args:
        initial: {type}`dict[str, callable | AttributeBuilder]` dict of initial
            values to populate the attributes dict with.

    Returns:
        {type}`AttrsDict`
    """
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
        attrs[k] = v.build() if hasattr(v, "build") else v
    return attrs

AttrsDict = struct(
    TYPEDEF = _AttrsDict_typedef,
    new = _AttrsDict_new,
    update = _AttrsDict_update,
    build = _AttrsDict_build,
)

ruleb = struct(
    Rule = _Rule_new,
    ToolchainType = _ToolchainType_new,
    ExecGroup = _ExecGroup_new,
)
