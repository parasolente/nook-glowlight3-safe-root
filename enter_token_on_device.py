#!/usr/bin/env python3
"""Enter a key into an already-open, verified KOReader password dialog.

The key is read without terminal echo. Only individual characters are passed to
Android's input command; the complete key is never a command-line argument.
This helper neither submits the dialog nor writes the key to a host file.
"""
import argparse
import getpass
import re
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--dialog-ready", action="store_true", required=True)
    args = parser.parse_args()
    key = getpass.getpass("Account key (hidden): ")
    if not re.fullmatch(r"[A-Za-z0-9]{1,256}", key):
        raise SystemExit("This helper accepts alphanumeric keys only; use the device keyboard otherwise.")
    commands = "".join("input text " + character + "\n" for character in key)
    result = subprocess.run(
        ["adb", "-s", args.serial, "shell"], input=commands.encode("ascii"),
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60,
    )
    if result.returncode:
        raise SystemExit("Device input failed; inspect the masked dialog locally.")
    print("Key entered into the dialog; not submitted or saved on this computer.")


if __name__ == "__main__":
    main()
