# Display residue and page buttons: investigation in progress

The user reports physical-panel ghosting, possibly across applications and noticed at the NOOK loading screen, as well as page buttons behaving differently. This is a new physical-panel report, distinct from the earlier screenshot-only rotation and black strips. Neither symptom is resolved yet.

## Page buttons

KOReader's [Android wiki](https://github.com/koreader/koreader/wiki/Android-tips-and-tricks#nook-glowlight-3) documents GlowLight 3 key codes 139–142. The candidate `config/event_map.lua` maps both sides to page forward/backward while preserving separate left/right event names. It is prepared only: no installation or physical-button validation has occurred.

The [keymapping documentation](https://github.com/koreader/koreader/wiki/Keymapping) specifies `koreader/settings/event_map.lua`. On this installation, that means `/sdcard/koreader/settings/event_map.lua`. Preserve any existing mapping, close KOReader normally, install the file, reopen KOReader, and test all four buttons inside an actual book. If codes differ, obtain the actual key events before changing the mapping. The wiki's prose and positional comments disagree about button direction; verify the user's preferred physical direction rather than treating those labels as authoritative.

This file changes KOReader only. It does not remap Android system keys or make every application interpret page buttons identically. No system key-layout edit is needed for this candidate.

## Refresh support

The official installed APK contains the `NookEPDController`, `NTXEPDController`, and `bnrv520` identifiers. This establishes that the APK includes support, not that the running app selected it successfully.

Upstream [NookEPDController](https://github.com/koreader/android-luajit-launcher/blob/75a8f73885b5e891a1dea87583f750141e768de7/app/src/main/java/org/koreader/launcher/device/epd/NookEPDController.kt) identifies this as a tested GlowLight 3 implementation, exposes full-only mode, and delays full updates by 500 ms to allow the system driver to finish. [DeviceInfo](https://github.com/koreader/android-luajit-launcher/blob/75a8f73885b5e891a1dea87583f750141e768de7/app/src/main/java/org/koreader/launcher/device/DeviceInfo.kt) recognizes BNRV520. These source observations are not a reason to replace firmware or install a custom APK.

Next checks are the same book/page-turn sequence in the original NOOK reader and KOReader, KOReader's reported E-ink platform, its refresh interval, and controller errors in logs. Only after confirming support should a full refresh every page be tried, then a longer interval if acceptable. KOReader's refresh setting cannot be assumed to control Simple Ink Launcher or Firefox.

## Current access limitation

ADB and the host USB inventory contain no NOOK device despite the user reporting the cable connected. Previous kernel logs show USB protocol error -71, followed by disconnection; this does not establish whether the current cause is cable, connector, port, or device USB state. A known data cable on a direct computer port and a comparison in the original reader have been requested. No screen-driver or key-layout changes have been applied during this investigation.
