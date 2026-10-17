# Additional app candidates for Android 4.4.2

These are version-specific candidates, not claims that the latest release works or that each app has been tested on the NOOK. Total Commander and KOReader are already installed; nothing in this list was installed during this research. Minimum Android compatibility alone does not establish usable speed, contrast, hardware support, or current online-service compatibility.

| App/version | Purpose | Minimum Android | Evidence |
| --- | --- | --- | --- |
| uNote 1.7.5, code 29 | Lightweight notes and lists | 4.4 / SDK 19 | Archived F-Droid APK manifest inspected with aapt2 |
| Simple Keyboard 5.29, code 115 | Lightweight system keyboard | 4.4 / SDK 19 | Archived F-Droid APK manifest inspected with aapt2 |
| SudoQ 2.1.1, code 43 | Offline sudoku variants | 4.4 / SDK 19 | Archived F-Droid APK manifest inspected with aapt2 |
| Calculator++ 2.2.7, code 158 | Standard/scientific calculation | 4.4 / SDK 19 | F-Droid's version entry |
| Aard 2 0.58, code 58 | Standalone offline dictionaries | 4.4 / SDK 19 | F-Droid's version entry; dictionary data needed separately |
| AnkiDroid 2.14.6 | Flashcards for vocabulary/study | 4.1 / SDK 16 | Archived F-Droid listing and official historical changelog |

The notes/keyboard/sudoku APKs were downloaded only for manifest inspection. Their observed hashes are in `diagnostics/app-candidate-inspection.json`; these are not independently authenticated release hashes or installation approval. Recheck official provenance/signatures and the complete device transfer before installing. APK binaries are not redistributed here.

## Sources

- [uNote and version history](https://f-droid.org/en/packages/app.varlorg.unote/) — 1.8.0 raised the minimum to Android 5; newer releases require more.
- [Simple Keyboard build metadata](https://gitlab.com/fdroid/fdroiddata/-/blob/master/metadata/rkr.simplekeyboard.inputmethod.yml).
- [SudoQ and version history](https://f-droid.org/en/packages/de.sudoq/) — the 3.x series requires Android 5; do not substitute it for the inspected 2.1.1.
- [Calculator++ version-specific requirements](https://f-droid.org/en/packages/org.solovyev.android.calculator/).
- [Aard 2 version-specific requirements](https://f-droid.org/packages/itkach.aard2/).
- [AnkiDroid official historical changelog](https://docs.ankidroid.org/changelog.html) and [archived F-Droid listing](https://bluet.gitlab.io/fdroid-website/en/packages/com.ichi2.anki/). Modern AnkiWeb synchronization and newer deck formats are not verified for this old client; offline card study is the candidate use case.

Notes, calculations, dictionaries, and static puzzles suit a reading-focused device more closely than animation-heavy apps. Their actual interaction and refresh still need a device trial. Changing Android's default keyboard would affect normal Android apps; KOReader uses its own keyboard in its dialogs.
