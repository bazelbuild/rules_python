# Configuration file for the Sphinx documentation builder.

import os

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
    "sphinx_bzl.bzl",
]

# Adapted from the template code:
# https://github.com/readthedocs/readthedocs.org/blob/main/readthedocs/doc_builder/templates/doc_builder/conf.py.tmpl
if os.environ.get("READTHEDOCS") == "True":
    # Must come first because it can interfere with other extensions, according
    # to the original conf.py template comments
    extensions.insert(0, "readthedocs_ext.readthedocs")

    if os.environ.get("READTHEDOCS_VERSION_TYPE") == "external":
        # Insert after the main extension
        extensions.insert(1, "readthedocs_ext.external_version_warning")
        readthedocs_vcs_url = (
            "http://github.com/bazelbuild/rules_python/pull/{}".format(
                os.environ.get("READTHEDOCS_VERSION", "")
            )
        )
        # The build id isn't directly available, but it appears to be encoded
        # into the host name, so we can parse it from that. The format appears
        # to be `build-X-project-Y-Z`, where:
        # * X is an integer build id
        # * Y is an integer project id
        # * Z is the project name
        _build_id = os.environ.get("HOSTNAME", "build-0-project-0-rules-python")
        _build_id = _build_id.split("-")[1]
        readthedocs_build_url = (
            f"https://readthedocs.org/projects/rules-python/builds/{_build_id}"
        )

exclude_patterns = ["_includes/*", "api/*/_*.md"]
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

# --- sphinx_stardoc configuration

bzl_default_repository_name = "@rules_python"

# -- Options for HTML output
# See https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output
# For additional html settings

# See https://sphinx-rtd-theme.readthedocs.io/en/stable/configuring.html for
# them-specific options
html_theme = "sphinx_rtd_theme"
html_theme_options = {}

# The html_context settings are part of the jinja context used by the themes.
html_context = {
    # This controls whether the flyout menu is shown. It is always false
    # because:
    # * For local builds, the flyout menu is empty and doesn't show in the
    #   same place as for RTD builds. No point in showing it locally.
    # * For RTD builds, the flyout menu is always automatically injected,
    #   so having it be True makes the flyout show up twice.
    "READTHEDOCS": False,
    "PRODUCTION_DOMAIN": "readthedocs.org",
    # This is the path to a page's source (after the github user/repo/commit)
    "conf_py_path": "/docs/sphinx/",
    "github_user": "bazelbuild",
    "github_repo": "rules_python",
    # The git version that was checked out, e.g. the tag or branch name
    "github_version": os.environ.get("READTHEDOCS_GIT_IDENTIFIER", ""),
    # For local builds, the github link won't work. Disabling it replaces
    # it with a "view source" link to view the source Sphinx saw, which
    # is useful for local development.
    "display_github": os.environ.get("READTHEDOCS") == "True",
    "commit": os.environ.get("READTHEDOCS_GIT_COMMIT_HASH", "unknown commit"),
    # Used by readthedocs_ext.external_version_warning extension
    # This is the PR number being built
    "current_version": os.environ.get("READTHEDOCS_VERSION", ""),
}

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

suppress_warnings = []


def setup(app):
    # Pygments says it supports starlark, but it doesn't seem to actually
    # recognize `starlark` as a name. So just manually map it to python.
    from sphinx.highlighting import lexer_classes

    app.add_lexer("starlark", lexer_classes["python"])
