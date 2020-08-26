import re
from typing import Dict, Set, Tuple, Optional


def parse_extras(requirements_path: str) -> Dict[str, Set[str]]:
    """Parse over the requirements.txt file to find extras requested.

    Args:
        requirements_path: The filepath for the requirements.txt file to parse.

    Returns:
         A dictionary mapping the requirement name to a set of extras requested.
    """

    extras_requested = {}
    with open(requirements_path, "r") as requirements:
        # Merge all backslash line continuations so we parse each requirement as a single line.
        for line in requirements.read().replace("\\\n", "").split("\n"):
            requirement, extras = _parse_requirement_for_extra(line)
            if requirement and extras:
                extras_requested[requirement] = extras

    return extras_requested


def _parse_requirement_for_extra(
    requirement: str,
) -> Tuple[Optional[str], Optional[Set[str]]]:
    """Given a requirement string, returns the requirement name and set of extras, if extras specified.
    Else, returns (None, None)
    """

    # https://www.python.org/dev/peps/pep-0508/#grammar
    extras_pattern = re.compile(
        r"^\s*([0-9A-Za-z][0-9A-Za-z_.\-]*)\s*\[\s*([0-9A-Za-z][0-9A-Za-z_.\-]*(?:\s*,\s*[0-9A-Za-z][0-9A-Za-z_.\-]*)*)\s*\]"
    )

    matches = extras_pattern.match(requirement)
    if matches:
        return (
            matches.group(1),
            {extra.strip() for extra in matches.group(2).split(",")},
        )

    return None, None
