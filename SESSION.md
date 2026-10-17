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
7. Completed gzip-compressed full-memory acquisition: 7,818,182,656 raw bytes and 473,766,758 compressed bytes. Gzip CRC, raw size, all twelve independently hashed regions, and the separately recomputed whole-image SHA-256 matched.
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

- Finish visual launch checks for the installed applications.
- Confirm touch-based dictionary lookup and shared-storage access in the reader UI.
- Test actual browser access; do not claim authenticated downloads work before testing.
- Confirm the Always home selection persists at the next normal start; the new launcher is already in use.

Recovery restoration is untested. A live acquisition is not an atomic snapshot of writable `/data` or `/cache`.

## Filesystem diagnostic limitation

A read-only `e2fsck -fn` of the extracted original system image reported unset padding bits at the end of an inode bitmap. The extracted image matches the device's original SHA-256, so this is not evidence of transfer corruption. The image and the device filesystem were left unchanged. A hash-verified acquisition must not be described as a tested restore or a filesystem with no diagnostic warnings.

## Application installation and offline checks

All three selected packages are now installed: `org.koreader.launcher`, `org.ds.simple.ink.launcher`, and `org.mozilla.firefox`. Intermittent ADB transfers required explicit rechecking of the installed package list. One browser installation was attempted before its transfer finished and Android rejected it as invalid; after completion and a full hash match, the same official APK installed successfully. `install_verified_apk.py` and its tests now guard the transfer/verification/install sequence.

Both prepared dictionaries were copied into KOReader's dictionary directory. The included `libsdcv.so` engine, with Wi-Fi disabled, returned two English–Spanish entries for `book` and Spanish definitions including the exact entry `libro`. The root-shell diagnostic emitted a local configuration-directory warning before its JSON results; the lookups themselves succeeded. Touch-based UI lookup remains to be checked.

During setup, `svc power stayon usb` temporarily changed the previous stay-awake setting of `0`; it must be restored before completion. The stock NOOK sleep overlay required physical wake-up and can cover an otherwise focused Android app.

## New display and button report

After choosing the new launcher persistently, the user reported ghosting on the physical panel, possibly across applications and noticed since the loading screen, plus different page-button behavior. USB still does not enumerate, so no live configuration change or fix is verified. `DISPLAY-AND-BUTTONS.md` records the upstream findings and pending comparison; `config/event_map.lua` is a prepared, unapplied KOReader-only mapping. This report must not be dismissed as the earlier screenshot artifact.

Follow-up: USB/ADB returned. Stock shell UID 2000, completed boot, no temporary `/sbin` overlay, and no `su` at the standard system locations were confirmed. The temporary root/backup directory and staged APKs were removed, and stay-awake was restored to zero. KOReader selected the Nook/NTX driver. Its four-button mapping was installed, and both full-refresh intervals were set to one after backing up existing settings. Logs show full-screen mode-34 requests; the user confirmed the four buttons work and refresh is much better. The browser remains unfinished.

## Integrated archive work

Firefox's real launch test failed with an EGL configuration error; an isolated software-rendering profile also crashed and was removed. The stock browser returned an SSL protocol error. The user explicitly chose integration inside KOReader and reiterated `.gl` as the requested domain. A new independent plugin was written, syntax-checked and locally tested, then copied to KOReader. Physical HTTPS/search/download checks remain in progress; see `ANNA-INTEGRATION.md`. No member token has been received or entered by this project.

The plugin menu now loads on the NOOK. Anonymous HTTPS to `.gl`'s member API validated the certificate and returned HTTP 400, expected without required parameters. Search initially returned 302; same-origin redirects were implemented and tested. The destination returned 403; an independent host request identified DDoS-Guard. No search results are claimed. A reproducible original EPUB fixture and an unauthenticated download test were added to check the download engine without using any membership allowance. Device download verification remains pending at this checkpoint.

The unauthenticated fixture download completed on the NOOK: 1,496 bytes, matching the expected MD5 before rename. Pulling the saved file back separately confirmed exact equality with the original EPUB. The download transport/storage path is verified, but direct archive search is still blocked and member downloads remain untested. No token has been entered. Public search-index probes did not yield a usable fallback, and none was installed. The user was explicitly informed that the requested standalone search/download workflow is not yet fulfilled.
