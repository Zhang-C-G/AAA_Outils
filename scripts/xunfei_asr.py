import argparse
import asyncio
import base64
import hmac
import hashlib
import json
import os
import sys
import time
from email.utils import formatdate
from pathlib import Path
from urllib.parse import quote

try:
    import websockets
    from websockets.exceptions import InvalidStatus
except Exception as exc:
    print(f"python websockets import failed: {exc}", file=sys.stderr)
    sys.exit(2)


def build_auth_url(api_key: str, api_secret: str) -> str:
    host = "iat-api.xfyun.cn"
    path = "/v2/iat"
    date = formatdate(timeval=None, localtime=False, usegmt=True)
    signature_origin = f"host: {host}\ndate: {date}\nGET {path} HTTP/1.1"
    digest = hmac.new(
        api_secret.encode("utf-8"),
        signature_origin.encode("utf-8"),
        hashlib.sha256,
    ).digest()
    signature = base64.b64encode(digest).decode("utf-8")
    authorization_origin = (
        f'api_key="{api_key}", algorithm="hmac-sha256", '
        f'headers="host date request-line", signature="{signature}"'
    )
    authorization = base64.b64encode(authorization_origin.encode("utf-8")).decode("utf-8")
    return (
        f"wss://{host}{path}"
        f"?authorization={quote(authorization, safe='')}"
        f"&date={quote(date, safe='')}"
        f"&host={host}"
    )


def extract_text(payload: dict) -> str:
    result = payload.get("data", {}).get("result", {})
    words = []
    for ws in result.get("ws", []) or []:
        for cw in ws.get("cw", []) or []:
            word = str(cw.get("w", "")).strip()
            if word:
                words.append(word)
    return "".join(words)


async def transcribe(audio_path: Path, app_id: str, api_key: str, api_secret: str) -> str:
    url = build_auth_url(api_key, api_secret)
    audio_bytes = audio_path.read_bytes()
    chunk_size = 1280
    segments: list[str] = []

    async with websockets.connect(url, max_size=None, ping_interval=None) as ws:
        if audio_bytes:
            offset = 0
            first = True
            while offset < len(audio_bytes):
                chunk = audio_bytes[offset: offset + chunk_size]
                status = 0 if first else (2 if offset + len(chunk) >= len(audio_bytes) else 1)
                payload = {
                    "data": {
                        "status": status,
                        "format": "audio/L16;rate=16000",
                        "encoding": "raw",
                        "audio": base64.b64encode(chunk).decode("utf-8"),
                    }
                }
                if first:
                    payload["common"] = {"app_id": app_id}
                    payload["business"] = {
                        "language": "zh_cn",
                        "domain": "iat",
                        "accent": "mandarin",
                        "vad_eos": 10000,
                    }
                await ws.send(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
                offset += len(chunk)
                first = False
                await asyncio.sleep(0.04)
        else:
            await ws.send(
                json.dumps(
                    {
                        "common": {"app_id": app_id},
                        "business": {
                            "language": "zh_cn",
                            "domain": "iat",
                            "accent": "mandarin",
                            "vad_eos": 10000,
                        },
                        "data": {
                            "status": 2,
                            "format": "audio/L16;rate=16000",
                            "encoding": "raw",
                            "audio": "",
                        },
                    },
                    ensure_ascii=False,
                    separators=(",", ":"),
                )
            )

        while True:
            raw = await ws.recv()
            payload = json.loads(raw)
            code = int(payload.get("code", 0) or 0)
            if code != 0:
                message = str(payload.get("message", "")).strip() or "xunfei websocket error"
                raise RuntimeError(f"xunfei asr failed ({code}): {message}")
            text = extract_text(payload)
            if text and (not segments or segments[-1] != text):
                segments.append(text)
            if int(payload.get("data", {}).get("status", 1) or 1) == 2:
                break

    return "".join(segments).strip()


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")

    parser = argparse.ArgumentParser()
    parser.add_argument("--audio", required=True)
    parser.add_argument("--app-id", default=os.environ.get("XUNFEI_APP_ID", ""))
    parser.add_argument("--api-key", default=os.environ.get("XUNFEI_API_KEY", ""))
    parser.add_argument("--api-secret", default=os.environ.get("XUNFEI_API_SECRET", ""))
    args = parser.parse_args()

    if not args.app_id or not args.api_key or not args.api_secret:
        print("xunfei websocket credentials missing", file=sys.stderr)
        return 2

    audio_path = Path(args.audio)
    if not audio_path.exists():
        print("xunfei audio file missing", file=sys.stderr)
        return 2

    try:
        text = asyncio.run(transcribe(audio_path, args.app_id, args.api_key, args.api_secret))
    except InvalidStatus as exc:
        body = ""
        response = getattr(exc, "response", None)
        if response is not None:
            raw_body = getattr(response, "body", b"") or b""
            try:
                body = raw_body.decode("utf-8", errors="ignore").strip()
            except Exception:
                body = ""
        detail = body or str(exc)
        print(detail, file=sys.stderr)
        return 1
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
