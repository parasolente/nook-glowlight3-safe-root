#!/usr/bin/env python3
"""Read and verify a NOOK memory image; never flash or install root."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shlex
import subprocess
import time
import zlib

PROBE = b"NOOK\x00\x01\x0a\x0d\xffEND"
BLOCK = "/dev/block/mmcblk0"
LIVE_LIMITATION = (
    "Acquired while Android was running; writable /data and /cache are not "
    "an atomic offline snapshot. Restoration has not been tested."
)


def adb(serial, *arguments, **kwargs):
    return subprocess.run(
        ["adb", "-s", serial, *arguments], check=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60, **kwargs
    ).stdout


def consume_gzip(source, destination, expected_size, progress=None):
    """Stream a single gzip member, checking CRC, length, and trailing data."""
    decoder = zlib.decompressobj(16 + zlib.MAX_WBITS)
    raw_hash, gzip_hash = hashlib.sha256(), hashlib.sha256()
    raw_size = compressed_size = 0
    while chunk := source.read(65536):
        destination.write(chunk)
        gzip_hash.update(chunk)
        compressed_size += len(chunk)
        pending = chunk
        while pending:
            raw = decoder.decompress(pending, 4 * 1024 * 1024)
            pending = decoder.unconsumed_tail
            raw_size += len(raw)
            if raw_size > expected_size:
                raise ValueError("Image exceeds the expected device size")
            raw_hash.update(raw)
        if decoder.unused_data:
            raise ValueError("Unexpected data after the gzip member")
        if progress:
            progress(raw_size, compressed_size)
    tail = decoder.flush()
    raw_hash.update(tail)
    raw_size += len(tail)
    if not decoder.eof:
        raise ValueError("Truncated gzip stream")
    if raw_size != expected_size:
        raise ValueError(f"Image has {raw_size} bytes; expected {expected_size}")
    return {
        "raw_bytes": raw_size, "compressed_bytes": compressed_size,
        "raw_sha256": raw_hash.hexdigest(), "gzip_sha256": gzip_hash.hexdigest(),
        "gzip_crc_verified": True,
    }


def capture(serial, busybox, output):
    output = Path(output)
    if output.exists() or Path(str(output) + ".partial").exists():
        raise FileExistsError("Refusing to overwrite a backup or partial backup")
    for suffix in (".manifest.json", ".sha256"):
        if Path(str(output) + suffix).exists():
            raise FileExistsError("Backup metadata already exists")
    model = adb(serial, "shell", "getprop ro.product.model").strip()
    if model != b"BNRV520":
        raise ValueError("This capture command is restricted to BNRV520")
    if adb(serial, "shell", "id -u").strip() != b"0":
        raise PermissionError("An already-authorized root ADB shell is required")
    # Quote every remote path; the device serial is a separate host argument.
    bb = shlex.quote(busybox)
    size_text = adb(serial, "shell", f"{bb} blockdev --getsize64 {BLOCK}").strip()
    if not re.fullmatch(rb"[0-9]+", size_text):
        raise ValueError("Unable to read the block-device size")
    expected = int(size_text)
    if not 1_000_000_000 <= expected <= 32_000_000_000:
        raise ValueError("Unexpected BNRV520 block-device size")
    # Old adbd lacks exec-out and translates LF to CRLF through its PTY.
    # Verify NUL, LF, CR, and a non-ASCII byte before trusting binary output.
    probe_command = f'{bb} stty raw -echo && {bb} printf "NOOK\\000\\001\\012\\015\\377END"'
    if adb(serial, "shell", probe_command) != PROBE:
        raise ValueError("ADB binary transport probe failed")
    command = f"{bb} stty raw -echo && {bb} cat {BLOCK} | {bb} gzip -1 -c"
    output.parent.mkdir(parents=True, exist_ok=True)
    partial = Path(str(output) + ".partial")
    process = subprocess.Popen(
        ["adb", "-s", serial, "shell", command],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    started = last = time.monotonic()

    def report(raw, compressed):
        nonlocal last
        if time.monotonic() - last >= 20:
            print(f"{raw / expected:.1%}: {raw:,}/{expected:,} bytes; "
                  f"{compressed:,} compressed bytes", flush=True)
            last = time.monotonic()

    try:
        with partial.open("xb") as destination:
            result = consume_gzip(process.stdout, destination, expected, report)
        if process.wait(timeout=60) != 0:
            raise RuntimeError("ADB failed; the partial backup was retained")
        partial.rename(output)
        result.update({"model": "BNRV520", "expected_raw_bytes": expected,
                       "elapsed_seconds": round(time.monotonic() - started, 1),
                       "limitation": LIVE_LIMITATION})
        Path(str(output) + ".manifest.json").write_text(json.dumps(result, indent=2) + "\n")
        Path(str(output) + ".sha256").write_text(result["gzip_sha256"] + "  " + output.name + "\n")
        return result
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", required=True, help="Explicit authorized device serial (not saved)")
    parser.add_argument("--busybox", required=True, help="Existing BusyBox path on the NOOK")
    parser.add_argument("--output", type=Path, required=True, help="Local .img.gz destination")
    args = parser.parse_args()
    print(json.dumps(capture(args.serial, args.busybox, args.output), indent=2))


if __name__ == "__main__":
    main()
