---
trigger: glob
description: Shell / Bash scripting style and portability rules
globs: "*.sh"
---

# Shell Scripting Rules

* Use `elif` instead of nesting `if` inside an `else` block.
* When reading file paths from a manifest or list file, iterate line-by-line
  with `while IFS= read -r file; do ...; done < "$manifest"`. Do not use
  unquoted command substitution (`$(cat "$manifest")`) or suppress ShellCheck
  `SC2046` assuming paths lack spaces.
* Do not create companion `.sh` forwarders that merely pass `"$@"` to another
  executable or script.
