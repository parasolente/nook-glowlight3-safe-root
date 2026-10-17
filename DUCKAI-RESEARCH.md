# Standalone Duck.ai research on the NOOK

## User constraints and current result

The requested client must run on the BNRV520 alone over Wi-Fi, without a companion computer, user API key, account login, or user-configured provider/base URL. Duck.ai's anonymous website is the intended service. Its lack of an account requirement is real; authentication by a user-supplied key is not the problem.

**No Duck.ai conversation has been completed on the NOOK. No working Duck.ai chat client was installed. The user subsequently chose an API-based KOReader chat client, which has completed a native device response; see [NOOK-CHAT.md](NOOK-CHAT.md).** The code in `diagnostics/` is a capability check, not a chat implementation. An HTTP 200 bootstrap response must not be described as a successful chat.

## Direct observations

1. A certificate-verified host request to `https://duck.ai/duckchat/v1/status`, with `x-vqd-accept: 1` and no credentials/cookies, returned HTTP 200 JSON and an `x-vqd-hash-1` header. Its value is not published.
2. Decoding that header locally, without executing its program, showed async/await, arrow syntax, and references to browser objects. The web entry bundle separately processes the supplied program in an iframe, hashes the returned client strings, and prepares the conversation request. None of the supplied executable code, proofs, grants, or cookies is included in this repository.
3. Opening a fresh Duck.ai tab on the NOOK's stock browser produced a certificate-trust warning. Viewing its certificate showed `*.duck.ai`, issued by Let's Encrypt YR1 and valid during the test date. The browser reported an untrusted authority. The warning was not bypassed, and system certificates were not changed.
4. The independently written, network-free `diagnostics/web-engine.html` was opened in that stock browser. JavaScript and XMLHttpRequest worked. Arrow syntax, async/await, Promise, and TextEncoder were unavailable. Web Crypto was absent in this local-file context (that last observation alone does not establish its behavior on HTTPS). The user agent reported Chromium 30 on Android 4.4.2.

Firefox’s earlier EGL crash and subsequent tests of Bromite and Opera Mini are documented in [BROWSER-ALTERNATIVES.md](BROWSER-ALTERNATIVES.md). All three were later removed at the user’s request. A generic Android WebView wrapper would inherit an old engine unless it supplied a genuinely different compatibility layer; lowering an APK's minimum SDK would not supply the missing web capabilities.

## What an experimental standalone client would require

A credible prototype would need certificate-verified modern HTTPS, an on-device way to execute the normal web bootstrap's required JavaScript/browser features, and a simple text conversation UI. The service origin can be built in so the user never enters a base URL. Any anonymous session state should stay app-local. No companion server is accepted for this task.

A small native UI, an isolated compatibility layer for the required web code, and complete-response rendering are candidates for investigation. They have not yet been shown to complete the service's bootstrap on this hardware. A simpler interface alone does not prove this works, and unofficial web-protocol changes may break it. Do not fabricate successful replies, disable TLS checks, or present a third-party proxy as a standalone direct client.

Remote-browser projects were researched, but their companion-computer dependency does not satisfy the user's stated constraint and none was installed.

## Reusable diagnostics

```sh
python3 diagnostics/probe_duckai.py
```

This sends one anonymous bootstrap GET with normal HTTPS verification, bounded response size and timeout. It prints only capability facts. It does not execute server JavaScript, send a conversation, accept credentials, retain cookies, or expose raw response values. It was run successfully from the host; Python is not claimed to be installed on the NOOK.

Open `diagnostics/web-engine.html` locally in the browser under test to check its actual feature support. The page sends no network requests and changes no settings. A temporary copy was used on the NOOK and removed after the check.

## Primary references

- [Duck.ai official access information](https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/duck-ai/do-i-need-to-install-anything-to-start-using-duckai).
- The current [Duck.ai website](https://duck.ai/) and its script resources were inspected directly; future bundles and requirements can differ.
- [Android's official WebView documentation](https://developer.android.com/develop/ui/views/layout/webapps/webview).

No user account key, chat content, site challenge value, or browser session is published.
