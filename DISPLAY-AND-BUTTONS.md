# KOReader display residue and page buttons: improvement confirmed

The user reported physical-panel ghosting, possibly across applications and noticed at the NOOK loading screen, as well as page buttons behaving differently. This was distinct from the earlier screenshot-only rotation and black strips. After applying the changes below, the user confirmed all four buttons work in KOReader and refresh is much better. No improvement in other applications has been established.

## Page buttons

KOReader's [Android wiki](https://github.com/koreader/koreader/wiki/Android-tips-and-tricks#nook-glowlight-3) documents GlowLight 3 key codes 139–142. `config/event_map.lua` maps both sides to page forward/backward while preserving separate left/right event names. It was installed after confirming no existing mapping was present. All four buttons were physically validated by the user.

The [keymapping documentation](https://github.com/koreader/koreader/wiki/Keymapping) specifies `koreader/settings/event_map.lua`. On this installation, that means `/sdcard/koreader/settings/event_map.lua`. Preserve any existing mapping, close KOReader normally, install the file, reopen KOReader, and test all four buttons inside an actual book. If codes differ, obtain the actual key events before changing the mapping. The wiki's prose and positional comments disagree about button direction; verify the user's preferred physical direction rather than treating those labels as authoritative.

This file changes KOReader only. It does not remap Android system keys or make every application interpret page buttons identically. No system key-layout edit is needed for this candidate.

## Refresh support

The official installed APK contains the `NookEPDController`, `NTXEPDController`, and `bnrv520` identifiers. This establishes that the APK includes support, not that the running app selected it successfully.

Upstream [NookEPDController](https://github.com/koreader/android-luajit-launcher/blob/75a8f73885b5e891a1dea87583f750141e768de7/app/src/main/java/org/koreader/launcher/device/epd/NookEPDController.kt) identifies this as a tested GlowLight 3 implementation, exposes full-only mode, and delays full updates by 500 ms to allow the system driver to finish. [DeviceInfo](https://github.com/koreader/android-luajit-launcher/blob/75a8f73885b5e891a1dea87583f750141e768de7/app/src/main/java/org/koreader/launcher/device/DeviceInfo.kt) recognizes BNRV520. These source observations are not a reason to replace firmware or install a custom APK.

The running application logged `Using Nook/NTX driver`. Its original settings had neither refresh interval set, so this version's UIManager used the default of six. With KOReader stopped, a private settings backup was saved and `set_refresh_interval.py` inserted only `full_refresh_count = 1` and `night_full_refresh_count = 1`. Subsequent logs show repeated full-screen mode-34 refresh requests at 1072 by 1448 pixels, and the user confirmed substantially improved refresh. More visible flashing is expected. KOReader's refresh setting cannot be assumed to control Simple Ink Launcher or Firefox.

## USB and temporary-access follow-up

USB enumeration and authorized ADB returned on a different USB topology. Previous error -71 disconnects remain recorded; the exact earlier cause is unconfirmed. ADB now reports stock `uid=2000(shell)`, boot completed, no `/sbin` overlay, and no `su` at the two standard system locations. The temporary `.nookrooter` directory and staged launcher/browser APKs were removed. The original global stay-awake value was restored to zero. No screen-driver or system key-layout changes were applied.
