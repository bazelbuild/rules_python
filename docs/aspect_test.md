## aspect test

Builds the specified targets and runs all test targets among them.

### Synopsis

Builds the specified targets and runs all test targets among them (test targets
might also need to satisfy provided tag, size or language filters) using
the specified options.

This command accepts all valid options to 'build', and inherits
defaults for 'build' from your .bazelrc.  If you don't use .bazelrc,
don't forget to pass all your 'build' options to 'test' too.

See 'bazel help target-syntax' for details and examples on how to
specify targets.


```
aspect test [flags]
```

### Options

```
  -h, --help   help for test
```

### Options inherited from parent commands

```
      --config string   config file (default is $HOME/.aspect.yaml)
      --interactive     Interactive mode (e.g. prompts for user input)
```

### SEE ALSO

* [aspect](aspect.md)	 - Aspect.build bazel wrapper

