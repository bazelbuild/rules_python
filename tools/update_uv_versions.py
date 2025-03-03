#!/bin/env python3
"""
This module provides functionality to fetch release information for the uv
project from GitHub and update the `versions.bzl` file accordingly.

The module defines several functions:

- `clean_trailing_commas`: Removes trailing commas from JSON-like strings to
  prepare them for JSON parsing.
- `get_uv_releases_info`: Fetches release information (tag names, asset URLs,
  and SHA256 hashes) from the Astral uv GitHub repository.  It filters out
  source code archives and allows limiting the number of releases fetched.  It
  also allows specifying a list of platforms to filter assets by.
- `parse_uv_platforms`: Parses the `UV_PLATFORMS` section from `versions.bzl`
  content to extract platform definitions.
- `parse_uv_versions`: Parses the `UV_TOOL_VERSIONS` section from
  `versions.bzl` content to extract existing version information.
- `update_versions_content`: Updates the content of `versions.bzl` by merging
  new release information into the existing `UV_TOOL_VERSIONS` section.

The module also includes a `main` function that orchestrates the entire update
process, reading from and writing to the `versions.bzl` file.

Error handling is implemented throughout the module to manage network requests,
JSON parsing, and file operations.  Logging is used for debugging and
informational purposes.

This module is intended to be used as a utility for automatically updating the
`versions.bzl` file with the latest uv releases.
"""


import json
import logging
import re

import requests

logger = logging.getLogger(__name__)
TIMEOUT: int = 60

def clean_trailing_commas(string) -> str:
    """Removes trailing commas from JSON-like strings.

    This helper function prepares JSON-like strings for parsing by removing
    trailing commas that might cause errors.

    Args:
        string: The input string.

    Returns:
        The string with trailing commas removed.
    """
    string = re.sub(",[ \t\r\n]*}", "}", string)
    string = re.sub(",[ \t\r\n]*]", "]", string)

    return string

def get_uv_releases_info(
    limit: int | None = 10,
    platforms: list[str] | None = None,
) -> dict[str, str | dict[str, str] | None]:
    """Fetches release information for the uv project from GitHub.

    This function retrieves the latest releases from the Astral uv GitHub
    repository, extracting information about each release's assets (binaries)
    and their corresponding SHA256 hashes. It filters out source code
    archives and provides details for a limited number of releases.  It also
    allows filtering assets by a list of supported platforms.

    Args:
        limit: The maximum number of releases to fetch. Defaults to 10. Set to
               None to fetch all releases.
        platforms: An optional list of supported platforms to filter assets by.

    Returns:
        A dictionary where keys are release tag names (e.g., "0.1.1") and
        values are dictionaries of assets. Each asset dictionary contains
        "name", "url", and "sha256". Returns None if there's an error.

    Raises:
        requests.exceptions.RequestException: For HTTP request errors.
        json.JSONDecodeError: For JSON decoding errors.
        Exception: For other unexpected errors.
    """
    try:
        repo_url = "https://api.github.com/repos/astral-sh/uv/releases"
        response = requests.get(repo_url, timeout=TIMEOUT)
        response.raise_for_status()  # Raise an exception for bad status codes

        release_data = response.json()
        releases: dict[str, dict[str, str]] = {}

        count = 0
        for release in release_data:
            if limit is not None and count >= limit:
                break

            release_tag = release["tag_name"]
            logger.debug("Release tag: %s", release_tag)
            assets = {}

            for asset in release["assets"]:
                if (
                    not any(
                        [
                            asset["name"].endswith(".zip"),
                            asset["name"].endswith(".tar.gz"),
                        ]
                    )
                    or asset["name"] == "source.tar.gz"
                ):
                    continue

                # If none of the platforms match this asset, skip
                if platforms is not None and not any(
                    [platform in asset["name"] for platform in platforms]
                ):
                    continue

                try:
                    logger.debug("Asset: %s", asset["name"])
                    asset_name = asset["name"]
                    asset_url = asset["browser_download_url"]

                    # Fetch the SHA256 hash for the asset
                    sha256_url = f"{asset_url}.sha256"
                    sha256_response = requests.get(sha256_url, timeout=TIMEOUT)
                    sha256_response.raise_for_status()
                    sha256_hash = sha256_response.text.strip().split()[0]

                    assets[asset_name] = {
                        "name": asset_name,
                        "url": asset_url,
                        "sha256": sha256_hash,
                    }
                except requests.exceptions.RequestException as e:
                    logger.warning(
                        "Error fetching SHA256 hash for asset '%s': %s",
                        asset_name,
                        e,
                    )
                    continue

            releases[release_tag] = assets
            count += 1

        return releases

    except requests.exceptions.RequestException as e:
        logging.error("Error fetching release information: %s", e)
        return None
    except json.JSONDecodeError as e:
        logging.error("Error decoding JSON response: %s", e)
        return None
    except Exception as e:  # pylint: disable=broad-exception-caught
        logging.error("An unexpected error occurred: %s", e)
        return None

def parse_uv_platforms(content: str) -> dict[str, dict[str, list[str]]]:
    """Parses the UV_PLATFORMS section from versions.bzl content.

    Args:
        content: The content of the versions.bzl file.

    Returns:
        A dictionary representing the UV_PLATFORMS section. Keys are platform
        names (e.g., "x86_64-unknown-linux-gnu"), and values are dictionaries
        with "default_repo_name" and "compatible_with" (list of strings).
        Returns an empty dictionary if the section is not found or is empty.
        Handles potential errors gracefully.
    """
    match = re.search(r"UV_PLATFORMS = {(.*?)}", content, re.DOTALL)
    platforms = {}
    if match:
        platforms_str = match.group(1).strip()
        if platforms_str:
            try:
                # Attempt to parse directly as JSON if it's already in a close-to-JSON format
                platform_str = clean_trailing_commas(
                    "{"
                    + (
                        platforms_str.replace("struct(", "{")
                        .replace(")", "}")
                        .replace("=", ":")
                        .replace("compatible_with", '"compatible_with"')
                        .replace("default_repo_name", '"default_repo_name"')
                    )
                    + "}"
                )
                platforms = json.loads(platform_str)
            except (json.JSONDecodeError, Exception) as e:  # pylint: disable=broad-exception-caught
                logger.error("Error parsing UV_PLATFORMS section: %s", e)
                print(platform_str)

    return platforms


def parse_uv_versions(content: str) -> dict[str, dict[str, str]]:
    """Parses the UV_TOOL_VERSIONS section from versions.bzl content.

    Args:
        content: The content of the versions.bzl file.

    Returns:
        A dictionary representing the UV_TOOL_VERSIONS section.  The keys are
        version tags, and the values are dictionaries mapping platform names
        to sha256 hashes. Returns an empty dictionary if the section is not
        found or is empty.
    """
    match = re.search(r"UV_TOOL_VERSIONS = {(.*?)}$", content, re.DOTALL)
    versions = {}
    if match:
        versions_str = match.group(1).strip()
        if versions_str:
            try:
                versions_str = clean_trailing_commas(
                    "{"
                    + versions_str.replace("struct(", "{")
                    .replace(")", "}")
                    .replace("sha256 = ", '"sha256": ')
                    + "}"
                )
                versions = json.loads(versions_str)
            except json.JSONDecodeError as e:
                logger.error("Error decoding JSON in UV_TOOL_VERSIONS section: %s", e)

    return versions


def update_versions_content(
    release_info: dict[str, dict[str, str]] | None,
    content: str | None = None,
) -> str | None:
    """Updates the versions.bzl file content with new release information.

    This function merges new release information into the existing
    `UV_TOOL_VERSIONS` section of the `versions.bzl` content.

    Args:
        release_info: A dictionary containing release information (as returned
                      by `get_uv_releases_info`).
        content: The initial content of the versions.bzl file.

    Returns:
        The updated content of the versions.bzl file, or None if there's an
        error or no release information is provided.
    """
    if release_info is None:
        logger.warning("No release information to update.")
        return content

    try:
        platforms = parse_uv_platforms(content)
        existing_versions = parse_uv_versions(content)
        if not platforms:
            logger.error("No platforms found in versions.bzl.")
            return content

        versions = {}
        for version in release_info.keys():
            assets = {}
            version_assets = release_info[version]
            for asset_name, asset_data in version_assets.items():
                matched_platform = None
                logger.debug("Asset name: %s", asset_name)
                for platform in platforms:
                    logger.debug("Platform: %s", platform)
                    if platform in asset_name:
                        logger.debug("matched platform: %s", platform)
                        matched_platform = platform
                        break

                if matched_platform:
                    logger.debug("asset_data: %s", asset_data)
                    assets[matched_platform] = {
                        "sha256": asset_data["sha256"],
                    }

            versions[version] = assets

        versions = {**existing_versions, **versions}
        # Sort versions from latest to oldest before rendering
        versions = dict(sorted(versions.items(), reverse=True))

        logging.debug("Updated Versions: %s", versions)

        binaries_str = "UV_TOOL_VERSIONS = {\n"
        for version_tag, version_data in versions.items():
            binaries_str += f'    "{version_tag}": {{\n'
            for platform_name, platform_data in version_data.items():
                binaries_str += f'        "{platform_name}": struct(\n'
                binaries_str += f'            sha256 = "{platform_data["sha256"]}",\n'
                binaries_str += "        ),\n"
            binaries_str += "    },\n"
        binaries_str += "}\n"

        # Replace the old UV_BINARIES with the new one
        content = re.sub(
            r"UV_TOOL_VERSIONS = {(.*?)}$", binaries_str, content, 1, flags=re.DOTALL
        )

        return content
    except Exception as e:  # pylint: disable=broad-exception-caught
        logger.error("An error occurred while updating the content: %s", e)


def main():
    """Main entry point for the script."""
    logging.basicConfig(level=logging.INFO)

    version_file = "python/uv/private/versions.bzl"
    with open(version_file, "r", encoding="utf-8") as f:
        content = f.read()

    platforms = parse_uv_platforms(content)
    info = get_uv_releases_info(limit=10, platforms=platforms.keys())
    content = update_versions_content(info, content)

    with open(version_file, "w", encoding="utf-8") as f:
        f.write(content)


if __name__ == "__main__":
    main()
