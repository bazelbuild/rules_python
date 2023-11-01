# Glossary

{.glossary}

common attributes
: Every rule has a set of common attributes. See Bazel's
  [Common attributes](https://bazel.build/reference/be/common-definitions#common-attributes)
  for a complete listing

rule callable
: A function that behaves like a rule. This includes, but is not is not
  limited to:
  * Accepts a `name` arg and other {term}`common attributes`.
  * Has no return value (i.e. returns `None`).
  * Creates at least a target named `name`

  There is usually an implicit interface about what attributes and values are
  accepted; refer to the respective API accepting this type.

simple label
: A `str` or `Label` object but not a _direct_ `select` object. These usually
  mean a string manipulation is occuring, which can't be done on `select`
  objects. Such attributes are usually still configurable if an alias is used,
  and a reference to the alias is passed instead.

nonconfigurable
: A nonconfigurable value cannot use `select`. See Bazel's
  [configurable attributes](https://bazel.build/reference/be/common-definitions#configurable-attributes) documentation.
