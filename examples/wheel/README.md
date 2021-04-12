This is a sample description of a wheel.

### py_wheel directory structure
The py_wheel target offers two means of directly manipulating the directory structure of the output .whl: `strip_path_prefixes` and `map_path_prefixes`. These allow you to use your own convention for the package directories, similar to the use of [distutils `package_dir`](https://docs.python.org/3/distutils/setupscript.html#listing-whole-packages).

#### strip_path_prefixes
This argument takes in a list of strings representing prefixes to strip from your .whl. Each prefix will be stripped from each filename in the order that the prefixes are listed. You can see this in the targets `:custom_package_root`, `:custom_package_root_multi_prefix`, and `:custom_package_root_multi_prefix_reverse_order`.

#### map_path_prefixes
This argument takes in a list of strings in the format 'key=value' where the `key` represents a prefix to be stripped out and the `value` represents a string to replace that prefix with. Note that the `map_path_prefixes` argument will always execute after the `strip_path_prefixes` argument. You can see examples of `map_path_prefixes` in the targets `:custom_package_root_map_prefixes` and `:custom_package_root_strip_and_map_prefixes`.