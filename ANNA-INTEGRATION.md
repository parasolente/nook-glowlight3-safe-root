# Anna's Archive inside KOReader — work in progress

The user chose an integrated KOReader search/download menu after Firefox failed. The requested initial origin remains `https://annas-archive.gl`. Native-device HTTPS, search, and downloads are still being validated; do not present this as a completed, tested download flow yet.

## Why Firefox was not usable

The official Firefox 68.11.0 APK installed, but launching it crashed. The local log shows `Failed to create EGLConfig!` immediately before the crash handler. A separate, unauthenticated external profile disabling accelerated/off-main-thread composition also crashed. That diagnostic profile was deleted. Its preferences are retained in `config/firefox-software-test-prefs.js` as a failed experiment, not a fix.

The original Android browser opened but returned `ERR_SSL_PROTOCOL_ERROR` for the requested site. Wi-Fi was connected and the device date was correct. Another official domain was tried only as a network diagnostic; the user reiterated that `.gl` should be used. No account key was entered during browser testing. No additional browser was installed.

## Independent plugin

`koreader/nookarchive.koplugin` is a new implementation, not a copy of either reviewed third-party Anna plugin. The third-party variants were reviewed but not installed. They did not provide the requested member-token workflow directly.

Menu location: KOReader's top **Search** menu → **Anna’s Archive (NOOK)**. The entry is available while reading and in the file browser.

- Search by title, author or ISBN; default format is EPUB. Format can cycle to PDF or all results.
- Edit the HTTPS domain in the menu. Changing it clears the stored account key.
- Edit the download folder; default `/storage/spsd/NOOK/Books/Downloads`.
- Enter the member token on the device in the masked dialog. On Android it is stored in KOReader's app-private files directory with mode 0600, bound to the selected origin. It is never put into shared settings, a public repository, or a displayed URL. A failed private save keeps it in memory only.
- Fast downloads use the [documented member API](https://annas-archive.gl/dyn/api/fast_download.json). An active membership/download allowance is required. The plugin does not automate a browser verification challenge or claim to provide free anonymous downloads.
- A known `/md5/…` identifier can be entered if search is unavailable.
- Requests validate the certificate chain and DNS subject-alternative name before sending HTTP. Account requests do not follow redirects. Download redirects must remain HTTPS and receive no account token/header.
- Files are streamed to `.partial` and renamed only after their MD5 matches the selected identifier. Existing files are not overwritten.

The Lua 5.1 syntax check and local tests for origin validation, DNS hostname checks, HTML result extraction, and the TLS adapter passed. Physical device tests remain pending at this checkpoint. Search depends on the site's HTML and can break or require a browser challenge; that limitation must be reported honestly.

## Installation and rollback

Stop KOReader, copy the plugin folder to `/sdcard/koreader/plugins/`, then reopen KOReader. Remove that folder while KOReader is stopped to disable it. Clear the token through the menu before removal if the private credential file should also be deleted. No system files or root access are required.

Keep `cacert.pem` and its third-party notice with the plugin. Tests run from this repository root:

```sh
lua5.1 tests/test_nookarchive.lua
luac5.1 -p koreader/nookarchive.koplugin/client.lua koreader/nookarchive.koplugin/main.lua
```
