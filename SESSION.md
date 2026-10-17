# Setup progress

## Result on the tested device

The BNRV520 runs Android 4.4.2, firmware `53.0.112_user`, on ARMv7/NEON. Simple Ink Launcher is selected with Always. KOReader, offline English–Spanish and Spanish dictionaries, page-button mappings, full refresh every page, and the independent archive integration are installed. The original NOOK app remains available. Firefox installed but crashes; it is not the working book-access method.

Authenticated catalog search, a member EPUB download with native MD5 verification, opening that EPUB, and the bibliographic viewer were exercised directly on the NOOK. Normal use needs Wi-Fi and the configured account, not the host computer. See [ANNA-INTEGRATION.md](ANNA-INTEGRATION.md).

## Backup and system scope

USB debugging was authorized before work. USB-visible files were archived and compared file by file. The upstream scripts were reviewed at the README's pinned commit. Only `doroot.sh adbhack` was used for a temporary root ADB shell to read storage; SuperSU was not installed and `/system` remained read-only.

The actual device partition map and independent SHA-256 hashes were collected. An old ADB shell changed LF into CRLF and did not support exec-out; a binary transport probe and BusyBox raw terminal mode established byte-preserving capture. The resulting full image contains 7,818,182,656 raw bytes and 473,766,758 gzip bytes. Gzip CRC, raw size, twelve independently hashed regions, and a separate whole-image SHA-256 read all matched.

After the user's reboot, ADB returned to UID 2000, boot completion was confirmed, and the temporary `/sbin` overlay and standard system `su` paths were absent. Temporary root/backup files and staged APKs were removed. No bootloader, boot, recovery, or system image was flashed. The original USB stay-awake value is zero and must be restored after any temporary test session.

The acquisition is live, not an atomic offline snapshot of writable `/data` and `/cache`; restoration has not been tested. Read-only `e2fsck -fn` reported unset padding bits at the end of an inode bitmap in the original system image. Its hash matches the unchanged device; no repair was attempted.

## Apps, storage, dictionaries, and display

Official APK digests and sources are recorded in `sources.json`. Package compatibility was inspected with Google's aapt2; KOReader requires API 18, the launcher API 17, and this device provides API 19. Installation checks now wait for transfer completion, compare hashes, require package-manager Success, and verify the package list.

`/sdcard` is Android emulated storage. The separate USB-visible filesystem is `/storage/spsd`, backed by `/data/sparse_image`. Books use `/storage/spsd/NOOK/Books/`; archive downloads use its `Downloads/` child. Dictionaries are under `/sdcard/koreader/data/dict/`.

Both StarDict archives were validated before transfer, including index/data boundaries and synonym references. KOReader's included dictionary engine returned English–Spanish entries for `book` and Spanish definitions for `libro` with Wi-Fi disabled. Touch-based lookup remains a separate user-interface check; the engine and installed data are verified.

The four-button KOReader mapping and day/night full-refresh interval of one were installed after preserving original settings. The Nook/NTX driver and full-screen mode-34 requests were observed. The user confirmed the buttons work and ghosting improved substantially. This does not establish refresh behavior in every other app.

## Resolved interruptions and limits

USB intermittently reported protocol error -71 and stopped enumerating. The cause remains unconfirmed. After a normal restart, the user saw a persistent Loading screen. Unplugging USB and briefly pressing power twice brought up the home chooser; selecting the launcher with Always cleared the symptom. No forced reset, factory reset, or image restoration was performed. USB/ADB subsequently returned.

The stock sleep screen can cover an otherwise focused app and sometimes requires a physical home-button press. Android screenshots were rotated and sometimes had black bands; the user confirmed the physical display was correct.

Firefox failed with an EGL configuration error, including with a separate software-rendering test profile; that profile was deleted. The stock browser returned an SSL protocol error. Anonymous archive search was blocked during development. The user authorized an account token and direct account-session integration, which now works. Credentials remain app-private; cookies remain in memory; downloaded books and diagnostics remain local.

The reusable scripts, configuration, plugin, tests, and documentation are published in English. Device serials, ADB keys, account data, raw storage, and downloaded books are excluded.
