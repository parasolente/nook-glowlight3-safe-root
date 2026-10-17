# Total Commander on the BNRV520

Total Commander 3.62d (`com.ghisler.android.TotalCommander`, version code 2490) was installed at the user's request. The developer's [official download page](https://www.ghisler.com/android.htm) links the [release repository](https://www.ghisler.com/fdroid.htm). Its APK declares minimum SDK 8 and includes ARMv7, compatible with the tested Android 4.4.2 / SDK 19 device.

## Verification and result

The official repository's SHA-256 matched the downloaded 5,599,020-byte APK; the repository certificate fingerprint matched the developer's published pin, and the APK signer certificate matched the index. Exact hashes and URLs are in `sources.json`. The APK was staged in `/data/local/tmp/`, pulled back in full, and checked against the expected SHA-256 before installation, without adding a hashing executable or obtaining root.

Android's package manager reported Success, and the expected package was listed. The app launched successfully and displayed the existing `/storage/spsd/NOOK/Books/Downloads` contents. No file move/delete operation was used for testing.

The first screen was covered by the stock USB Mode dialog; its close button dismissed it without activating USB storage. Total Commander's initial automatic theme had very pale text. In **Configure → Font and Colors → Theme**, explicitly selecting **Light**, applying it, and returning to the list produced dark text on a white background.

A **Downloads** bookmark points to the reader's book-download folder, with **Show in home folder** enabled. This is distinct from Android's default `/sdcard/Download` directory. Open the app from Simple Ink Launcher; use the bookmarks toolbar icon or its home entry to reach books.

The app's first-run privacy prompt was accepted as part of installation. No cloud plugin, account, root feature, or subscription was configured. The system and existing books were not changed. Remove Total Commander through Android's app settings to undo the app installation; installed APKs and private app preferences are not published here.

## Legacy signing diagnostic

The official index/APK use legacy SHA-1 JAR signing. Current Java's default verifier treats those signatures as disabled; their mathematical verification was additionally checked in a separate local verifier process with a temporary Java security-properties override. No host-wide or Android security policy was changed. Verification also relied on the pinned certificate fingerprints, official HTTPS distribution, exact APK hash, and Android's package signature checks. A Java `jar verified` message alone is not a substitute for those checks.
