#!/usr/bin/env python3
"""Verify selected image regions against hashes obtained from the device."""

import argparse
import gzip
import hashlib
import json
from pathlib import Path
import re


def validate_layout(layout):
    expected = layout["expected_raw_bytes"]
    if type(expected) is not int or expected <= 0:
        raise ValueError("expected_raw_bytes must be a positive integer")
    names = set()
    regions = []
    for item in layout["regions"]:
        name, offset, size, digest = (item[k] for k in ("name", "offset", "size", "sha256"))
        if not re.fullmatch(r"[A-Za-z0-9_-]+", name) or name in names:
            raise ValueError("Region names must be unique, plain file-name stems")
        if type(offset) is not int or type(size) is not int or offset < 0 or size <= 0:
            raise ValueError("Region offsets and sizes must be valid byte counts")
        if offset + size > expected or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("Invalid region boundary or SHA-256")
        names.add(name)
        regions.append(dict(item))
    if not regions:
        raise ValueError("At least one independently hashed region is required")
    return expected, regions


def verify(image, layout, extract_dir=None):
    expected, regions = validate_layout(layout)
    states = {r["name"]: {"hash": hashlib.sha256(), "bytes": 0} for r in regions}
    destination = Path(extract_dir) if extract_dir else None
    if destination:
        # A new directory prevents accidental replacement of an earlier backup.
        destination.mkdir(parents=True, exist_ok=False)
    handles = {}
    try:
        if destination:
            for region in regions:
                handles[region["name"]] = (destination / (region["name"] + ".img.partial")).open("xb")
        position = 0
        raw_hash = hashlib.sha256()
        with gzip.open(image, "rb") as source:
            while chunk := source.read(4 * 1024 * 1024):
                end = position + len(chunk)
                if end > expected:
                    raise ValueError("Image exceeds expected size")
                raw_hash.update(chunk)
                for region in regions:
                    start = max(position, region["offset"])
                    stop = min(end, region["offset"] + region["size"])
                    if start < stop:
                        data = chunk[start - position:stop - position]
                        state = states[region["name"]]
                        state["hash"].update(data)
                        state["bytes"] += len(data)
                        if destination:
                            handles[region["name"]].write(data)
                position = end
        if position != expected:
            raise ValueError("Image does not match expected raw size")
        results = []
        for region in regions:
            state = states[region["name"]]
            digest = state["hash"].hexdigest()
            if state["bytes"] != region["size"] or digest != region["sha256"]:
                raise ValueError(f"Independent verification failed: {region['name']}")
            results.append({"name": region["name"], "bytes": state["bytes"], "sha256": digest})
        for handle in handles.values():
            handle.close()
        if destination:
            for region in regions:
                (destination / (region["name"] + ".img.partial")).rename(destination / (region["name"] + ".img"))
        return {"raw_bytes": position, "raw_sha256": raw_hash.hexdigest(),
                "verified_regions": results,
                "limitation": "Matching regions do not validate live /data consistency or prove recovery will work."}
    finally:
        for handle in handles.values():
            handle.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path)
    parser.add_argument("layout", type=Path, help="Local JSON with byte offsets, lengths, and independent SHA-256 hashes")
    parser.add_argument("--extract-dir", type=Path, help="New local directory for verified raw regions")
    args = parser.parse_args()
    print(json.dumps(verify(args.image, json.loads(args.layout.read_text()), args.extract_dir), indent=2))


if __name__ == "__main__":
    main()
