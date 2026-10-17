#!/usr/bin/env python3
"""Install an APK only after completed transfer and matching device SHA-256."""

import argparse
import hashlib
from pathlib import Path
import re
import shlex
import subprocess
import uuid


def adb(serial, *arguments):
    return subprocess.run(["adb", "-s", serial, *arguments], check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          timeout=180).stdout


def install(serial, apk, expected_sha256, package, busybox):
    apk = Path(apk).resolve()
    if not re.fullmatch(r"[0-9a-f]{64}", expected_sha256):
        raise ValueError("Expected SHA-256 must be 64 lowercase hexadecimal digits")
    if not re.fullmatch(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)+", package):
        raise ValueError("Invalid expected package name")
    digest = hashlib.sha256()
    with apk.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    if digest.hexdigest() != expected_sha256:
        raise ValueError("Local APK does not match the expected SHA-256")
    if adb(serial, "shell", "getprop ro.product.model").strip() != b"BNRV520":
        raise ValueError("Device model must be BNRV520")
    remote = "/data/local/tmp/nook-install-" + uuid.uuid4().hex + ".apk"
    print("Transferring APK...", flush=True)
    adb(serial, "push", str(apk), remote)  # Must finish before reading or installing.
    result = adb(serial, "shell", f"{shlex.quote(busybox)} sha256sum {remote}")
    if result.decode().split()[0] != expected_sha256:
        raise ValueError("Device APK hash mismatch; installation was not attempted")
    print("Transfer verified; installing APK...", flush=True)
    result = adb(serial, "shell", f"pm install -r {remote}")
    if "Success" not in result.decode().split():
        raise RuntimeError("Package manager did not report Success: " + result.decode())
    installed = adb(serial, "shell", "pm list packages -3").decode().splitlines()
    if "package:" + package not in installed:
        raise RuntimeError("Expected package is not present after installation")
    adb(serial, "shell", f"rm -f {remote}")
    return package


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--busybox", required=True, help="Existing device BusyBox used for hashing")
    args = parser.parse_args()
    print("Verified installation:", install(args.serial, args.apk, args.sha256, args.package, args.busybox))


if __name__ == "__main__":
    main()
