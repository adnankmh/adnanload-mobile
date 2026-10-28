"""One release version contract, shared across all historical source checks."""
import re

MINIMUM_VERSION = (2, 1, 0, 10)


def supported_version(pubspec: str) -> bool:
    match = re.search(r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$", pubspec, re.MULTILINE)
    if not match:
        return False
    return tuple(int(part) for part in match.groups()) >= MINIMUM_VERSION
