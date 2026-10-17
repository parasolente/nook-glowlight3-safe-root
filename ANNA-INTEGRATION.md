# Anna's Archive inside KOReader

The independent `nookarchive.koplugin` provides standalone search, bibliographic details, member downloads, and opening the saved book on the tested BNRV520. It uses the selected origin, initially `https://annas-archive.gl`, directly; no host computer, proxy, or remote helper is needed during normal use. No permanent root is required.

## Usage

1. Open KOReader's top **Search** menu (magnifying glass); on this installation the archive entry is on its second menu page.
2. Open **Anna’s Archive (NOOK)**. **Formato** cycles EPUB → PDF → ALL. Reopen the menu after changing it.
3. Choose **Buscar libros**, enter a title, author, or ISBN, and select a result.
4. Read the scrollable **Ficha del libro**: title, author, language codes, publisher, year, edition, ISBN-13/10, format, size, page count, and synopsis. Missing fields explicitly say they are unavailable; catalog metadata is not independently certified.
5. Choose **Descargar**, then confirm the membership download. An active membership and remaining allowance are required. The final file is opened only when requested.

Default folder: `/storage/spsd/NOOK/Books/Downloads`. The directory and HTTPS domain are editable in the menu. Changing the domain clears the key and session; sign in separately on the new origin. **Descargar con MD5 conocido** also retrieves the record before offering a download. Actual record format determines the filename, including in ALL searches; downloads currently accept EPUB, PDF, and MOBI.

Browsing records does not request a fast-download URL. An existing destination is offered for opening before requesting another member download. Files use their MD5 identifier as the filename.

## Credentials and HTTPS

Enter the authorized member token in the device's masked **Token de miembro** dialog. On Android it is stored in KOReader's app-private files directory with mode 0600 and bound to the selected origin. It is not stored in shared KOReader settings. If private storage fails, it remains in memory only. Enter an empty value to delete it.

The plugin performs the site's normal form POST to `/account/`, sending `key` in the HTTPS request body. Derived account cookies stay in memory for up to an hour and are used only on that origin for search and record requests. A rejected session gets at most one renewal attempt. Login does not follow redirects. Authenticated requests are refused when their expected origin differs from the request origin.

Fast downloads use the [documented member API](https://annas-archive.gl/dyn/api/fast_download.json). The key is sent only to the selected API origin. The resulting HTTPS download hosts receive neither the account token nor search cookies. No credentials, signed URLs, account pages, or downloaded books belong in this repository.

TLS validates the certificate chain using the bundled Mozilla CA file and checks the DNS subject-alternative name before sending HTTP. The system CA store is unchanged. Keep `cacert.pem` and `THIRD-PARTY-NOTICES.md` with the plugin.

Downloads stream into `.partial`, have bounded size/time, and are renamed only after the expected MD5 matches. Existing files are not overwritten. Failed downloads are discarded. The reader still determines whether a particular book is usable; this is not DRM removal.

## Verified on the device

- The menu loads and certificate-validated anonymous HTTPS reaches the member API; HTTP 400 is expected without required parameters.
- The project's original 1,496-byte EPUB test downloaded without an account key or membership allowance. Native MD5 and an independent host byte comparison passed.
- The authorized token was entered through the masked dialog, saved privately, and remained configured after restarting KOReader.
- Authenticated search for Don Quixote returned multiple editions on the NOOK.
- One selected member EPUB downloaded successfully: 1,687,265 bytes, native MD5 matched before rename, and KOReader opened its cover and parsed its pages.
- The bibliographic viewer displayed a real EPUB edition's author, English language code, publisher, year, edition, ISBNs, format, size, and synopsis. Missing page count was shown as unavailable.
- A search with the PDF filter returned different editions. Selecting a 1949 record displayed PDF, English, 49.77 MiB, and explicit missing publisher/ISBN/synopsis fields. No additional member download was requested.
- The temporary USB stay-awake setting was restored to its original zero, and stock shell UID 2000 was checked again after validation.

PDF uses the same streaming/checksum engine. A separate PDF member download has not been consumed merely to repeat the transport test. Availability depends on the selected record and membership. Search depends on site HTML; record details depend on the site's JSON schema. Future domain, login, or schema changes may require an update.

Anonymous search was blocked by site verification during development. The working path uses a normal authenticated account session. Valid result pages also contain DDoS-Guard helper scripts; challenge detection checks response status, page title, and the exact verification redirect instead of rejecting every page containing that script name.

## Local validation and provenance

```sh
lua5.1 tests/test_nookarchive.lua
luac5.1 -p koreader/nookarchive.koplugin/client.lua koreader/nookarchive.koplugin/main.lua
```

Tests cover strict origin parsing, same-origin redirects, chain/SAN verification, cookie extraction with Expires commas, session reuse and bounded renewal, credential isolation, challenge detection, result deduplication, record normalization, missing metadata, and double-encoded record JSON.

The implementation is independently written under MIT. The [bitesized client](https://github.com/bitesized/annas-archive-api/blob/main/lib/annas.js) was reviewed for the normal account exchange. The [Rust client's author-published source](https://docs.rs/crate/annas-archive-api/0.2.0/source/src/client.rs) documents the record endpoint `/db/aarecord_elasticsearch/md5:ID.json` and unified metadata fields; those protocol facts were used, with no third-party implementation copied. Reviewed KOReader archive plugins were not installed.

`enter_token_on_device.py` reads a key without terminal echo and types individual characters into a verified ready password dialog. It neither submits the dialog nor saves a host credential file, and does not pass the complete key as a process argument.

## Installation and rollback

Stop KOReader, copy `koreader/nookarchive.koplugin` into `/sdcard/koreader/plugins/`, and reopen KOReader. To remove it, first clear the token through the menu if its private credential file should also be deleted; then stop KOReader and remove the plugin directory. No system files or root access are required.

## Browser result

Firefox 68.11.0 installed but crashed with `Failed to create EGLConfig!`. An isolated software-rendering profile also crashed and was removed. The stock Android browser returned `ERR_SSL_PROTOCOL_ERROR`. They are not validated alternatives to this plugin. `config/firefox-software-test-prefs.js` preserves the failed experiment, not a browser fix.
