#!/usr/bin/env python3
"""Inspect the anonymous web bootstrap, without executing its code or sending a chat."""
import base64
import json
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

STATUS_URL = "https://duck.ai/duckchat/v1/status"


def summarize(status, headers, body):
    """Return capability facts only: never tokens, cookies, grants, or executable code."""
    proof = headers.get("x-vqd-hash-1", "")
    result = {
        "http_status": status,
        "account_key_sent": False,
        "proof_header_present": bool(proof),
        "chat_request_sent": False,
        "chat_verified": False,
    }
    try:
        data = json.loads(body)
        result["json_object"] = isinstance(data, dict)
    except (ValueError, UnicodeDecodeError):
        result["json_object"] = False
    if proof and len(proof) <= 262144:
        try:
            program = base64.b64decode(proof, validate=True).decode("utf-8")
            result["proof_uses_async_syntax"] = "async " in program and "await " in program
            result["proof_uses_arrow_syntax"] = "=>" in program
            result["proof_mentions_browser_objects"] = any(
                name in program for name in ("document", "navigator", "window")
            )
        except (ValueError, UnicodeDecodeError):
            result["proof_format_recognized"] = False
    return result


def main():
    # Default HTTPS chain/hostname verification remains enabled. No cookie jar,
    # browser automation, JavaScript evaluation, retries, or custom endpoints.
    request = Request(STATUS_URL, headers={"x-vqd-accept": "1", "Accept": "application/json"})
    try:
        try:
            response = urlopen(request, timeout=20)
        except HTTPError as error:
            response = error
        with response:
            body = response.read(262145)
            if len(body) > 262144:
                raise SystemExit("Response exceeds the diagnostic limit.")
            headers = {key.lower(): value for key, value in response.headers.items()}
            print(json.dumps(summarize(response.status, headers, body), indent=2))
    except (URLError, TimeoutError):
        raise SystemExit("HTTPS bootstrap failed; no chat was sent.") from None


if __name__ == "__main__":
    main()
