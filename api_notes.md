

## For rule.cfg

optional vs rule-union vs cfg-union?

* Optional: feels verbose. Requires extra get() calls.
* Optional: seems harder to detect value
* Rule-union: which API feels verbose.
* Cfg-Union: seems nicest? More underlying impl work though.

```
# optional
# Rule.cfg is type Optional[TransitionBuilder | ConfigNone | ConfigTarget]

r = RuleBuilder()
cfg = r.cfg.get()
if <cfg is TransitionBuilder>:
  cfg.inputs.append(...)
elif <cfg is config.none>:
  ...
elif <cfg is config.target>:
  ...
else: error()

# rule union
# Rule has {get,set}{cfg,cfg_none,cfg_target} functions
# which() tells which is set.
# Setting one clears the others

r = RuleBuilder()
which = r.cfg_which()
if which == "cfg":
  r.cfg().inputs.append(...)
elif which == "cfg_none":
  ...
elif which == "cfg_target":
  ...
else: error

# cfg union (1)
# Rule.cfg is type RuleCfgBuilder
# RuleConfigBuilder has {get,set}{implementation,none,target}
# Setting one clears the others

r = RuleBuilder()

if r.cfg.implementation():
  r.cfg.inputs.append(...)
elif r.cfg.none():
  ...
elif r.cfg.target():
  ...
else:
  error

# cfg-union (2)
# Make implementation attribute polymorphic
impl = r.cfg.implementation()
if impl == "none":
  ...
elif impl == "target":
  ...
else: # function
  r.cfg.inputs.append(...)

# cfg-union (3)
# impl attr is an Optional
impl = r.cfg.implementation.get()
... r.cfg.implementation.set(...) ...
```

## Copies copies everywhere

To have a nicer API, the builders should provide mutable lists/dicts/etc.

But, when they accept a user input, they can't tell if the value is mutable or
not. So they have to make copies. Most of the time, the values probably _will_
be mutable (why use a builder if its not mutable?). But its an easy mistake to
overlook that a list is referring to e.g. some global instead of a local var.

So, we could defensively copy, or just document that a mutable input is
expected, and behavior is undefined otherwise.

Alternatively, add a function to py_internal to detect immutability, and it'll
eventually be available in some bazel release.

## Collections of of complex objects

Should these be exposed as the raw collection, or a wrapper? e.g.
