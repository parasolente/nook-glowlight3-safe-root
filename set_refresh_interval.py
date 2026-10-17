#!/usr/bin/env python3
"""Prepare a KOReader settings copy without executing Lua or changing other keys."""

import argparse
import re
from pathlib import Path


def set_interval(settings: str, count: int) -> str:
    if count < 1:
        raise ValueError("Refresh interval must be at least one")
    if not re.search(r"^return \{[ \t]*$", settings, re.MULTILINE):
        raise ValueError("Expected a KOReader settings return table")
    for key in ("full_refresh_count", "night_full_refresh_count"):
        pattern = rf'^    \["{key}"\] = [0-9]+,[ \t]*$'
        matches = list(re.finditer(pattern, settings, re.MULTILINE))
        if len(matches) > 1 or (f'["{key}"]' in settings and not matches):
            raise ValueError(f"Unexpected or duplicate setting: {key}")
        replacement = f'    ["{key}"] = {count},'
        if matches:
            settings = re.sub(pattern, replacement, settings, flags=re.MULTILINE)
        else:
            settings = re.sub(r"^return \{[ \t]*$", f"return {{\n{replacement}",
                              settings, count=1, flags=re.MULTILINE)
    return settings


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--count", type=int, default=1)
    args = parser.parse_args()
    prepared = set_interval(args.source.read_text(encoding="utf-8"), args.count)
    with args.destination.open("x", encoding="utf-8") as output:
        output.write(prepared)


if __name__ == "__main__":
    main()
