// Diagnostic profile only; do not enter account tokens in shared storage.
// Test whether old Fennec can start without its failing EGL configuration.
// This is not a verified fix or a security update.
user_pref("layers.acceleration.disabled", true);
user_pref("layers.acceleration.force-enabled", false);
user_pref("layers.offmainthreadcomposition.enabled", false);
user_pref("browser.startup.homepage", "about:blank");
