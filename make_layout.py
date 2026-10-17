#!/usr/bin/env python3
"""Build a local verification layout from saved read-only ADB diagnostics."""

import argparse
import json
from pathlib import Path
import re

from verify_regions import validate_layout


def build(partition_text, extra_text=""):
    match = re.search(r"Disk /dev/block/mmcblk0: .*?, (\d+) bytes", partition_text)
    if not match:
        raise ValueError("Missing device byte count from fdisk -lu")
    sizes = {
        int(number): (int(start), int(size))
        for number, start, size in re.findall(
            r"/sys/block/mmcblk0/mmcblk0p(\d+)\n(\d+)\n(\d+)", partition_text
        )
    }
    hashes = {
        int(number): digest
        for digest, number in re.findall(
            r"([0-9a-f]{64})\s+/dev/block/mmcblk0p(\d+)", partition_text
        )
    }
    regions = [
        {"name": f"mmcblk0p{number}", "offset": sizes[number][0] * 512,
         "size": sizes[number][1] * 512, "sha256": digest}
        for number, digest in hashes.items()
    ]
    for start, count, digest in re.findall(r"(\d+):(\d+)\n([0-9a-f]{64})\s+-", extra_text):
        regions.append({"name": f"sectors_{start}_{count}", "offset": int(start) * 512,
                        "size": int(count) * 512, "sha256": digest})
    layout = {"expected_raw_bytes": int(match.group(1)), "regions": regions}
    validate_layout(layout)
    return layout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("partitions", type=Path)
    parser.add_argument("--extra-regions", type=Path)
    args = parser.parse_args()
    extra = args.extra_regions.read_text() if args.extra_regions else ""
    print(json.dumps(build(args.partitions.read_text(), extra), indent=2))


if __name__ == "__main__":
    main()
