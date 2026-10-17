# KOReader AI chat on the NOOK

The independent `nookchat.koplugin` supplies a text conversation UI and selected-text questions without a browser, permanent root, or companion computer. It uses an OpenAI-compatible Chat Completions endpoint. This is an API client, not a Duck.ai client.

## Configuration and use

The tested configuration is base URL `https://tokenharbor.ai/v1` and model `deepseek-v4-flash`. The user supplied a key privately; no actual key is included here. Open KOReader’s top Search menu (magnifying glass), then **Asistente IA → Conversación / Preguntar**. The item may be on a later menu page. Use **Preguntar** to enter a message and **Nueva charla** to clear the current conversation.

Select text in a book and choose **Preguntar a IA** to ask about that excerpt. The question is editable before sending. Only explicit questions, recent conversation pairs and an explicitly selected excerpt are sent, never the entire current book automatically. The dialog states that requests may consume API credit.

**Asistente IA → Configuración** edits the HTTPS base URL, exact model ID, and masked API key. Changing the base URL clears the stored key; changing configuration clears the in-memory conversation. Blank key input deletes the saved key value. It does not modify Android certificates or networking settings.

## Credentials and transport

Configuration, including the key bound to its base URL, is stored only at `android.dir/nookchat-private.json` in the Android app’s private data directory. Writes use a mode-0600 temporary file and atomic rename. The key is not stored in shared settings, the public plugin source, an exported book, or a request URL. Plugin code does not log raw API objects or errors. Uninstalling KOReader removes its private configuration.

TLS chain verification uses the bundled Mozilla/curl CA data and an additional DNS SAN check before sending Authorization. Only HTTPS URLs without embedded credentials, query strings or fragments are accepted. Redirects and automatic POST retries are disabled. HTTP error bodies are not displayed, since servers can echo credentials.

Responses are requested as complete JSON (`stream: false`) to avoid repeated screen refreshes. A subprocess keeps the UI responsive; tapping the waiting overlay cancels local waiting and terminates the subprocess. Cancellation cannot recall a request the provider already received and may not avoid billing. No automatic request is sent at normal startup.

Conversations remain in the plugin instance’s memory, not local history files. Successful pairs are retained up to six turns; transmitted recent context is further bounded to 24,000 bytes. A request accepts up to 12,000 bytes, an explicitly selected excerpt up to 8,000, a response body up to 1 MiB, and answer text up to 48,000 bytes. Output defaults to 1,024 tokens and reports a length cutoff. The API provider’s own retention/privacy rules still apply.

## Validation

- Host HTTPS call: HTTP 200, the requested model, and a short text answer.
- Actual BNRV520/Android 4.4.2 call using KOReader’s LuaSocket/LuaSec runtime: a 262-byte Spanish answer was received and visibly displayed in the native KOReader text viewer. This was a real model response, not a fixture.
- The app-private file was reread inside the app and its permissions were verified as `rw-------`. Initial provisioning used a one-use loopback socket through an ADB USB forward; the key never needed a shared-storage staging file. The temporary bridge and forwarding rule were removed afterward.
- After closing and reopening KOReader, **Preguntar a IA** appeared in the normal highlight menu. An editable question about a selected word from the repository’s own EPUB fixture was submitted through the normal UI, and a real Spanish explanation was visibly displayed. This also verified the saved key across app restarts.
- Final full readback confirmed that all six installed plugin files exactly match the published source, with no provisioning bridge left. Browser packages were absent, ADB remained unprivileged, and USB stay-awake was zero. The temporary host credential file was deleted after provisioning.
- The Spanish offline dictionary also displayed a real definition via touch during that test.
- Lua syntax checks and `tests/test_nookchat.lua` cover endpoint/header validation, context bounds, malformed replies, sanitized errors, and the actual HTTP request boundary (bearer header, no redirect, no retry).

Developer diagnostic `diagnostics/nookchat_device_test.lua` is intentionally outside the plugin. It is only invoked from a temporary local test copy with a fresh random nonce, binds to loopback, accepts a single connection, provisions app-private data and makes one small live test call. It is not an installed background service. Never commit credentials or generated provisioning nonces.

## Installation

Copy the complete `koreader/nookchat.koplugin/` directory into `/sdcard/koreader/plugins/` while KOReader is closed, then restart KOReader. Enter your own key through the masked configuration dialog. The input button for a question is **Enviar**. A failed/cancelled submitted question can be reopened from **Reabrir pregunta pendiente** without automatic resending. No changes to the firmware, system WebView, bootloader or NOOK app are required.

Primary protocol references: [Token Harbor Chat APIs](https://tokenharbor.ai/docs/api/curl) and [the configured model’s exact ID](https://tokenharbor.ai/models/deepseek-v4-flash). API availability, model behavior and pricing may change. The CA bundle has separate attribution in the plugin’s THIRD-PARTY-NOTICES.md.
