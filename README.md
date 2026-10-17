# NOOK GlowLight 3: backup-first root notes

Tools and documented observations for the Barnes & Noble NOOK GlowLight 3 (BNRV520), focused on preserving the original system before permanent root installation.

## Current status

- USB debugging and authorized ADB confirmed on a BNRV520 running Android 4.4.2 / `53.0.112_user`.
- The temporary `adbhack` stage from the upstream rooting project provided a root ADB shell while `/system` remained read-only.
- Shared-storage files were archived and checked file by file.
- Internal-memory backup and independent partition verification are in progress.
- Permanent root and recovery restoration are not yet validated by this project.

These are observations from one device, not a compatibility guarantee. Rooting has a nonzero risk of data loss or a device that will not boot.

## Backup scope

A copy of the USB-visible drive is a shared-storage backup, not a complete Android or boot backup. A full image taken while Android is running is also **not an atomic offline snapshot**: writable `/data` and `/cache` can change during acquisition. Immutable boot and system regions must be checked independently before relying on them. Do not blindly restore a live image over an entire device.

## Upstream references

- [Original rooting scripts and model-selection note](https://github.com/wmahfoudh/rooting-nook-glowlight), reviewed at commit `b290e7db6426064436bee7a7c0c1cf5d896255a7`.
- [XDA GlowLight 3 setup thread](https://xdaforums.com/t/how-to-root-and-set-up-a-new-nook-glowlight-3.3802331/) — the page returned HTTP 403 during this session, so its contents were not independently reviewed.
- [TWRP device source](https://github.com/Ryogo-X/nook_ntx_6sl_twrp) documents booting recovery from RAM. No recovery image has been flashed or tested by this project.

Changing `BNRV510` to `BNRV520` in upstream `rootnook.sh` changes its ADB selection filter; it does not change the hardware model. The complete upstream script installs SuperSU and modifies `/system`; it does not create a backup first. This repository does not redistribute upstream APKs or executable payloads.

## Publication policy

Only reusable code, instructions, and non-identifying observations belong here. Device backups, serial numbers, partition dumps, account data, and ADB keys remain local. Each substantive improvement is committed separately.

## Capture tool

Requirements: Python 3.8+, host `adb`, an explicitly authorized **root** ADB shell, and the upstream BusyBox already present on the device. This tool neither obtains root nor installs anything on the NOOK. Keep the USB cable connected throughout acquisition.

```sh
python3 nook_backup.py --serial YOUR_DEVICE_SERIAL \
  --busybox /data/local/tmp/.nookrooter/busybox \
  --output backups/mmcblk0-pre-root.img.gz
python3 -m unittest -v
```

The tool restricts capture to BNRV520, reads the device size, checks binary transport through old ADB, streams and validates gzip CRC and raw size, and records SHA-256 hashes. Interrupted or invalid captures retain a `.partial` extension. Existing outputs are not overwritten. A verified transfer proves stream integrity, not filesystem consistency or restorability. The manifest excludes the device serial.

Tests cover binary byte preservation, long zero runs, truncation, corrupt CRC, wrong image size, and unexpected trailing data.
