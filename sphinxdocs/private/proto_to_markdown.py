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

import argparse
import io
import itertools
import pathlib
import sys
import textwrap
from typing import Callable, TextIO, TypeVar

from stardoc.proto import stardoc_output_pb2

_AttributeType = stardoc_output_pb2.AttributeType

_T = TypeVar("_T")


def _anchor_id(text: str) -> str:
    # MyST/Sphinx's markdown processing doesn't like dots in anchor ids.
    return "#" + text.replace(".", "_").lower()


# Create block attribute line.
# See https://myst-parser.readthedocs.io/en/latest/syntax/optional.html#block-attributes
def _block_attrs(*attrs: str) -> str:
    return "{" + " ".join(attrs) + "}\n"


def _link(display: str, link: str = "", *, ref: str = "", classes: str = "") -> str:
    if ref:
        ref = f"[{ref}]"
    if link:
        link = f"({link})"
    if classes:
        classes = "{" + classes + "}"
    return f"[{display}]{ref}{link}{classes}"


def _span(display: str, classes: str = ".span") -> str:
    return f"[{display}]{{" + classes + "}"


def _link_here_icon(anchor: str) -> str:
    # The headerlink class activates some special logic to show/hide
    # text upon mouse-over; it's how headings show a clickable link.
    return _link("¶", anchor, classes=".headerlink")


def _inline_anchor(anchor: str) -> str:
    return _span("", anchor)


def _indent_block_text(text: str) -> str:
    return text.strip().replace("\n", "\n  ")


def _join_csv_and(values: list[str]) -> str:
    if len(values) == 1:
        return values[0]

    values = list(values)
    values[-1] = "and " + values[-1]
    return ", ".join(values)


def _position_iter(values: list[_T]) -> tuple[bool, bool, _T]:
    for i, value in enumerate(values):
        yield i == 0, i == len(values) - 1, value


class _MySTRenderer:
    def __init__(
        self,
        module: stardoc_output_pb2.ModuleInfo,
        out_stream: TextIO,
        public_load_path: str,
    ):
        self._module = module
        self._out_stream = out_stream
        self._public_load_path = public_load_path

    def render(self):
        self._render_module(self._module)

    def _render_module(self, module: stardoc_output_pb2.ModuleInfo):
        if self._public_load_path:
            bzl_path = self._public_load_path
        else:
            bzl_path = "//" + self._module.file.split("//")[1]
        self._write(
            f"# {bzl_path}\n",
            "\n",
            module.module_docstring.strip(),
            "\n\n",
        )

        # Sort the objects by name
        objects = itertools.chain(
            ((r.rule_name, r, self._render_rule) for r in module.rule_info),
            ((p.provider_name, p, self._render_provider) for p in module.provider_info),
            ((f.function_name, f, self._render_func) for f in module.func_info),
            ((a.aspect_name, a, self._render_aspect) for a in module.aspect_info),
            (
                (m.extension_name, m, self._render_module_extension)
                for m in module.module_extension_info
            ),
            (
                (r.rule_name, r, self._render_repository_rule)
                for r in module.repository_rule_info
            ),
        )

        objects = sorted(objects, key=lambda v: v[0].lower())

        for _, obj, func in objects:
            func(obj)
            self._write("\n")

    def _render_aspect(self, aspect: stardoc_output_pb2.AspectInfo):
        aspect_anchor = _anchor_id(aspect.aspect_name)
        self._write(
            _block_attrs(".starlark-object"),
            f"## {aspect.aspect_name}\n\n",
            "_Propagates on attributes:_ ",  # todo add link here
            ", ".join(sorted(f"`{attr}`" for attr in aspect.aspect_attribute)),
            "\n\n",
            aspect.doc_string.strip(),
            "\n\n",
        )

        if aspect.attribute:
            self._render_attributes(aspect_anchor, aspect.attribute)
        self._write("\n")

    def _render_module_extension(self, mod_ext: stardoc_output_pb2.ModuleExtensionInfo):
        self._write(
            _block_attrs(".starlark-object"),
            f"## {mod_ext.extension_name}\n\n",
        )

        self._write(mod_ext.doc_string.strip(), "\n\n")

        mod_ext_anchor = _anchor_id(mod_ext.extension_name)
        for tag in mod_ext.tag_class:
            tag_name = f"{mod_ext.extension_name}.{tag.tag_name}"
            tag_anchor = f"{mod_ext_anchor}_{tag.tag_name}"
            self._write(
                _block_attrs(".starlark-module-extension-tag-class"),
                f"### {tag_name}\n\n",
            )
            self._render_signature(
                tag_name,
                tag_anchor,
                tag.attribute,
                get_name=lambda a: a.name,
                get_default=lambda a: a.default_value,
            )

            self._write(tag.doc_string.strip(), "\n\n")
            self._render_attributes(tag_anchor, tag.attribute)
            self._write("\n")

    def _render_repository_rule(self, repo_rule: stardoc_output_pb2.RepositoryRuleInfo):
        self._write(
            _block_attrs(".starlark-object"),
            f"## {repo_rule.rule_name}\n\n",
        )
        repo_anchor = _anchor_id(repo_rule.rule_name)
        self._render_signature(
            repo_rule.rule_name,
            repo_anchor,
            repo_rule.attribute,
            get_name=lambda a: a.name,
            get_default=lambda a: a.default_value,
        )
        self._write(repo_rule.doc_string.strip(), "\n\n")
        if repo_rule.attribute:
            self._render_attributes(repo_anchor, repo_rule.attribute)
        if repo_rule.environ:
            self._write(
                "**ENVIRONMENT VARIABLES** ",
                _link_here_icon(repo_anchor + "_env"),
                "\n",
            )
            for name in sorted(repo_rule.environ):
                self._write(f"* `{name}`\n")
        self._write("\n")

    def _render_rule(self, rule: stardoc_output_pb2.RuleInfo):
        rule_name = rule.rule_name
        rule_anchor = _anchor_id(rule_name)
        self._write(
            _block_attrs(".starlark-object"),
            f"## {rule_name}\n\n",
        )

        self._render_signature(
            rule_name,
            rule_anchor,
            rule.attribute,
            get_name=lambda r: r.name,
            get_default=lambda r: r.default_value,
        )

        self._write(rule.doc_string.strip(), "\n\n")

        if len(rule.advertised_providers.provider_name) == 0:
            self._write("_Provides_: no providers advertised.")
        else:
            self._write(
                "_Provides_: ",
                ", ".join(rule.advertised_providers.provider_name),
            )
        self._write("\n\n")

        if rule.attribute:
            self._render_attributes(rule_anchor, rule.attribute)

    def _rule_attr_type_string(self, attr: stardoc_output_pb2.AttributeInfo) -> str:
        if attr.type == _AttributeType.NAME:
            return _link("Name", ref="target-name")
        elif attr.type == _AttributeType.INT:
            return _link("int", ref="int")
        elif attr.type == _AttributeType.LABEL:
            return _link("label", ref="attr-label")
        elif attr.type == _AttributeType.STRING:
            return _link("string", ref="str")
        elif attr.type == _AttributeType.STRING_LIST:
            return "list of " + _link("string", ref="str")
        elif attr.type == _AttributeType.INT_LIST:
            return "list of " + _link("int", ref="int")
        elif attr.type == _AttributeType.LABEL_LIST:
            return "list of " + _link("label", ref="attr-label") + "s"
        elif attr.type == _AttributeType.BOOLEAN:
            return _link("bool", ref="bool")
        elif attr.type == _AttributeType.LABEL_STRING_DICT:
            return "dict of {key} to {value}".format(
                key=_link("label", ref="attr-label"), value=_link("string", ref="str")
            )
        elif attr.type == _AttributeType.STRING_DICT:
            return "dict of {key} to {value}".format(
                key=_link("string", ref="str"), value=_link("string", ref="str")
            )
        elif attr.type == _AttributeType.STRING_LIST_DICT:
            return "dict of {key} to list of {value}".format(
                key=_link("string", ref="str"), value=_link("string", ref="str")
            )
        elif attr.type == _AttributeType.OUTPUT:
            return _link("label", ref="attr-label")
        elif attr.type == _AttributeType.OUTPUT_LIST:
            return "list of " + _link("label", ref="attr-label")
        else:
            # If we get here, it means the value was unknown for some reason.
            # Rather than error, give some somewhat understandable value.
            return _AttributeType.Name(attr.type)

    def _render_func(self, func: stardoc_output_pb2.StarlarkFunctionInfo):
        func_name = func.function_name
        func_anchor = _anchor_id(func_name)
        self._write(
            _block_attrs(".starlark-object"),
            f"## {func_name}\n\n",
        )

        parameters = [param for param in func.parameter if param.name != "self"]

        self._render_signature(
            func_name,
            func_anchor,
            parameters,
            get_name=lambda p: p.name,
            get_default=lambda p: p.default_value,
        )

        self._write(func.doc_string.strip(), "\n\n")

        if parameters:
            self._write(
                _block_attrs(f"{func_anchor}_parameters"),
                "**PARAMETERS** ",
                _link_here_icon(f"{func_anchor}_parameters"),
                "\n\n",
            )
            entries = []
            for param in parameters:
                entries.append(
                    [
                        f"{func_anchor}_{param.name}",
                        param.name,
                        f"(_default `{param.default_value}`_) "
                        if param.default_value
                        else "",
                        param.doc_string if param.doc_string else "_undocumented_",
                    ]
                )
            self._render_field_list(entries)

        if getattr(func, "return").doc_string:
            return_doc = _indent_block_text(getattr(func, "return").doc_string)
            self._write(
                _block_attrs(f"{func_anchor}_returns"),
                "RETURNS",
                _link_here_icon(func_anchor + "_returns"),
                "\n",
                ": ",
                return_doc,
                "\n",
            )
        if func.deprecated.doc_string:
            self._write(
                "\n\n**DEPRECATED**\n\n", func.deprecated.doc_string.strip(), "\n"
            )

    def _render_provider(self, provider: stardoc_output_pb2.ProviderInfo):
        self._write(
            _block_attrs(".starlark-object"),
            f"## {provider.provider_name}\n\n",
        )

        provider_anchor = _anchor_id(provider.provider_name)
        self._render_signature(
            provider.provider_name,
            provider_anchor,
            provider.field_info,
            get_name=lambda f: f.name,
        )

        self._write(provider.doc_string.strip(), "\n\n")

        if provider.field_info:
            self._write(
                _block_attrs(provider_anchor),
                "**FIELDS** ",
                _link_here_icon(provider_anchor + "_fields"),
                "\n",
                "\n",
            )
            entries = []
            for field in provider.field_info:
                entries.append(
                    [
                        f"{provider_anchor}_{field.name}",
                        field.name,
                        field.doc_string,
                    ]
                )
            self._render_field_list(entries)

    def _render_attributes(
        self, base_anchor: str, attributes: list[stardoc_output_pb2.AttributeInfo]
    ):
        self._write(
            _block_attrs(f"{base_anchor}_attributes"),
            "**ATTRIBUTES** ",
            _link_here_icon(f"{base_anchor}_attributes"),
            "\n",
        )
        entries = []
        for attr in attributes:
            anchor = f"{base_anchor}_{attr.name}"
            required = "required" if attr.mandatory else "optional"
            attr_type = self._rule_attr_type_string(attr)
            default = f", default `{attr.default_value}`" if attr.default_value else ""
            providers_parts = []
            if attr.provider_name_group:
                providers_parts.append("\n\n_Required providers_: ")
            if len(attr.provider_name_group) == 1:
                provider_group = attr.provider_name_group[0]
                if len(provider_group.provider_name) == 1:
                    providers_parts.append(provider_group.provider_name[0])
                else:
                    providers_parts.extend(
                        ["all of ", _join_csv_and(provider_group.provider_name)]
                    )
            elif len(attr.provider_name_group) > 1:
                providers_parts.append("any of \n")
                for group in attr.provider_name_group:
                    providers_parts.extend(["* ", _join_csv_and(group.provider_name)])
            if providers_parts:
                providers_parts.append("\n")

            entries.append(
                [
                    anchor,
                    attr.name,
                    f"_({required} {attr_type}{default})_\n",
                    attr.doc_string,
                    *providers_parts,
                ]
            )
        self._render_field_list(entries)

    def _render_signature(
        self,
        name: str,
        base_anchor: str,
        parameters: list[_T],
        *,
        get_name: Callable[_T, str],
        get_default: Callable[_T, str] = lambda v: None,
    ):
        self._write(_block_attrs(".starlark-signature"), name, "(")
        for _, is_last, param in _position_iter(parameters):
            param_name = get_name(param)
            self._write(_link(param_name, f"{base_anchor}_{param_name}"))
            default_value = get_default(param)
            if default_value:
                self._write(f"={default_value}")
            if not is_last:
                self._write(",\n")
        self._write(")\n\n")

    def _render_field_list(self, entries: list[list[str]]):
        """Render a list of field lists.

        Args:
            entries: list of field list entries. Each element is 3
                pieces: an anchor, field description, and one or more
                text strings for the body of the field list entry.
        """
        for anchor, description, *body_pieces in entries:
            body_pieces = [_block_attrs(anchor), *body_pieces]
            self._write(
                ":",
                _span(description + _link_here_icon(anchor)),
                ":\n  ",
                # The text has to be indented to be associated with the block correctly.
                "".join(body_pieces).strip().replace("\n", "\n  "),
                "\n",
            )
        # Ensure there is an empty line after the field list, otherwise
        # the next line of content will fold into the field list
        self._write("\n")

    def _write(self, *lines: str):
        self._out_stream.writelines(lines)


def _convert(
    *,
    proto: pathlib.Path,
    output: pathlib.Path,
    footer: pathlib.Path,
    public_load_path: str,
):
    if footer:
        footer_content = footer.read_text()

    module = stardoc_output_pb2.ModuleInfo.FromString(proto.read_bytes())
    with output.open("wt", encoding="utf8") as out_stream:
        _MySTRenderer(module, out_stream, public_load_path).render()
        out_stream.write(footer_content)


def _create_parser():
    parser = argparse.ArgumentParser(fromfile_prefix_chars="@")
    parser.add_argument("--footer", dest="footer", type=pathlib.Path)
    parser.add_argument("--proto", dest="proto", type=pathlib.Path)
    parser.add_argument("--output", dest="output", type=pathlib.Path)
    parser.add_argument("--public-load-path", dest="public_load_path")
    return parser


def main(args):
    options = _create_parser().parse_args(args)
    _convert(
        proto=options.proto,
        output=options.output,
        footer=options.footer,
        public_load_path=options.public_load_path,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
