"""Download a wheel without retaining it in the extracted repository."""

load("//python/private:auth.bzl", "AUTH_ATTRS", "get_auth")
load("//python/private:repo_utils.bzl", "REPO_DEBUG_ENV_VAR", "repo_utils")
load(":attrs.bzl", "ATTRS")
load(":urllib.bzl", "urllib")

def download_whl(rctx, *, logger):
    """Download a wheel and return its path, preserving index authentication.

    Args:
        rctx: The repository context.
        logger: The repository logger.

    Returns:
        The path of the downloaded wheel.
    """
    filename = rctx.attr.filename
    if not filename.endswith(".whl"):
        fail("Only wheels are supported")
    urls = [
        urllib.absolute_url(
            rctx.attr.index_url,
            url,
            envsubst = rctx.attr.envsubst,
            getenv = rctx.getenv,
        )
        for url in rctx.attr.urls
    ]
    result = rctx.download(
        url = urls,
        output = filename,
        sha256 = rctx.attr.sha256,
        integrity = rctx.attr.integrity if not rctx.attr.sha256 else "",
        auth = get_auth(rctx, urls),
    )
    if not rctx.attr.sha256 and not rctx.attr.integrity:
        logger.warn("Please update the requirement line to include the hash:\n{} \\\n    --hash=sha256:{}".format(
            rctx.attr.requirement,
            result.sha256,
        ))
    if not result.success:
        fail("could not download the '{}' from {}:\n{}".format(filename, urls, result))
    return rctx.path(filename)

whl_download_attrs = {
    "envsubst": ATTRS["envsubst"],
    "filename": attr.string(doc = "The filename of the downloaded wheel."),
    "index_url": attr.string(doc = "The index URL used to resolve relative wheel URLs."),
    "integrity": attr.string(doc = "The expected SRI checksum, used when sha256 is unset."),
    "requirement": attr.string(doc = "The requirement used in download diagnostics."),
    "sha256": attr.string(doc = "The expected SHA256 checksum."),
    "urls": attr.string_list(doc = "The wheel download URLs."),
} | AUTH_ATTRS

def _whl_download_impl(rctx):
    whl_path = download_whl(rctx, logger = repo_utils.logger(rctx))
    rctx.file("BUILD.bazel", "exports_files([{}])\n".format(repr(whl_path.basename)))
    if hasattr(rctx, "repo_metadata"):
        return rctx.repo_metadata(reproducible = True)
    return None

whl_download = repository_rule(
    implementation = _whl_download_impl,
    attrs = whl_download_attrs | {
        "_rule_name": attr.string(default = "whl_download"),
    },
    environ = [REPO_DEBUG_ENV_VAR],
)
