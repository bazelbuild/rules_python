# Configuration file for the Sphinx documentation builder.

# -- Project information
project = "rules_python"
copyright = "2023, The Bazel Authors"
author = "Bazel"

# NOTE: These are overriden by -D flags via --//sphinxdocs:extra_defines
version = "0.0.0"
release = version

# -- General configuration
# See https://www.sphinx-doc.org/en/master/usage/configuration.html
# for more settings

# Any extensions here not built into Sphinx must also be added to
# the dependencies of //docs/sphinx:sphinx-builder
extensions = [
    "sphinx.ext.autodoc",
    "sphinx.ext.autosectionlabel",
    "sphinx.ext.autosummary",
    "sphinx.ext.doctest",
    "sphinx.ext.duration",
    "sphinx.ext.extlinks",
    "sphinx.ext.intersphinx",
    "myst_parser",
    "sphinx_rtd_theme",  # Necessary to get jquery to make flyout work
]

exclude_patterns = ["_includes/*"]
templates_path = ["_templates"]
primary_domain = None  # The default is 'py', which we don't make much use of
nitpicky = True

# --- Intersphinx configuration

intersphinx_mapping = {
    "bazel": ("https://bazel.build/", "bazel_inventory.inv"),
}

# --- Extlinks configuration
extlinks = {
    "gh-path": (f"https://github.com/bazelbuild/rules_python/tree/main/%s", "%s"),
}

# --- MyST configuration
# See https://myst-parser.readthedocs.io/en/latest/configuration.html
# for more settings

# See https://myst-parser.readthedocs.io/en/latest/syntax/optional.html
# for additional extensions.
myst_enable_extensions = [
    "fieldlist",
    "attrs_block",
    "attrs_inline",
    "colon_fence",
    "deflist",
    "substitution",
]

myst_substitutions = {}

# -- Options for HTML output
# See https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output
# For additional html settings

# See https://sphinx-rtd-theme.readthedocs.io/en/stable/configuring.html for
# them-specific options
html_theme = "sphinx_rtd_theme"
html_theme_options = {}

# Keep this in sync with the stardoc templates
html_permalinks_icon = "¶"

# These folders are copied to the documentation's HTML output
html_static_path = ["_static"]

# These paths are either relative to html_static_path
# or fully qualified paths (eg. https://...)
html_css_files = [
    "css/custom.css",
]

# -- Options for EPUB output
epub_show_urls = "footnote"

suppress_warnings = ["myst.header", "myst.xref_missing"]


def setup(app):
  # Pygments says it supports starlark, but it doesn't seem to actually
  # recognize `starlark` as a name. So just manually map it to python.
  from sphinx.highlighting import lexer_classes
  app.add_lexer('starlark', lexer_classes['python'])
