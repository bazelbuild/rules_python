import json
import unittest
from unittest.mock import patch

import requests
from update_uv_versions import (
    clean_trailing_commas,
    get_uv_releases_info,
    parse_uv_platforms,
    parse_uv_versions,
    update_versions_content,
)


class TestCleanTrailingCommas(unittest.TestCase):
    """Unit tests for the clean_trailing_commas function."""

    def test_clean_trailing_commas_success(self):
        """Tests successful removal of trailing commas."""
        test_cases = [
            ('{"a": 1, "b": 2,}', '{"a": 1, "b": 2}'),
            ('{"a": 1, "b": 2, "c": 3}', '{"a": 1, "b": 2, "c": 3}'),
            ("[1, 2,]", "[1, 2]"),
            ("[1, 2, 3]", "[1, 2, 3]"),
            ('{"a": [1, 2,]}', '{"a": [1, 2]}'),
            ('{"a": [1, 2, 3]}', '{"a": [1, 2, 3]}'),
            ('{"a": 1, "b": 2, }', '{"a": 1, "b": 2}'),
            ('{"a": 1, "b": 2,  }', '{"a": 1, "b": 2}'),
            ('{"a": 1, "b": 2,\n}', '{"a": 1, "b": 2}'),
            ('{"a": 1, "b": 2,\r}', '{"a": 1, "b": 2}'),
            ('{"a": 1, "b": 2,\t}', '{"a": 1, "b": 2}'),
            ('{"a": 1, "b": 2,\r\n}', '{"a": 1, "b": 2}'),
            ('{"a": 1, "b": 2,\n\r}', '{"a": 1, "b": 2}'),
            ('{"a": 1, "b": 2,\t\r}', '{"a": 1, "b": 2}'),
            ('{"a": 1, "b": 2,\t\n}', '{"a": 1, "b": 2}'),
            ('{"a": 1, "b": 2,\t\r\n}', '{"a": 1, "b": 2}'),
        ]
        for test_case in test_cases:
            self.assertEqual(clean_trailing_commas(test_case[0]), test_case[1])


class TestGetUVReleasesInfo(unittest.TestCase):
    """Unit tests for the get_uv_releases_info function."""

    @patch("requests.get")
    def test_get_uv_releases_info_success(self, mock_get):
        """Tests successful retrieval of release information."""
        mock_response = unittest.mock.Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = [
            {
                "tag_name": "0.1.1",
                "assets": [
                    {
                        "name": "uv-0.1.1-x86_64-unknown-linux-gnu.tar.gz",
                        "browser_download_url": "https://example.com/uv-0.1.1-x86_64-unknown-linux-gnu.tar.gz",
                    },
                    {
                        "name": "uv-0.1.1-aarch64-apple-darwin.tar.gz",
                        "browser_download_url": "https://example.com/uv-0.1.1-aarch64-apple-darwin.tar.gz",
                    },
                ],
            }
        ]
        mock_sha256_response_1 = unittest.mock.Mock()
        mock_sha256_response_1.status_code = 200
        mock_sha256_response_1.text = "sha256_1  file1"
        mock_sha256_response_2 = unittest.mock.Mock()
        mock_sha256_response_2.status_code = 200
        mock_sha256_response_2.text = "sha256_2  file2"
        mock_get.side_effect = [
            mock_response,
            mock_sha256_response_1,
            mock_sha256_response_2,
        ]
        result = get_uv_releases_info()
        self.assertIsNotNone(result)
        self.assertEqual(len(result), 1)
        self.assertIn("0.1.1", result)
        self.assertEqual(len(result["0.1.1"]), 2)
        self.assertEqual(
            result["0.1.1"]["uv-0.1.1-x86_64-unknown-linux-gnu.tar.gz"]["sha256"],
            "sha256_1",
        )
        self.assertEqual(
            result["0.1.1"]["uv-0.1.1-aarch64-apple-darwin.tar.gz"]["sha256"],
            "sha256_2",
        )

    @patch("requests.get")
    def test_get_uv_releases_info_request_error(self, mock_get):
        """Tests handling of request errors."""
        mock_get.side_effect = requests.exceptions.RequestException("Request error")
        result = get_uv_releases_info()
        self.assertIsNone(result)

    @patch("requests.get")
    def test_get_uv_releases_info_json_decode_error(self, mock_get):
        """Tests handling of JSON decoding errors."""
        mock_response = unittest.mock.Mock()
        mock_response.status_code = 200
        mock_response.json.side_effect = json.JSONDecodeError("Decoding error", "", 0)
        mock_get.return_value = mock_response
        result = get_uv_releases_info()
        self.assertIsNone(result)


class TestParseUVPlatforms(unittest.TestCase):
    """Unit tests for the parse_uv_platforms function."""

    def test_parse_uv_platforms_success(self):
        """Tests successful parsing of UV_PLATFORMS section."""
        content = """
UV_PLATFORMS = {
    "x86_64-unknown-linux-gnu": struct(default_repo_name = "x86_64-unknown-linux-gnu", compatible_with = ["@platforms//os:linux", "@platforms//cpu:x86_64"]),
    "aarch64-apple-darwin": struct(default_repo_name = "aarch64-apple-darwin", compatible_with = ["@platforms//os:osx", "@platforms//cpu:arm64"]),
}
"""
        expected_platforms = {
            "x86_64-unknown-linux-gnu": {
                "default_repo_name": "x86_64-unknown-linux-gnu",
                "compatible_with": ["@platforms//os:linux", "@platforms//cpu:x86_64"],
            },
            "aarch64-apple-darwin": {
                "default_repo_name": "aarch64-apple-darwin",
                "compatible_with": ["@platforms//os:osx", "@platforms//cpu:arm64"],
            },
        }
        platforms = parse_uv_platforms(content)
        self.assertEqual(platforms, expected_platforms)

    def test_parse_uv_platforms_empty(self):
        """Tests parsing when UV_PLATFORMS section is empty."""
        content = "UV_PLATFORMS = {}"
        platforms = parse_uv_platforms(content)
        self.assertEqual(platforms, {})

    def test_parse_uv_platforms_missing(self):
        """Tests parsing when UV_PLATFORMS section is missing."""
        content = "some other content"
        platforms = parse_uv_platforms(content)
        self.assertEqual(platforms, {})

    def test_parse_uv_platforms_invalid_json(self):
        """Tests handling of invalid JSON in UV_PLATFORMS section."""
        content = """
UV_PLATFORMS = {
    "x86_64-unknown-linux-gnu": struct(default_repo_name = "x86_64-unknown-linux-gnu", compatible_with = ["@platforms//os:linux", "@platforms//cpu:x86_64"]),
    "aarch64-apple-darwin": struct(default_repo_name = "aarch64-apple-darwin", compatible_with = ["@platforms//os:osx", "@platforms//cpu:arm64"]
}
"""
        platforms = parse_uv_platforms(content)
        self.assertEqual(platforms, {})

    def test_parse_uv_platforms_no_compatible_with(self):
        """Tests parsing when compatible_with is missing."""
        content = """
UV_PLATFORMS = {
    "x86_64-unknown-linux-gnu": struct(default_repo_name = "x86_64-unknown-linux-gnu"),
}
"""
        expected_platforms = {
            "x86_64-unknown-linux-gnu": {
                "default_repo_name": "x86_64-unknown-linux-gnu",
            },
        }
        platforms = parse_uv_platforms(content)
        self.assertEqual(platforms, expected_platforms)


class TestParseUVVersions(unittest.TestCase):
    """Unit tests for the parse_uv_versions function."""

    def test_parse_uv_versions_success(self):
        """Tests successful parsing of UV_TOOL_VERSIONS section."""
        content = """
UV_TOOL_VERSIONS = {
    "0.1.1": {
        "x86_64-unknown-linux-gnu": struct(sha256 = "sha256_1"),
        "aarch64-apple-darwin": struct(sha256 = "sha256_2"),
    },
    "0.1.0": {
        "x86_64-unknown-linux-gnu": struct(sha256 = "sha256_3"),
    },
}
"""
        expected_versions = {
            "0.1.1": {
                "x86_64-unknown-linux-gnu": {"sha256": "sha256_1"},
                "aarch64-apple-darwin": {"sha256": "sha256_2"},
            },
            "0.1.0": {"x86_64-unknown-linux-gnu": {"sha256": "sha256_3"}},
        }
        versions = parse_uv_versions(content)
        self.assertEqual(versions, expected_versions)

    def test_parse_uv_versions_empty(self):
        """Tests parsing when UV_TOOL_VERSIONS section is empty."""
        content = "UV_TOOL_VERSIONS = {}"
        versions = parse_uv_versions(content)
        self.assertEqual(versions, {})

    def test_parse_uv_versions_missing(self):
        """Tests parsing when UV_TOOL_VERSIONS section is missing."""
        content = "some other content"
        versions = parse_uv_versions(content)
        self.assertEqual(versions, {})

    def test_parse_uv_versions_invalid_json(self):
        """Tests handling of invalid JSON in UV_TOOL_VERSIONS section."""
        content = """
UV_TOOL_VERSIONS = {
    "0.1.1": {
        "x86_64-unknown-linux-gnu": struct(sha256 = "sha256_1"),
        "aarch64-apple-darwin": struct(sha256 = "sha256_2"),
    },
    "0.1.0": {
        "x86_64-unknown-linux-gnu": struct(sha256 = "sha256_3"),
}
"""
        versions = parse_uv_versions(content)
        self.assertEqual(versions, {})


class TestUpdateVersionsContent(unittest.TestCase):
    """Unit tests for the update_versions_content function."""

    @patch("update_uv_versions.parse_uv_platforms")
    @patch("update_uv_versions.parse_uv_versions")
    def test_update_versions_content_success(
        self, mock_parse_versions, mock_parse_platforms
    ):
        """Tests successful update of versions.bzl content."""
        release_info = {
            "0.1.1": {
                "uv-0.1.1-x86_64-unknown-linux-gnu.tar.gz": {
                    "sha256": "sha256_1",
                },
                "uv-0.1.1-aarch64-apple-darwin.tar.gz": {
                    "sha256": "sha256_2",
                },
            },
            "0.1.0": {
                "uv-0.1.0-x86_64-unknown-linux-gnu.tar.gz": {
                    "sha256": "sha256_3",
                },
            },
        }
        initial_content = """
UV_PLATFORMS = {
    "x86_64-unknown-linux-gnu": struct(
        default_repo_name = "x86_64-unknown-linux-gnu",
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64"
        ],
    ),
    "aarch64-apple-darwin": struct(
        default_repo_name = "aarch64-apple-darwin",
        compatible_with = [
            "@platforms//os:osx",
            "@platforms//cpu:arm64"
        ],
    ),
}
UV_TOOL_VERSIONS = {}
"""
        mock_parse_platforms.return_value = {
            "x86_64-unknown-linux-gnu": {
                "default_repo_name": "x86_64-unknown-linux-gnu",
                "compatible_with": ["@platforms//os:linux", "@platforms//cpu:x86_64"],
            },
            "aarch64-apple-darwin": {
                "default_repo_name": "aarch64-apple-darwin",
                "compatible_with": ["@platforms//os:osx", "@platforms//cpu:arm64"],
            },
        }
        mock_parse_versions.return_value = {}
        updated_content = update_versions_content(release_info, initial_content)
        self.assertIn('"0.1.1": {', updated_content)
        self.assertIn('sha256 = "sha256_1"', updated_content)
        self.assertIn('sha256 = "sha256_2"', updated_content)
        self.assertIn('"0.1.0": {', updated_content)
        self.assertIn('sha256 = "sha256_3"', updated_content)

    @patch("update_uv_versions.parse_uv_platforms")
    @patch("update_uv_versions.parse_uv_versions")
    def test_update_versions_content_no_release_info(
        self, mock_parse_versions, mock_parse_platforms
    ):
        """Tests handling of no release information."""
        mock_parse_platforms.return_value = {}
        mock_parse_versions.return_value = {}
        updated_content = update_versions_content(None)
        self.assertIsNone(updated_content)

    @patch("update_uv_versions.parse_uv_platforms")
    @patch("update_uv_versions.parse_uv_versions")
    def test_update_versions_content_empty_initial_content(
        self, mock_parse_versions, mock_parse_platforms
    ):
        """Tests handling of empty initial content."""
        release_info = {"0.1.1": {"a": {"sha256": "x"}}}
        mock_parse_platforms.return_value = {}
        mock_parse_versions.return_value = {}
        updated_content = update_versions_content(release_info, "")
        self.assertEqual(updated_content, "")


if __name__ == "__main__":
    unittest.main()
