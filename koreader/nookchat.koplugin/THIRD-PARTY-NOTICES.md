# Certificate bundle

`cacert.pem` is Mozilla's public root certificate data, converted and distributed by curl under MPL 2.0. It is not covered by this repository's MIT license.

- Download: https://curl.se/ca/cacert.pem
- Source and license information: https://curl.se/docs/caextract.html
- Original source: https://github.com/mozilla-firefox/firefox/blob/release/security/nss/lib/ckfw/builtins/certdata.txt
- MPL 2.0: https://www.mozilla.org/MPL/2.0/
- Mozilla data date: 2026-09-25
- Retrieved: 2026-10-16
- File SHA-256: `a41b5d356aea97a529fe27e0f7316d2f9d946d75927476cf9cf1b90637d00505`

The downloaded file matched curl's separately published SHA-256. This bundle is used by the plugin only; no Android system certificate store is changed. Certificate data will need refreshing as trust stores evolve.
