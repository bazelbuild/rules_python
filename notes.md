NOTES

TLDR

Two API choices to make:
1. (a) struct vs (b) dict
2. (a) less CPU/memory vs (b) nicer ergonomics

Question: worth worrying about CPU/memory overhead? This is just loading
phase to construct the few dozen objects that are fed into rule creation

EXAMPLE: CPU/memory vs ergonomics examples

```
# 1a + 2a: struct; uses less cpu/memory; worse ergonomics
def create_custom_rule()
  r = py_binary_builder()
  srcs = r.attrs["srcs"].to_mutable()
  r.attrs["srcs"] = srcs
  srcs.default.append("//bla")
  cfg = srcs.cfg.get().to_mutable()
  srcs.cfg.set(cfg)
  cfg.inputs.append("whatever")

# 1a+2b: struct; uses more cpu/memory; nicer ergonomics
def create_custom_rule()
  r = py_binary_builder()
  srcs = r.attrs["srcs"]
  srcs.default.append("//bla")
  srcs.cfg.inputs.append("whatever")
  return r.build()

# 1b+2a: dict; uses less cpu/memory; worse ergonomics
def create_custom_rule():
  r = py_binary_rule_kwargs()
  srcs = dict(r["attrs"]["srcs"])
  r["attrs"]["srcs"] = srcs
  srcs["default"] = list(srcs["default"])
  srcs["default"].append("//bla")
  cfg = dict(srcs["cfg"])
  srcs["cfg"] = cfg
  cfg["inputs"] = list(cfg["inputs"])
  cfg["inputs"].append("whatever")

  return rule(**r)

# 1b+2b: dict; uses more cpu/memory; nicer ergonomics
def create_custom_rule():
  r = py_binary_rule_kwargs()
  srcs = r["attrs"]["srcs"]
  srcs["default"].append("//bla")
  srcs["cfg"]["inputs"].append("whatever")
  return rule(**r)

```

Ergonomic highlights:
* Dicts don't need the `xx.{get,set}` stuff; you can just directly
  assign without a wrapper.
* Structs don't need `x[key] = list(x[key])` stuff. They can ensure their
  lists/dicts are mutable themselves.
  * Can somewhat absolve this: just assume things are mutable
* Structs _feel_ more "solid". Like a real API.
* Structs give us API control; dicts don't.

---------

Our goals are to allow users to derive new rules based upon ours. This translates to
two things:
* Specifying an implementation function. This allows them to introduce their own
  logic. (Hooking into our impl function is for another time)
* Customizing the rule() kwargs. This is necessary because a different
  implementation function almost certainly requires _something_ different in the
  rule() kwargs. It may be new attributes or modifications to existing
  attributes; we can't know and don't care. Most other rule() kwargs they want
  to automatically inherit; they are either internal details or upstream
  functionality they want to automatically benefit from.

So, we need some way to for users to intercept the rule kwargs before they're
turned into immutable objects (attr.xxx, transition(), exec_group(), etc etc)
that they can't introspect or modify.

Were we using a more traditional language, we'd probably have classes:
```
class PyBinaryRule(Rule): ...
class UserPyBinaryRule(PyBinary): ...
```

And have various methods for how different pieces are created.

We don't have classes or inheritence, though, so we have to find other avenues.

====================

A key constraint are Bazel's immutability rules.

* Objects are mutable within the thread that creates them.
* Each bzl file evaluation is a separate thread.

Translated:
* Assigning a list/dict (_directly or indirectly_) to a global var makes it
  immutable once the bzl file is finished being evaluated.
* A work around to this limitation is to use a function/lambda. When `foo.bzl` calls
  `bar.bzl%create_builder()`, it is foo.bzl's thread creating _new_ objects, so
  they are returned as mutable objects.

Relatedly, this means mutability has to be "top down". e.g. given
`x: dict[str, dict[str, int]] = ...`, in order to modify
the inner dict, the outer dict must also be mutable. It's not possible
for an immutable object to reference a mutable object because Bazel
makes things recursively immutable when the thread ends.

What this means for us:

1. In order for us to expose objects users can modify, we _must_ provide them
   with a function to create the objects they will modify. How they call that
   function is up to us and defines our public API for this.
2. Whatever we expose, we cannot return immutable objects, e.g. `attr.string()`,
   `transition()`, `exec_group()`, et al, or direct references to e.g. global
   vars. Such objects are immutable, many cannot be introspected, and
   immutability can't be detected; this prevents a user from customizing.

====================

Unfortunately, everything we're dealing with is some sort of container whose
contents users may want to arbitrarily modify. A type-wise description
looks something like:

```
class Rule:
    implementation: function
    test: bool | unset
    attrs: dict[str name, Attribute]
    cfg: string | ExecGroup | Transition

class LabelListAttribute(Attribute):
    default: list[string | Label]
    cfg: string | ExecGroup | Transition

class Transition:
    implementation: function
    inputs: list[string]
    outputs: list[string]

```

Where calling e.g `Rule()` can be translated to using `struct(...)` or
`dict(...)` in Starlark.

All these containers of values mean the top-down immutability rules are
prominent and affect the API. Lets discuss that next.

====================

Recall:

* Deep immutable: after calling `x = py_executable_builder()`
  the result is a "mutable rule" object.  Every part (i.e. dict/lists) of `x`
  is mutable, recursively. e.g. `x.foo["y"].z.append(1)` works.
* Shallow immutable: after calling `x = py_executable_builder()`,
  the result is a "mutable rule" object, but only the attributes/objects that
  directly belong to it are _guaranteed_ mutable. e.g.
  * works: `x.foo["y"] = ...`
  * may not work: `x.foo["y"].z.append(1)`

If it's deep mutable, then the user API is easy, but it costs more CPU to
create and costs more memory (equivalent objects are created multiple times).

If it's shallow mutable, then the user API is harder. To allow mutability,
objects must provide a lambda to re-create themselves. Being a "builder" isn't
sufficient; it must have been created in the current thread context.

Let's explore the implications of shallow vs deep immutability.

1. Everything always deep immutable

Each rule calls `create_xxx_rule_builder()`, the result is deep mutable.
* Pro: Easy
* Con: Wasteful. Most things aren't customized. Equivalent attributes,
  transitions, etc objects get recreated instead of reused (Bazel doesn't do
  anything smart with them when they're logically equivalent, and it can't
  because each call carries various internal debug state info)

2. Shallow immutability

The benefit shallow immutability brings is objects (e.g. attr.xxx etc) are
only recreated when they're modified.

Each rule calls `create_xxx_rule_builder`, the result is shallow mutable. e.g.
`x.attrs` is a mutable dict, but the values may not be mutable. If we want
to modify something deeper, the object has its `to_mutable()` method called.
This create a mutable version of the object (shallow or deep? read on).

Under the hood, the way this works is objects have an immutable version of
themselves and function to create an equivalent mutable version of themselves.
e.g., creating an attribute looks like this:
```
def Attr(builder_factory):
  builder = builder_factory()
  built = builder.build()
  return struct(built=built, to_mutable = builder_factory)

def LabelListBuilder(default):
  self = struct(
    default = default
    to_mutable = lambda: self
    build = lambda: attr.label(default=self.default)
  )
  return self

SRCS = Attr(lambda: LabelListBuilder(default=["a"]))
def base():
  builder.attrs["srcs"] = SRCS

def custom():
  builder = base()
  srcs = builder.attrs["srcs"].to_mutable()
  srcs["default"].append("b")
  builder.attrs["srcs"] = srcs
```

When the final `rule()` kwargs are created, the logic checks for obj.built and
uses it if present. Otherwise it calls e.g. `obj.build()` to create it.

The disadvantage is the API is more complicated. You have to remember to call
`to_mutable()` and reassign the value.

If the return value of `to_mutable()` is deep immutable, then this is as
complicated as the API gets. You just call it once, at the "top".

If the return value of `to_mutable()` is _also_ shallow mutable, then this is
API complication is recursive in nature. e.g, lets say we want to modify the
inputs for an attributes's transition when things are shallow immutable:

```
def custom():
  builder = base()
  srcs = builder.attrs["srcs"].to_mutable() # -> LabelListBuilder
  cfg = srcs.cfg.to_mutable() # TransitionBuilder
  cfg.inputs.append("bla")
  srcs.cfg.set(cfg) # store our modified cfg back into the attribute
  builder.attrs["srcs"] = srcs # store modified attr back into the rule attrs
```

Pretty tedious.

Also, the nature of the top-down mutability constraint somewhat works against
the design goal here. We avoid having to recreate _all_ the objects for a rule,
but we still had to re-create the direct values that the srcs Attribute object
manages. So less work, but definitely not precise.

3. Mix/Match of immutability

A compromise between (1) and (2) is for `to_mutable()` to be shallow for some
things but deep for others.

* Rule is shallow immutable. e.g. `Rule.attrs` is a mutable dict, but contains
  immutable Attribute objects.
* Attribute.to_mutable returns a deep mutable object. This avoids having to
  call to_mutable() many times and reassign up the object tree.

--------------------

Alternative: visitor pattern

Instead of returning a mutable value to users to modify, users pass in a
Visitor object, which has methods to handle rule kwarg building. e.g.

```
SRCS = Attr(lambda: LabelListBuilder(...))

def create_executable_rule(visitor):
  kwargs = visitor.init_kwargs(visitor)
  kwargs["srcs"] = visitor.add_attr("srcs", SRCS.built, SRCS.to_mutable)
  kwargs = visitor.finalize_kwargs(kwargs)
  return rule(**kwargs)

def visitor():
  return struct(
     add_attr = visit_add_attr,
     ...
  )

def customize_add_attr(name, built, new_builder):
  if name != "srcs":
    return built
  builder = new_builder()
  builder.default.append("custom")
  return builder.build()

custom_rule = create_executable_rule(visitor())
```

Unfortunately, this doesn't change things too much. The same issue of object
reuse vs immutability show up. This actually seems _worse_ because now
a user has to do pseudo-object-oriented Starlark for even small changes.


--------------------

Alternative: overrride values

The idea here is to return immutable values to benefit from better cpu/memory
usage. To modify something, a user calls a function to create a mutable version
of it, then overwrites the value entirely.

```
load(":base.bzl", "create_srcs_attr_builder", "create_cfg_builder")
def custom_rule():
    builder = base()
    srcs = create_srcs_attr_builder()
    srcs.providers.append("bla")

    cfg = create_cfg_builder()
    cfg.inputs.append("bla")
    builder.cfg.set(cfg)
```

This is similar to having a `to_mutable()` method. The difference is there are
no wrapper objects in between. e.g. the builder.attrs dict contains attr.xxx
objects, instead of `struct(built=<value>, to_mutable=<func>)`
