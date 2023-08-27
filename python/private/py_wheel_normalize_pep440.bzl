# Copyright 2023 The Bazel Authors. All rights reserved.
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

"Implementation of PEP440 version string normalization"

def mkmethod(self, method):
    """Bind a struct as the first arg to a function.

    This is loosely equivalent to creating a bound method of a class.
    """
    return lambda *args, **kwargs: method(self, *args, **kwargs)

def _isdigit(token):
    return token.isdigit()

def _isalnum(token):
    return token.isalnum()

def _lower(token):
    # PEP 440: Case sensitivity
    return token.lower()

def _is(reference):
    """Predicate testing a token for equality with `reference`."""
    return lambda token: token == reference

def _is_not(reference):
    """Predicate testing a token for inequality with `reference`."""
    return lambda token: token != reference

def _in(reference):
    """Predicate testing if a token is in the list `reference`."""
    return lambda token: token in reference

def _ctx(start):
    return {"norm": "", "start": start}

def _open_context(self):
    """Open an new parsing ctx.

    If the current parsing step succeeds, call self.close_context().
    If the current parsing step fails, call contexts.pop() to
    go back to how it was before we opened a new ctx.

    Args:
      self: The normalizer.
      start: index into `version` indicating where the current
        parsing step starts.
    """
    self.contexts.append(_ctx(_context(self)["start"]))
    return self.contexts[-1]

def _close_context(self):
    """Close the current ctx successfully and merge the results."""
    finished = self.contexts.pop()
    self.contexts[-1]["norm"] += finished["norm"]
    self.contexts[-1]["start"] = finished["start"]

def _context(self):
    return self.contexts[-1]

def _pop_context(self):
    return self.contexts.pop()

def _new(input):
    """Create a new normalizer"""
    self = struct(
        input = input,
        contexts = [_ctx(0)],
    )

    public = struct(
        # methods: keep sorted
        close_context = mkmethod(self, _close_context),
        context = mkmethod(self, _context),
        open_context = mkmethod(self, _open_context),
        pop_context = mkmethod(self, _pop_context),

        # attributes: keep sorted
        input = self.input,
    )
    return public

def accept(parser, predicate, value):
    """If `predicate` matches the next token, accept the token.

    Accepting the token means adding it (according to `value`) to
    the running results maintained in ctx["norm"] and
    advancing the cursor in ctx["start"] to the next token in
    `version`.

    Args:
      predicate: function taking a token and returning a boolean
        saying if we want to accept the token.
      value: the string to add if there's a match, or, if `value`
        is a function, the function to apply to the current token
        to get the string to add.

    Returns:
      whether a token was accepted.
    """

    ctx = parser.context()

    if ctx["start"] >= len(parser.input):
        return False

    token = parser.input[ctx["start"]]

    if predicate(token):
        if type(value) in ["function", "builtin_function_or_method"]:
            value = value(token)

        ctx["norm"] += value
        ctx["start"] += 1
        return True

    return False

def accept_placeholder(parser):
    """Accept a Bazel placeholder.

    Placeholders aren't actually part of PEP 440, but are used for
    stamping purposes. A placeholder might be
    ``{BUILD_TIMESTAMP}``, for instance. We'll accept these as
    they are, assuming they will expand to something that makes
    sense where they appear. Before the stamping has happened, a
    resulting wheel file name containing a placeholder will not
    actually be valid.

    """
    ctx = parser.open_context()

    if not accept(parser, _is("{"), str):
        parser.pop_context()
        return False

    start = ctx["start"]
    for _ in range(start, len(parser.input) + 1):
        if not accept(parser, _is_not("}"), str):
            break

    if not accept(parser, _is("}"), str):
        parser.pop_context()
        return False

    parser.close_context()
    return True

def accept_digits(parser):
    """Accept multiple digits (or placeholders)."""

    ctx = parser.open_context()
    start = ctx["start"]

    for i in range(start, len(parser.input) + 1):
        if not accept(parser, _isdigit, str) and not accept_placeholder(parser):
            if i - start >= 1:
                if ctx["norm"].isdigit():
                    # PEP 440: Integer Normalization
                    ctx["norm"] = str(int(ctx["norm"]))
                parser.close_context()
                return True
            break

    parser.pop_context()
    return False

def accept_string(parser, string, replacement):
    """Accept a `string` in the input. Output `replacement`."""
    ctx = parser.open_context()

    for character in string.elems():
        if not accept(parser, _in([character, character.upper()]), ""):
            parser.pop_context()
            return False

    ctx["norm"] = replacement

    parser.close_context()
    return True

def accept_alnum(parser):
    """Accept an alphanumeric sequence."""

    ctx = parser.open_context()
    start = ctx["start"]

    for i in range(start, len(parser.input) + 1):
        if not accept(parser, _isalnum, _lower) and not accept_placeholder(parser):
            if i - start >= 1:
                parser.close_context()
                return True
            break

    parser.pop_context()
    return False

def accept_dot_number(parser):
    """Accept a dot followed by digits."""
    parser.open_context()

    if accept(parser, _is("."), ".") and accept_digits(parser):
        parser.close_context()
        return True
    else:
        parser.pop_context()
        return False

def accept_dot_number_sequence(parser):
    """Accept a sequence of dot+digits."""
    ctx = parser.context()
    start = ctx["start"]
    i = start

    for i in range(start, len(parser.input) + 1):
        if not accept_dot_number(parser):
            break
    return i - start >= 1

def accept_separator_alnum(parser):
    """Accept a separator followed by an alphanumeric string."""
    parser.open_context()

    # PEP 440: Local version segments
    if (
        accept(parser, _in([".", "-", "_"]), ".") and
        (accept_digits(parser) or accept_alnum(parser))
    ):
        parser.close_context()
        return True

    parser.pop_context()
    return False

def accept_separator_alnum_sequence(parser):
    """Accept a sequence of separator+alphanumeric."""
    ctx = parser.context()
    start = ctx["start"]
    i = start

    for i in range(start, len(parser.input) + 1):
        if not accept_separator_alnum(parser):
            break

    return i - start >= 1

def accept_epoch(parser):
    """PEP 440: Version epochs."""
    ctx = parser.open_context()
    if accept_digits(parser) and accept(parser, _is("!"), "!"):
        if ctx["norm"] == "0!":
            parser.pop_context()
            parser.context()["start"] = ctx["start"]
        else:
            parser.close_context()
        return True
    else:
        parser.pop_context()
        return False

def accept_release(parser):
    """Accept the release segment, numbers separated by dots."""
    parser.open_context()

    if not accept_digits(parser):
        parser.pop_context()
        return False

    accept_dot_number_sequence(parser)
    parser.close_context()
    return True

def accept_pre_l(parser):
    """PEP 440: Pre-release spelling."""
    parser.open_context()

    if (
        accept_string(parser, "alpha", "a") or
        accept_string(parser, "a", "a") or
        accept_string(parser, "beta", "b") or
        accept_string(parser, "b", "b") or
        accept_string(parser, "c", "rc") or
        accept_string(parser, "preview", "rc") or
        accept_string(parser, "pre", "rc") or
        accept_string(parser, "rc", "rc")
    ):
        parser.close_context()
        return True
    else:
        parser.pop_context()
        return False

def accept_prerelease(parser):
    """PEP 440: Pre-releases."""
    ctx = parser.open_context()

    # PEP 440: Pre-release separators
    accept(parser, _in(["-", "_", "."]), "")

    if not accept_pre_l(parser):
        parser.pop_context()
        return False

    accept(parser, _in(["-", "_", "."]), "")

    if not accept_digits(parser):
        # PEP 440: Implicit pre-release number
        ctx["norm"] += "0"

    parser.close_context()
    return True

def accept_implicit_postrelease(parser):
    """PEP 440: Implicit post releases."""
    ctx = parser.open_context()

    if accept(parser, _is("-"), "") and accept_digits(parser):
        ctx["norm"] = ".post" + ctx["norm"]
        parser.close_context()
        return True

    parser.pop_context()
    return False

def accept_explicit_postrelease(parser):
    """PEP 440: Post-releases."""
    ctx = parser.open_context()

    # PEP 440: Post release separators
    if not accept(parser, _in(["-", "_", "."]), "."):
        ctx["norm"] += "."

    # PEP 440: Post release spelling
    if (
        accept_string(parser, "post", "post") or
        accept_string(parser, "rev", "post") or
        accept_string(parser, "r", "post")
    ):
        accept(parser, _in(["-", "_", "."]), "")

        if not accept_digits(parser):
            # PEP 440: Implicit post release number
            ctx["norm"] += "0"

        parser.close_context()
        return True

    parser.pop_context()
    return False

def accept_postrelease(parser):
    """PEP 440: Post-releases."""
    parser.open_context()

    if accept_implicit_postrelease(parser) or accept_explicit_postrelease(parser):
        parser.close_context()
        return True

    parser.pop_context()
    return False

def accept_devrelease(parser):
    """PEP 440: Developmental releases."""
    ctx = parser.open_context()

    # PEP 440: Development release separators
    if not accept(parser, _in(["-", "_", "."]), "."):
        ctx["norm"] += "."

    if accept_string(parser, "dev", "dev"):
        accept(parser, _in(["-", "_", "."]), "")

        if not accept_digits(parser):
            # PEP 440: Implicit development release number
            ctx["norm"] += "0"

        parser.close_context()
        return True

    parser.pop_context()
    return False

def accept_local(parser):
    """PEP 440: Local version identifiers."""
    parser.open_context()

    if accept(parser, _is("+"), "+") and accept_alnum(parser):
        accept_separator_alnum_sequence(parser)
        parser.close_context()
        return True

    parser.pop_context()
    return False

def normalize_pep440(version):
    """Escape the version component of a filename.

    See https://packaging.python.org/en/latest/specifications/binary-distribution-format/#escaping-and-unicode
    and https://peps.python.org/pep-0440/

    Args:
      version: version string to be normalized according to PEP 440.

    Returns:
      string containing the normalized version.
    """
    parser = _new(version.strip())  # PEP 440: Leading and Trailing Whitespace
    accept(parser, _is("v"), "")  # PEP 440: Preceding v character
    accept_epoch(parser)
    accept_release(parser)
    accept_prerelease(parser)
    accept_postrelease(parser)
    accept_devrelease(parser)
    accept_local(parser)
    if parser.input[parser.context()["start"]:]:
        fail(
            "Failed to parse PEP 440 version identifier '%s'." % parser.input,
            "Parse error at '%s'" % parser.input[parser.context()["start"]:],
        )
    return parser.context()["norm"]
