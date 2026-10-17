# Boot-screen investigation and remaining checks

The setup is not complete and must not be represented as a validated end-to-end recipe.

## Last verified state

- The original full-memory image and twelve selected regions were acquired and hash-verified before application installation.
- `/system` remained read-only. No bootloader, boot, recovery, or system image was flashed. No SuperSU installation was run.
- KOReader, Simple Ink Launcher, and Firefox were confirmed in the installed package list.
- Both offline dictionaries answered real queries using KOReader's included engine.
- The user confirmed KOReader displayed correctly on the physical panel. The Android screenshot appeared rotated with black strips; this was not a physical display problem.
- The NOOK USB dialog was dismissed successfully with `adb shell input keyevent 4` while a connection was available.

## Open symptoms

The host kernel reported repeated USB protocol errors (`-71`) and disconnects. The reader later stopped enumerating on USB. A normal power-off and power-on was performed by the user. The user then reported the NOOK logo and a repeatedly moving Loading indicator for about five minutes. Brief presses of the home and power buttons did not reach the home interface.

The cause has not been established. Do not infer that the system or boot image was changed simply from the loading symptom, and do not infer that a correct image hash proves restoration will succeed.

## Current conservative step

A manufacturer-documented soft reset was proposed, but the user did not need to complete it. After unplugging USB, a short power-button press changed the screen; a second press brought up the Android home chooser. The user then selected Simple Ink Launcher with Always, having used Just once earlier. No factory reset or image restoration was performed. The loading-screen symptom is cleared; the USB cause remains unconfirmed.

The original device backups and diagnostic files remain local. Their private paths and device identifiers are intentionally not published.

## Still required

- Restore a stable USB connection for the final checks.
- Confirm stock ADB permissions after restart and remove temporary backup/rooting files.
- Restore the prior stay-awake setting (`0`), which was temporarily changed during transfers.
- Confirm the selected home preference persists at the next normal start.
- Complete browser configuration and actual access/download testing. No account token has been entered or stored by this project.
