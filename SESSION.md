# Setup progress

## Hardware and scope

Observed device: BNRV520, ARMv7 with NEON, Android 4.4.2, firmware `53.0.112_user`.
The chosen result is **KOReader, an E-Ink launcher, offline English–Spanish and Spanish dictionaries, and browser access without permanent root**.

No bootloader, recovery, boot partition, or `/system` modification is planned for this setup. The original NOOK application stays available.

## Completed preparation

1. Identified the device and obtained USB-debugging authorization.
2. Archived USB-visible files and compared every file's size and SHA-256 against the archive.
3. Reviewed upstream root scripts at the commit linked in the README.
4. Pushed upstream files to `/data/local/tmp/.nookrooter` and ran **only** `doroot.sh adbhack` to obtain temporary root ADB for backup. SuperSU was not installed. `/system` remained read-only.
5. Read the actual partition map and obtained independent SHA-256 hashes for the unchanged partitions and disk gaps.
6. Verified binary transport through the old ADB daemon using NUL, LF, CR, and a non-ASCII test byte. `exec-out` was unsupported. Plain shell output changed LF to CRLF; `busybox stty raw -echo` preserved every probe byte.
7. Started a gzip-compressed full-memory acquisition, with streaming CRC, size, and SHA-256 checks. Final verification remains pending while the transfer runs.
8. Downloaded APKs from official project sources and inspected them with Google's `aapt2` 8.7.3. KOReader requires API 18 and ARMv7; Simple Ink Launcher requires API 17. The observed NOOK runs API 19.
9. Prepared and checked both StarDict dictionaries, including every index/data boundary and synonym reference.

The acquisition prototype was generalized as `nook_backup.py`; the saved-diagnostic layout conversion is reproduced by `make_layout.py`. No device identifiers, credentials, or memory contents are published.

## Storage findings

On this device, `/sdcard` points to Android's emulated storage. The USB-visible NOOK drive is `/storage/spsd`, a separate FAT filesystem backed by `/data/sparse_image`. Do not assume those two locations contain the same files.

Planned paths:

- Books: `/storage/spsd/NOOK/Books/`
- Browser downloads: `/storage/spsd/NOOK/Books/Downloads/`
- KOReader dictionaries: `/sdcard/koreader/data/dict/`

## Browser constraints

The firmware includes `com.android.browser`. Firefox 68.11.0 from Mozilla's own archive is also compatible at the APK level, but Mozilla explicitly ended its security updates in 2020. Downloading it for a compatibility test does not establish that it can safely support a modern authenticated site.

The requested initial bookmark is `https://annas-archive.gl/`. It must remain editable. Account access uses a token entered by the user, not a credential embedded in code. Do not carry the token automatically to newly discovered domains. Each new destination needs separate verification and sign-in.

Current release sources and SHA-256 hashes are recorded in `sources.json`. Dictionary archives and APKs are not redistributed.

## Pending validation

- Complete full-memory acquisition and independent region verification.
- Install and launch the selected applications.
- Confirm offline dictionary lookup and shared-storage access.
- Test actual browser access; do not claim authenticated downloads work before testing.
- Restart into stock ADB, remove temporary rooting files, and confirm the absence of permanent root.
- Confirm the new launcher appears as the home interface while the original NOOK application remains accessible.

Recovery restoration is untested. A live acquisition is not an atomic snapshot of writable `/data` or `/cache`.
