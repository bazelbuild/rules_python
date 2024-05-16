"""List files from a wheel's RECORD."""

import re
import sys
from pathlib import Path

from python.pip_install.tools.wheel_installer import wheel


def get_files(whl: wheel.Wheel, regex_pattern: str) -> list[str]:
    """Get files in a wheel that match a regex pattern."""
    p = re.compile(regex_pattern)
    return [filepath for filepath in whl.record.keys() if re.match(p, filepath)]


def main() -> None:
    if 2 < len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <wheel> [regex_pattern]", file=sys.stderr)
        sys.exit(1)

    whl = wheel.Wheel(Path(sys.argv[1]))
    regex_pattern = sys.argv[2] if len(sys.argv) == 3 else ""

    files = get_files(whl, regex_pattern)

    print("\n".join(files))


if __name__ == "__main__":
    main()
