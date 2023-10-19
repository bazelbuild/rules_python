# Configuration file for the Sphinx documentation builder.

# -- Project information
project = "rules_python"
copyright = "2023, The Bazel Authors"
author = "Bazel"

# Readthedocs fills these in
release = "0.0.0"
version = release

# -- General configuration

# Any extensions here not built into Sphinx must also be added to
# the dependencies of Bazel and Readthedocs.
# * //docs:requirements.in
# * Regenerate //docs:requirements.txt (used by readthedocs)
# * Add the dependencies to //docs:sphinx_build
extensions = [
    "sphinx.ext.duration",
    "sphinx.ext.doctest",
    "sphinx.ext.autodoc",
    "sphinx.ext.autosummary",
    "sphinx.ext.intersphinx",
    "sphinx.ext.autosectionlabel",
    "myst_parser",
    "sphinx_rtd_theme",  # Necessary to get jquery to make flyout work
]

exclude_patterns = ["crossrefs.md"]

intersphinx_mapping = {}

intersphinx_disabled_domains = ["std"]

# Prevent local refs from inadvertently linking elsewhere, per
# https://docs.readthedocs.io/en/stable/guides/intersphinx.html#using-intersphinx
intersphinx_disabled_reftypes = ["*"]

templates_path = ["_templates"]

# -- Options for HTML output

html_theme = "sphinx_rtd_theme"

# See https://sphinx-rtd-theme.readthedocs.io/en/stable/configuring.html
# for options
html_theme_options = {}

# Keep this in sync with the stardoc templates
html_permalinks_icon = "¶"

# See https://myst-parser.readthedocs.io/en/latest/syntax/optional.html
# for additional extensions.
myst_enable_extensions = [
    "fieldlist",
    "attrs_block",
    "attrs_inline",
    "colon_fence",
    "deflist",
]

# These folders are copied to the documentation's HTML output
html_static_path = ["_static"]

# These paths are either relative to html_static_path
# or fully qualified paths (eg. https://...)
html_css_files = [
    "css/custom.css",
]

# -- Options for EPUB output
epub_show_urls = "footnote"
