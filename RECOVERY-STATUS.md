# Boot-screen investigation and recovery limits

The loading-screen interruption cleared without a reset or image restoration. The current launcher, KOReader page buttons/refresh, authenticated search, member EPUB download/opening, and bibliographic viewer have been checked on the tested BNRV520. Recovery restoration itself remains untested.

## Original backup

The full-memory image and twelve selected regions were acquired and hash-verified before installing applications. `/system` stayed read-only. No bootloader, boot, recovery, or system image was flashed, and no SuperSU installation ran. Backups and device identifiers remain local. A live image is not an atomic snapshot of writable filesystems, and a matching transfer hash does not establish restorability.

## Loading and USB symptoms

The host reported intermittent USB protocol errors (-71) and disconnects. Following a normal power-off/on, the user saw the NOOK Loading indicator for about five minutes. Brief home/power presses initially did not reach home. The cause was not established.

After unplugging USB, a short power press changed the screen and a second brought up Android's home chooser. The user chose Simple Ink Launcher with Always. No proposed forced reset was needed. The loading symptom cleared and authorized USB/ADB later returned; the precise USB fault remains unconfirmed. Persistence through a further reboot was not deliberately tested merely to repeat the interruption.

## Post-reconnection checks

ADB had stock shell UID 2000 and completed boot, no temporary `/sbin` overlay, and no `su` in standard system locations. Temporary root/backup files and staged APKs were removed. Stay-awake's original setting is zero; temporary USB testing must restore it. KOReader's four-button mapping and full refresh every page were applied after saving the previous settings, and the user confirmed improvement.

Firefox crashes and the stock browser's modern HTTPS failed. The independent KOReader integration is the verified standalone search/download route; see [ANNA-INTEGRATION.md](ANNA-INTEGRATION.md). This setup does not require permanent root or recovery flashing.
