# NOOK GlowLight 3: backup-first root notes

Tools and documented observations for the Barnes & Noble NOOK GlowLight 3 (BNRV520), focused on preserving the original system before permanent root installation.

## Current status

**Setup is in progress:** Simple Ink Launcher is selected with Always, USB/ADB access has returned, and stock shell permissions are confirmed. Temporary backup/root files were removed and the original stay-awake setting restored. All four page buttons now work in KOReader; the user confirmed that full refresh on every page substantially improves ghosting. Browser configuration and validation remain pending; see `RECOVERY-STATUS.md`.

- USB debugging and authorized ADB confirmed on a BNRV520 running Android 4.4.2 / `53.0.112_user`.
- The temporary `adbhack` stage from the upstream rooting project provided a root ADB shell while `/system` remained read-only.
- Shared-storage files were archived and checked file by file.
- Full-memory acquisition completed: 7,818,182,656 raw bytes; gzip CRC and exact length verified. Twelve independently hashed regions matched, and a separate whole-image read matched the acquisition SHA-256.
- The selected setup is KOReader, Simple Ink Launcher, and offline dictionaries without permanent root. SuperSU will not be installed. Recovery restoration remains untested.

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

## Independent region verification

`verify_regions.py` reads a local gzip image and compares selected byte ranges against SHA-256 hashes obtained separately from the physical device. It can extract matching regions to a new directory. It does not connect to ADB or write to a device.

Create a **local** layout JSON using the actual device's partition starts and sizes from `/sys/block/mmcblk0/mmcblk0p*/{start,size}`. Multiply sector values by 512; do not copy offsets from a different model or assume that an extended partition is a filesystem. Obtain each expected hash independently while the original region is unchanged.

```json
{
  "expected_raw_bytes": 7818182656,
  "regions": [
    {"name": "system", "offset": 54525952, "size": 402644992,
     "sha256": "REPLACE_WITH_THE_INDEPENDENT_DEVICE_SHA256"}
  ]
}
```

The numeric example reflects one observed BNRV520; it is not a universal partition map. The placeholder is intentionally invalid.

```sh
python3 verify_regions.py backups/mmcblk0-pre-root.img.gz backups/layout.json \
  --extract-dir backups/verified-regions
```

The verifier checks the gzip CRC, full raw length, every selected region's size and SHA-256, and returns the whole-image SHA-256. Compare that whole-image digest with the acquisition manifest too. Failed extractions keep `.partial` extensions. Tests also cover region boundaries spanning read chunks, mismatching hashes, invalid ranges, path traversal, and existing output directories.

## Dictionary preparation

`prepare_dictionary.py` extracts a StarDict ZIP into a new local directory and validates the `.ifo`, `.idx`, dictionary data, and synonym references before transfer. It rejects ZIP path traversal and symbolic links, validates gzip CRC for `.dict.dz`, and produces per-file SHA-256 hashes. It does not transfer files to the NOOK.

```sh
python3 prepare_dictionary.py dictionary.zip backups/prepared-dictionary
```

Selected public dictionary sources, linked from the [KOReader dictionary documentation](https://github.com/koreader/koreader/wiki/Dictionary-support):

- [WikDict English–Spanish](https://download.wikdict.com/dictionaries/stardict/wikdict-en-es.zip), under the [WikDict reuse terms](https://www.wikdict.com/page/download).
- [reader.dict Spanish, without etymology](https://www.reader-dict.com/download/es). Keep dictionary metadata and attribution with the files.

On Android, KOReader expects dictionaries under `/sdcard/koreader/data/dict/`. Dictionary files are not redistributed in this repository.

## Verified APK installation

`install_verified_apk.py` waits for ADB's file transfer to finish, compares both local and on-device SHA-256 with the expected digest, requires explicit `Success` from Android's package manager, and checks that the expected package is installed. An old ADB connection can close without a useful install result; a zero command exit alone is not enough. Use the official digests recorded in `sources.json`.

```sh
python3 install_verified_apk.py app.apk --serial YOUR_DEVICE_SERIAL \
  --sha256 EXPECTED_SHA256 --package org.example.app \
  --busybox /data/local/tmp/.nookrooter/busybox
```

The existing BusyBox is used only as a hash utility; this script does not obtain root. Tests confirm that a hash mismatch blocks the package manager and that a failure message cannot be mistaken for success.

## KOReader page buttons and ghosting

`config/event_map.lua` maps the four stock GlowLight 3 page buttons inside KOReader. After backing up any existing mapping and closing KOReader, install it at `/sdcard/koreader/settings/event_map.lua` and reopen the app. The user confirmed all four buttons work. This does not change system key layouts or other apps.

`set_refresh_interval.py` prepares a copy of an existing KOReader settings file, changing only the day/night full-refresh intervals. It never executes Lua and refuses to overwrite an output file. Close KOReader before acquiring or replacing settings; keep the original local copy.

```sh
python3 set_refresh_interval.py settings.reader.before.lua settings.reader.prepared.lua --count 1
```

Deploy the prepared copy to `/sdcard/koreader/settings.reader.lua` while KOReader is stopped, then reopen it. An interval of one requests a full refresh on every eligible page update, increasing visible flashing. On this device, logs confirmed the Nook/NTX controller and full-screen mode-34 requests; the user confirmed much better ghosting. This setting does not control launcher/browser refresh. Restore the saved original file to undo the interval change, and remove or restore `event_map.lua` to undo the key mapping. See `DISPLAY-AND-BUTTONS.md` for observations and limits.
