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

"""Text manipulation utilities useful for repository rule writing."""

def _indent(text, indent = " " * 4):
    if "\n" not in text:
        return indent + text

    return "\n".join([indent + line for line in text.splitlines()])

def _render_alias(name, actual, *, visibility = None):
    args = [
        "name = \"{}\",".format(name),
        "actual = {},".format(actual),
    ]

    if visibility:
        args.append("visibility = {},".format(render.list(visibility)))

    return "\n".join([
        "alias(",
    ] + [_indent(arg) for arg in args] + [
        ")",
    ])

def _render_dict(d, *, value_repr = repr):
    return "\n".join([
        "{",
        _indent("\n".join([
            "{}: {},".format(repr(k), value_repr(v))
            for k, v in d.items()
        ])),
        "}",
    ])

def _render_select(selects, *, no_match_error = None, value_repr = repr):
    dict_str = _render_dict(selects, value_repr = value_repr) + ","

    if no_match_error:
        args = "\n".join([
            "",
            _indent(dict_str),
            _indent("no_match_error = {},".format(no_match_error)),
            "",
        ])
    else:
        args = "\n".join([
            "",
            _indent(dict_str),
            "",
        ])

    return "select({})".format(args)

def _render_list(items):
    if not items:
        return "[]"

    if len(items) == 1:
        return "[{}]".format(repr(items[0]))

    return "\n".join([
        "[",
        _indent("\n".join([
            "{},".format(repr(item))
            for item in items
        ])),
        "]",
    ])

def _render_is_python_config_setting(name, flag_values, visibility = None, match_extra = None, constraint_values = None, **kwargs):
    rendered_kwargs = {
        "flag_values": _render_dict(flag_values),
        "name": repr(name),
    }

    if type(match_extra) == type({}):
        rendered_kwargs["match_extra"] = _render_dict(match_extra)
    elif type(match_extra) == type([]):
        rendered_kwargs["match_extra"] = _render_list(match_extra)
    elif match_extra != None:
        fail("unknown 'match_extra' type: {}".format(type(match_extra)))

    if visibility:
        rendered_kwargs["visibility"] = _render_list(visibility)

    if constraint_values:
        rendered_kwargs["constraint_values"] = _render_list(constraint_values)

    for key, value in kwargs.items():
        rendered_kwargs[key] = repr(value)

    return "is_python_config_setting(\n{}\n)".format(
        _indent("\n".join([
            "{key} = {value},".format(key = key, value = value)
            for key, value in rendered_kwargs.items()
        ])),
    )

render = struct(
    alias = _render_alias,
    dict = _render_dict,
    indent = _indent,
    list = _render_list,
    select = _render_select,
    is_python_config_setting = _render_is_python_config_setting,
)
