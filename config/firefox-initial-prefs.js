// Compatibility profile only: Firefox 68 has not received security updates since 2020.
// Apply once to a new, stopped profile; do not retain this as user.js.
// Later homepage edits in Firefox must remain effective after restart.
// Never put an account token, password, cookie, or authenticated URL in this file.
user_pref("browser.startup.homepage", "https://annas-archive.gl/");
user_pref("browser.download.folderList", 2);
user_pref("browser.download.dir", "/storage/spsd/NOOK/Books/Downloads");
user_pref("browser.download.useDownloadDir", true);
