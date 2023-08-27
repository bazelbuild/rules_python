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

def _isdigit(token):
    return token.isdigit()

def _isalnum(token):
    return token.isalnum()

def _lower(token):
    # PEP 440: Case sensitivity
    return token.lower()

def normalize_pep440(version):
    """Escape the version component of a filename.

    See https://packaging.python.org/en/latest/specifications/binary-distribution-format/#escaping-and-unicode
    and https://peps.python.org/pep-0440/

    Args:
      version: version string to be normalized according to PEP 440.

    Returns:
      string containing the normalized version.
    """

    self = struct(
        version = version.strip(),  # PEP 440: Leading and Trailing Whitespace
        contexts = [],
    )

    def open_context(start):
        """Open an new parsing context.

        If the current parsing step succeeds, call close_context().
        If the current parsing step fails, call contexts.pop() to
        go back to how it was before we opened a new context.

        Args:
          start: index into `version` indicating where the current
            parsing step starts.
        """
        self.contexts.append({"norm": "", "start": start})
        return self.contexts[-1]

    def close_context():
        """Close the current context successfully and merge the results."""
        finished = self.contexts.pop()
        self.contexts[-1]["norm"] += finished["norm"]
        self.contexts[-1]["start"] = finished["start"]

    def is_(reference):
        """Predicate testing a token for equality with `reference`."""
        return lambda token: token == reference

    def is_not(reference):
        """Predicate testing a token for inequality with `reference`."""
        return lambda token: token != reference

    def in_(reference):
        """Predicate testing if a token is in the list `reference`."""
        return lambda token: token in reference

    def accept(predicate, value):
        """If `predicate` matches the next token, accept the token.

        Accepting the token means adding it (according to `value`) to
        the running results maintained in context["norm"] and
        advancing the cursor in context["start"] to the next token in
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

        context = self.contexts[-1]

        if context["start"] >= len(self.version):
            return False

        token = self.version[context["start"]]

        if predicate(token):
            if type(value) in ["function", "builtin_function_or_method"]:
                value = value(token)

            context["norm"] += value
            context["start"] += 1
            return True

        return False

    def accept_placeholder():
        """Accept a Bazel placeholder.

        Placeholders aren't actually part of PEP 440, but are used for
        stamping purposes. A placeholder might be
        ``{BUILD_TIMESTAMP}``, for instance. We'll accept these as
        they are, assuming they will expand to something that makes
        sense where they appear. Before the stamping has happened, a
        resulting wheel file name containing a placeholder will not
        actually be valid.

        """
        context = open_context(self.contexts[-1]["start"])

        if not accept(is_("{"), str):
            self.contexts.pop()
            return False

        start = context["start"]
        for _ in range(start, len(self.version) + 1):
            if not accept(is_not("}"), str):
                break

        if not accept(is_("}"), str):
            self.contexts.pop()
            return False

        close_context()
        return True

    def accept_digits():
        """Accept multiple digits (or placeholders)."""

        context = open_context(self.contexts[-1]["start"])
        start = context["start"]

        for i in range(start, len(self.version) + 1):
            if not accept(_isdigit, str) and not accept_placeholder():
                if i - start >= 1:
                    if context["norm"].isdigit():
                        # PEP 440: Integer Normalization
                        context["norm"] = str(int(context["norm"]))
                    close_context()
                    return True
                break

        self.contexts.pop()
        return False

    def accept_string(string, replacement):
        """Accept a `string` in the input. Output `replacement`."""
        context = open_context(self.contexts[-1]["start"])

        for character in string.elems():
            if not accept(in_([character, character.upper()]), ""):
                self.contexts.pop()
                return False

        context["norm"] = replacement

        close_context()
        return True

    def accept_alnum():
        """Accept an alphanumeric sequence."""

        context = open_context(self.contexts[-1]["start"])
        start = context["start"]

        for i in range(start, len(self.version) + 1):
            if not accept(_isalnum, _lower) and not accept_placeholder():
                if i - start >= 1:
                    close_context()
                    return True
                break

        self.contexts.pop()
        return False

    def accept_dot_number():
        """Accept a dot followed by digits."""
        open_context(self.contexts[-1]["start"])

        if accept(is_("."), ".") and accept_digits():
            close_context()
            return True
        else:
            self.contexts.pop()
            return False

    def accept_dot_number_sequence():
        """Accept a sequence of dot+digits."""
        context = self.contexts[-1]
        start = context["start"]
        i = start

        for i in range(start, len(self.version) + 1):
            if not accept_dot_number():
                break
        return i - start >= 1

    def accept_separator_alnum():
        """Accept a separator followed by an alphanumeric string."""
        open_context(self.contexts[-1]["start"])

        # PEP 440: Local version segments
        if (
            accept(in_([".", "-", "_"]), ".") and
            (accept_digits() or accept_alnum())
        ):
            close_context()
            return True

        self.contexts.pop()
        return False

    def accept_separator_alnum_sequence():
        """Accept a sequence of separator+alphanumeric."""
        context = self.contexts[-1]
        start = context["start"]
        i = start

        for i in range(start, len(self.version) + 1):
            if not accept_separator_alnum():
                break

        return i - start >= 1

    def accept_epoch():
        """PEP 440: Version epochs."""
        context = open_context(self.contexts[-1]["start"])
        if accept_digits() and accept(is_("!"), "!"):
            if context["norm"] == "0!":
                self.contexts.pop()
                self.contexts[-1]["start"] = context["start"]
            else:
                close_context()
            return True
        else:
            self.contexts.pop()
            return False

    def accept_release():
        """Accept the release segment, numbers separated by dots."""
        open_context(self.contexts[-1]["start"])

        if not accept_digits():
            self.contexts.pop()
            return False

        accept_dot_number_sequence()
        close_context()
        return True

    def accept_pre_l():
        """PEP 440: Pre-release spelling."""
        open_context(self.contexts[-1]["start"])

        if (
            accept_string("alpha", "a") or
            accept_string("a", "a") or
            accept_string("beta", "b") or
            accept_string("b", "b") or
            accept_string("c", "rc") or
            accept_string("preview", "rc") or
            accept_string("pre", "rc") or
            accept_string("rc", "rc")
        ):
            close_context()
            return True
        else:
            self.contexts.pop()
            return False

    def accept_prerelease():
        """PEP 440: Pre-releases."""
        context = open_context(self.contexts[-1]["start"])

        # PEP 440: Pre-release separators
        accept(in_(["-", "_", "."]), "")

        if not accept_pre_l():
            self.contexts.pop()
            return False

        accept(in_(["-", "_", "."]), "")

        if not accept_digits():
            # PEP 440: Implicit pre-release number
            context["norm"] += "0"

        close_context()
        return True

    def accept_implicit_postrelease():
        """PEP 440: Implicit post releases."""
        context = open_context(self.contexts[-1]["start"])

        if accept(is_("-"), "") and accept_digits():
            context["norm"] = ".post" + context["norm"]
            close_context()
            return True

        self.contexts.pop()
        return False

    def accept_explicit_postrelease():
        """PEP 440: Post-releases."""
        context = open_context(self.contexts[-1]["start"])

        # PEP 440: Post release separators
        if not accept(in_(["-", "_", "."]), "."):
            context["norm"] += "."

        # PEP 440: Post release spelling
        if (
            accept_string("post", "post") or
            accept_string("rev", "post") or
            accept_string("r", "post")
        ):
            accept(in_(["-", "_", "."]), "")

            if not accept_digits():
                # PEP 440: Implicit post release number
                context["norm"] += "0"

            close_context()
            return True

        self.contexts.pop()
        return False

    def accept_postrelease():
        """PEP 440: Post-releases."""
        open_context(self.contexts[-1]["start"])

        if accept_implicit_postrelease() or accept_explicit_postrelease():
            close_context()
            return True

        self.contexts.pop()
        return False

    def accept_devrelease():
        """PEP 440: Developmental releases."""
        context = open_context(self.contexts[-1]["start"])

        # PEP 440: Development release separators
        if not accept(in_(["-", "_", "."]), "."):
            context["norm"] += "."

        if accept_string("dev", "dev"):
            accept(in_(["-", "_", "."]), "")

            if not accept_digits():
                # PEP 440: Implicit development release number
                context["norm"] += "0"

            close_context()
            return True

        self.contexts.pop()
        return False

    def accept_local():
        """PEP 440: Local version identifiers."""
        open_context(self.contexts[-1]["start"])

        if accept(is_("+"), "+") and accept_alnum():
            accept_separator_alnum_sequence()
            close_context()
            return True

        self.contexts.pop()
        return False

    open_context(0)
    accept(is_("v"), "")  # PEP 440: Preceding v character
    accept_epoch()
    accept_release()
    accept_prerelease()
    accept_postrelease()
    accept_devrelease()
    accept_local()
    if self.version[self.contexts[-1]["start"]:]:
        fail(
            "Failed to parse PEP 440 version identifier '%s'." % self.version,
            "Parse error at '%s'" % self.version[self.contexts[-1]["start"]:],
        )
    return self.contexts[-1]["norm"]
