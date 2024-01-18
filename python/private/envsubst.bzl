# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Substitute environment variables in shell format strings."""

def envsubst(template_string, varnames, environ):
    """Helper function to substitute environment variables.

    Supports `$VARNAME`, `${VARNAME}` and `${VARNAME:-default}`
    syntaxes in the `template_string`, looking up each `VARNAME`
    listed in the `varnames` list in the environment defined by the
    `environ` dict. Typically called with `environ = rctx.os.environ`.

    Limitations: Unlike the shell, we don't support `${VARNAME}` and
    `${VARNAME:-default}` in the default expression for a different
    environment variable expansion. We do support the braceless syntax
    in the default, so an expression such as `${HOME:-/home/$USER}` is
    valid.

    Args:
      template_string: String that may contain variables to be expanded.
      varnames: List of variable names of variables to expand in
        `template_string`.
      environ: Dictionary mapping variable names to their values.

    Returns:
      `template_string` with environment variables expanded according
      to their values in `environ`.
    """

    if not varnames:
        return template_string

    for varname in varnames:
        value = environ.get(varname, "")
        template_string = template_string.replace("$%s" % varname, value)
        template_string = template_string.replace("${%s}" % varname, value)
        segments = template_string.split("${%s:-" % varname)
        template_string = segments.pop(0)
        for segment in segments:
            default_value, separator, rest = segment.partition("}")
            if "{" in default_value:
                fail("Environment substitution expression " +
                     "\"${%s:-\" has an opening \"{\" " % varname +
                     "in default value \"%s\"." % default_value)
            if not separator:
                fail("Environment substitution expression " +
                     "\"${%s:-\" is missing the final \"}\"" % varname)
            template_string += (value if value else default_value) + rest
    return template_string
