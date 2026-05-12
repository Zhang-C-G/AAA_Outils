import argparse
import asyncio
import base64
import contextlib
import hashlib
import hmac
import json
import os
import time
import sys
from email.utils import formatdate
from pathlib import Path
from urllib.parse import quote

try:
    import websockets
    from websockets.exceptions import InvalidStatus
except Exception as exc:
    print(f"python websockets import failed: {exc}", file=sys.stderr)
    sys.exit(2)

try:
    import sounddevice as sd
except Exception:
    sd = None


CHUNK_SIZE = 640


class StatusReporter:
    def __init__(self, status_path: str, bootstrap_metrics: dict[str, int] | None = None):
        self.status_path = status_path
        self.started_at = time.perf_counter()
        self.metrics: dict[str, int] = {}
        if isinstance(bootstrap_metrics, dict):
            for key, value in bootstrap_metrics.items():
                try:
                    self.metrics[str(key)] = int(value)
                except Exception:
                    continue

    def elapsed_ms(self) -> int:
        return int((time.perf_counter() - self.started_at) * 1000)

    def mark(self, name: str) -> int:
        value = self.elapsed_ms()
        self.metrics[f"{name}_ms"] = value
        return value

    def update(self, stage: str, detail: str = "", mark: str | None = None, extra_metrics: dict[str, int] | None = None) -> None:
        if not self.status_path:
            return
        if mark:
            self.mark(mark)
        if isinstance(extra_metrics, dict):
            for key, value in extra_metrics.items():
                try:
                    self.metrics[str(key)] = int(value)
                except Exception:
                    continue

        lines = [f"stage={stage}"]
        if detail:
            lines.append(f"detail={detail}")
        for key in sorted(self.metrics):
            lines.append(f"metric_{key}={self.metrics[key]}")
        Path(self.status_path).write_text("\n".join(lines), encoding="utf-8")


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


def merge_segments(slots: list[str], payload: dict) -> str:
    result = payload.get("data", {}).get("result", {}) or {}
    text = extract_text(payload)
    if not text:
        return "".join(slots).strip()

    pgs = str(result.get("pgs", "") or "").strip().lower()
    rg = result.get("rg", None)

    if pgs == "rpl" and isinstance(rg, list) and len(rg) == 2:
        try:
            start = max(0, int(rg[0]) - 1)
            end = max(start, int(rg[1]) - 1)
            while len(slots) <= end:
                slots.append("")
            slots[start] = text
            for idx in range(start + 1, end + 1):
                slots[idx] = ""
            return "".join(slots).strip()
        except Exception:
            pass

    slots.append(text)
    return "".join(slots).strip()


def write_output(path: str, text: str) -> None:
    if not path:
        return
    Path(path).write_text(text, encoding="utf-8")


async def send_payload(ws, payload: dict) -> None:
    await ws.send(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))


def build_audio_payload(chunk: bytes, status: int, app_id: str, include_headers: bool) -> dict:
    payload = {
        "data": {
            "status": status,
            "format": "audio/L16;rate=16000",
            "encoding": "raw",
            "audio": base64.b64encode(chunk).decode("utf-8"),
        }
    }
    if include_headers:
        payload["common"] = {"app_id": app_id}
        payload["business"] = {
            "language": "zh_cn",
            "domain": "iat",
            "accent": "mandarin",
            "vad_eos": 5000,
            "dwa": "wpgs",
        }
    return payload


async def transcribe_file(
    audio_path: Path,
    app_id: str,
    api_key: str,
    api_secret: str,
    status_path: str = "",
) -> str:
    url = build_auth_url(api_key, api_secret)
    reporter = StatusReporter(status_path)
    reporter.update("starting", "audio_file_loading")
    audio_bytes = audio_path.read_bytes()
    reporter.update("connecting", "websocket_connect_begin", mark="audio_file_loaded")
    slots: list[str] = []
    last_text = ""
    first_audio_sent = False
    first_result_received = False
    first_nonempty_text_received = False

    async with websockets.connect(url, max_size=None, ping_interval=None) as ws:
        reporter.update("streaming", "websocket_connected", mark="websocket_connected")
        if audio_bytes:
            offset = 0
            first = True
            while offset < len(audio_bytes):
                chunk = audio_bytes[offset : offset + CHUNK_SIZE]
                status = 0 if first else (2 if offset + len(chunk) >= len(audio_bytes) else 1)
                payload = build_audio_payload(chunk, status, app_id, first)
                await send_payload(ws, payload)
                if not first_audio_sent:
                    first_audio_sent = True
                    reporter.update("streaming", "first_audio_sent", mark="first_audio_sent")
                offset += len(chunk)
                first = False
            reporter.update("streaming", "final_payload_sent", mark="final_payload_sent")
        else:
            await send_payload(
                ws,
                {
                    "common": {"app_id": app_id},
                    "business": {
                        "language": "zh_cn",
                        "domain": "iat",
                        "accent": "mandarin",
                        "vad_eos": 5000,
                        "dwa": "wpgs",
                    },
                    "data": {
                        "status": 2,
                        "format": "audio/L16;rate=16000",
                        "encoding": "raw",
                        "audio": "",
                    },
                },
            )
            reporter.update("streaming", "final_payload_sent", mark="final_payload_sent")

        while True:
            raw = await ws.recv()
            if not first_result_received:
                first_result_received = True
                reporter.update("streaming", "first_result_received", mark="first_result_received")
            payload = json.loads(raw)
            code = int(payload.get("code", 0) or 0)
            if code != 0:
                message = str(payload.get("message", "")).strip() or "xunfei websocket error"
                raise RuntimeError(f"xunfei asr failed ({code}): {message}")
            merged = merge_segments(slots, payload)
            if merged:
                last_text = merged
                if not first_nonempty_text_received:
                    first_nonempty_text_received = True
                    reporter.update("streaming", "first_nonempty_text_received", mark="first_nonempty_text_received")
            if int(payload.get("data", {}).get("status", 1) or 1) == 2:
                reporter.update("done", "final_result_received", mark="final_result_received")
                break

    reporter.update("done", "completed", mark="completed")
    return last_text.strip()


async def transcribe_live(
    device_name: str,
    stop_path: str,
    transcript_path: str,
    status_path: str,
    app_id: str,
    api_key: str,
    api_secret: str,
    bootstrap_metrics: dict[str, int] | None = None,
) -> str:
    if sd is not None:
        try:
            return await transcribe_live_sounddevice(
                device_name=device_name,
                stop_path=stop_path,
                transcript_path=transcript_path,
                status_path=status_path,
                app_id=app_id,
                api_key=api_key,
                api_secret=api_secret,
                bootstrap_metrics=bootstrap_metrics,
            )
        except Exception:
            # Fall back to ffmpeg/dshow when sounddevice is unavailable for the selected device.
            pass

    return await transcribe_live_ffmpeg(
        device_name=device_name,
        stop_path=stop_path,
        transcript_path=transcript_path,
        status_path=status_path,
        app_id=app_id,
        api_key=api_key,
        api_secret=api_secret,
        bootstrap_metrics=bootstrap_metrics,
    )


def _normalize_device_name(name: str) -> str:
    return "".join(ch.lower() for ch in (name or "") if ch.isalnum())


def _resolve_sounddevice_input(device_name: str) -> int | None:
    if sd is None:
        return None

    target = _normalize_device_name(device_name)
    devices = sd.query_devices()

    if target:
        for idx, dev in enumerate(devices):
            if int(dev.get("max_input_channels", 0) or 0) <= 0:
                continue
            name = str(dev.get("name", "") or "")
            normalized = _normalize_device_name(name)
            if normalized == target or target in normalized or normalized in target:
                return idx

    try:
        default_input = sd.default.device[0]
        if default_input is not None and int(default_input) >= 0:
            return int(default_input)
    except Exception:
        pass

    for idx, dev in enumerate(devices):
        if int(dev.get("max_input_channels", 0) or 0) > 0:
            return idx
    return None


async def transcribe_live_sounddevice(
    device_name: str,
    stop_path: str,
    transcript_path: str,
    status_path: str,
    app_id: str,
    api_key: str,
    api_secret: str,
    bootstrap_metrics: dict[str, int] | None = None,
) -> str:
    if sd is None:
        raise RuntimeError("sounddevice unavailable")

    url = build_auth_url(api_key, api_secret)
    stop_file = Path(stop_path) if stop_path else None
    stop_requested = False
    send_done = asyncio.Event()
    slots: list[str] = []
    last_text = ""
    loop = asyncio.get_running_loop()
    audio_queue: asyncio.Queue[bytes | None] = asyncio.Queue()
    device_index = _resolve_sounddevice_input(device_name)
    if device_index is None:
        raise RuntimeError("no sounddevice input device available")

    reporter = StatusReporter(status_path, bootstrap_metrics)
    reporter.update("starting", "python_worker_booting", mark="python_worker_boot")
    first_audio_captured = False
    first_audio_sent = False
    first_result_received = False
    first_nonempty_text_received = False

    def audio_callback(indata, frames, time_info, status) -> None:
        nonlocal first_audio_captured
        if status:
            pass
        if not first_audio_captured:
            first_audio_captured = True
            reporter.update("listening", "first_audio_captured", mark="first_audio_captured")
        try:
            loop.call_soon_threadsafe(audio_queue.put_nowait, bytes(indata))
        except RuntimeError:
            pass

    async def stop_watcher() -> None:
        nonlocal stop_requested
        if stop_file is None:
            return
        while not stop_requested and not send_done.is_set():
            if stop_file.exists():
                stop_requested = True
                reporter.update("finalizing", "stop_requested", mark="stop_requested")
                try:
                    loop.call_soon_threadsafe(audio_queue.put_nowait, None)
                except RuntimeError:
                    pass
                return
            await asyncio.sleep(0.02)

    async def stream_audio(ws) -> None:
        nonlocal stop_requested, first_audio_sent
        first = True
        try:
            reporter.update("capturing", "capturing_audio", mark="stream_audio_started")
            while True:
                chunk = await audio_queue.get()
                if chunk is None:
                    break
                if not chunk:
                    continue
                if not first_audio_sent:
                    first_audio_sent = True
                    reporter.update("capturing", "first_audio_sent", mark="first_audio_sent")
                payload = build_audio_payload(chunk, 0 if first else 1, app_id, first)
                await send_payload(ws, payload)
                first = False

            final_payload = build_audio_payload(b"", 2, app_id, first)
            if first:
                final_payload["common"] = {"app_id": app_id}
                final_payload["business"] = {
                    "language": "zh_cn",
                    "domain": "iat",
                    "accent": "mandarin",
                    "vad_eos": 5000,
                    "dwa": "wpgs",
                }
            await send_payload(ws, final_payload)
            reporter.update("recognizing", "waiting_final_result", mark="final_payload_sent")
        finally:
            stop_requested = True
            send_done.set()

    async def receive_results(ws) -> None:
        nonlocal last_text, first_result_received, first_nonempty_text_received
        while True:
            raw = await ws.recv()
            if not first_result_received:
                first_result_received = True
                reporter.update("streaming", "first_result_received", mark="first_result_received")
            payload = json.loads(raw)
            code = int(payload.get("code", 0) or 0)
            if code != 0:
                message = str(payload.get("message", "")).strip() or "xunfei websocket error"
                raise RuntimeError(f"xunfei asr failed ({code}): {message}")
            merged = merge_segments(slots, payload)
            if merged and merged != last_text:
                if not first_nonempty_text_received:
                    first_nonempty_text_received = True
                    reporter.update("streaming", "first_nonempty_text_received", mark="first_nonempty_text_received")
                last_text = merged
                write_output(transcript_path, last_text)
                reporter.update("streaming", "streaming_text")
            if int(payload.get("data", {}).get("status", 1) or 1) == 2 and send_done.is_set():
                reporter.update("recognizing", "final_result_received", mark="final_result_received")
                break

    reporter.update("starting", "connecting_service", mark="websocket_connect_begin")
    async with websockets.connect(url, max_size=None, ping_interval=None) as ws:
        reporter.update("connected", "service_connected", mark="websocket_connected")
        stream = sd.RawInputStream(
            samplerate=16000,
            blocksize=CHUNK_SIZE // 2,
            device=device_index,
            channels=1,
            dtype="int16",
            callback=audio_callback,
        )
        watcher_task = asyncio.create_task(stop_watcher())
        send_task = asyncio.create_task(stream_audio(ws))
        recv_task = asyncio.create_task(receive_results(ws))
        try:
            stream.start()
            reporter.update("listening", "audio_stream_ready", mark="audio_stream_ready")
            done, pending = await asyncio.wait(
                {watcher_task, send_task, recv_task},
                return_when=asyncio.FIRST_EXCEPTION,
            )
            for task in done:
                exc = task.exception()
                if exc is not None:
                    raise exc
            await send_task
            await recv_task
            watcher_task.cancel()
            with contextlib.suppress(Exception):
                await watcher_task
        finally:
            with contextlib.suppress(Exception):
                stream.stop()
            with contextlib.suppress(Exception):
                stream.close()
            if not send_done.is_set():
                send_done.set()

    result = last_text.strip()
    if result:
        write_output(transcript_path, result)
        reporter.update("completed", "completed_with_text", mark="completed")
    elif transcript_path:
        write_output(transcript_path, "")
        reporter.update("completed", "completed_empty", mark="completed")
    return result


async def transcribe_live_ffmpeg(
    device_name: str,
    stop_path: str,
    transcript_path: str,
    status_path: str,
    app_id: str,
    api_key: str,
    api_secret: str,
    bootstrap_metrics: dict[str, int] | None = None,
) -> str:
    url = build_auth_url(api_key, api_secret)
    ffmpeg = await asyncio.create_subprocess_exec(
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-f",
        "dshow",
        "-i",
        f"audio={device_name}",
        "-ac",
        "1",
        "-ar",
        "16000",
        "-f",
        "s16le",
        "-",
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )

    slots: list[str] = []
    last_text = ""
    stop_file = Path(stop_path) if stop_path else None
    stop_requested = False
    audio_started = False
    send_done = asyncio.Event()

    reporter = StatusReporter(status_path, bootstrap_metrics)
    reporter.update("starting", "python_worker_booting", mark="python_worker_boot")
    first_audio_sent = False
    first_result_received = False
    first_nonempty_text_received = False

    async def stop_watcher() -> None:
        nonlocal stop_requested
        if stop_file is None:
            return
        while not stop_requested and not send_done.is_set():
            if stop_file.exists():
                stop_requested = True
                reporter.update("finalizing", "stop_requested", mark="stop_requested")
                try:
                    if ffmpeg.stdin and not ffmpeg.stdin.is_closing():
                        ffmpeg.stdin.write(b"q\n")
                        await ffmpeg.stdin.drain()
                except Exception:
                    pass
                return
            await asyncio.sleep(0.03)

    async def stream_audio(ws) -> None:
        nonlocal audio_started, stop_requested, first_audio_sent
        first = True
        try:
            reporter.update("capturing", "capturing_audio", mark="stream_audio_started")
            while True:
                if ffmpeg.stdout is None:
                    break
                chunk = await ffmpeg.stdout.read(CHUNK_SIZE)
                if not chunk:
                    break
                if not audio_started:
                    reporter.update("listening", "first_audio_captured", mark="first_audio_captured")
                if not first_audio_sent:
                    first_audio_sent = True
                    reporter.update("capturing", "first_audio_sent", mark="first_audio_sent")
                payload = build_audio_payload(chunk, 0 if first else 1, app_id, first)
                await send_payload(ws, payload)
                audio_started = True
                first = False
            final_payload = build_audio_payload(b"", 2, app_id, first)
            if first:
                final_payload["common"] = {"app_id": app_id}
                final_payload["business"] = {
                    "language": "zh_cn",
                    "domain": "iat",
                    "accent": "mandarin",
                    "vad_eos": 5000,
                    "dwa": "wpgs",
                }
            await send_payload(ws, final_payload)
            reporter.update("recognizing", "waiting_final_result", mark="final_payload_sent")
        finally:
            stop_requested = True
            send_done.set()

    async def receive_results(ws) -> None:
        nonlocal last_text, first_result_received, first_nonempty_text_received
        while True:
            raw = await ws.recv()
            if not first_result_received:
                first_result_received = True
                reporter.update("streaming", "first_result_received", mark="first_result_received")
            payload = json.loads(raw)
            code = int(payload.get("code", 0) or 0)
            if code != 0:
                message = str(payload.get("message", "")).strip() or "xunfei websocket error"
                raise RuntimeError(f"xunfei asr failed ({code}): {message}")
            merged = merge_segments(slots, payload)
            if merged and merged != last_text:
                if not first_nonempty_text_received:
                    first_nonempty_text_received = True
                    reporter.update("streaming", "first_nonempty_text_received", mark="first_nonempty_text_received")
                last_text = merged
                write_output(transcript_path, last_text)
                reporter.update("streaming", "streaming_text")
            if int(payload.get("data", {}).get("status", 1) or 1) == 2 and send_done.is_set():
                reporter.update("recognizing", "final_result_received", mark="final_result_received")
                break

    try:
        reporter.update("starting", "connecting_service", mark="websocket_connect_begin")
        async with websockets.connect(url, max_size=None, ping_interval=None) as ws:
            reporter.update("connected", "service_connected", mark="websocket_connected")
            watcher_task = asyncio.create_task(stop_watcher())
            send_task = asyncio.create_task(stream_audio(ws))
            recv_task = asyncio.create_task(receive_results(ws))
            done, pending = await asyncio.wait(
                {watcher_task, send_task, recv_task},
                return_when=asyncio.FIRST_EXCEPTION,
            )
            for task in done:
                exc = task.exception()
                if exc is not None:
                    raise exc
            await send_task
            await recv_task
            watcher_task.cancel()
            with contextlib.suppress(Exception):
                await watcher_task
    finally:
        if ffmpeg.stdin:
            with contextlib.suppress(Exception):
                ffmpeg.stdin.close()
        with contextlib.suppress(Exception):
            await asyncio.wait_for(ffmpeg.wait(), timeout=3)
        if ffmpeg.returncode is None:
            ffmpeg.kill()
            with contextlib.suppress(Exception):
                await ffmpeg.wait()

    result = last_text.strip()
    if result:
        write_output(transcript_path, result)
        reporter.update("completed", "completed_with_text", mark="completed")
    elif transcript_path:
        write_output(transcript_path, "")
        reporter.update("completed", "completed_empty", mark="completed")
    return result


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")

    parser = argparse.ArgumentParser()
    parser.add_argument("--audio", default="")
    parser.add_argument("--device-name", default="")
    parser.add_argument("--stop-path", default="")
    parser.add_argument("--transcript-path", default="")
    parser.add_argument("--status-path", default="")
    parser.add_argument("--app-id", default=os.environ.get("XUNFEI_APP_ID", ""))
    parser.add_argument("--api-key", default=os.environ.get("XUNFEI_API_KEY", ""))
    parser.add_argument("--api-secret", default=os.environ.get("XUNFEI_API_SECRET", ""))
    parser.add_argument("--output", default="")
    parser.add_argument("--error-output", default="")
    parser.add_argument("--bootstrap-metrics", default="")
    args = parser.parse_args()

    bootstrap_metrics: dict[str, int] = {}
    if args.bootstrap_metrics:
        with contextlib.suppress(Exception):
            raw_metrics = json.loads(args.bootstrap_metrics)
            if isinstance(raw_metrics, dict):
                for key, value in raw_metrics.items():
                    bootstrap_metrics[str(key)] = int(value)

    if not args.app_id or not args.api_key or not args.api_secret:
        message = "xunfei websocket credentials missing"
        write_output(args.error_output, message)
        print(message, file=sys.stderr)
        return 2

    try:
        if args.device_name:
            text = asyncio.run(
                transcribe_live(
                    device_name=args.device_name,
                    stop_path=args.stop_path,
                    transcript_path=args.transcript_path,
                    status_path=args.status_path,
                    app_id=args.app_id,
                    api_key=args.api_key,
                    api_secret=args.api_secret,
                    bootstrap_metrics=bootstrap_metrics,
                )
            )
        else:
            if not args.audio:
                message = "xunfei audio file missing"
                write_output(args.error_output, message)
                print(message, file=sys.stderr)
                return 2
            audio_path = Path(args.audio)
            if not audio_path.exists():
                message = "xunfei audio file missing"
                write_output(args.error_output, message)
                print(message, file=sys.stderr)
                return 2
            text = asyncio.run(
                transcribe_file(
                    audio_path,
                    args.app_id,
                    args.api_key,
                    args.api_secret,
                    status_path=args.status_path,
                )
            )
    except InvalidStatus as exc:
        body = ""
        response = getattr(exc, "response", None)
        if response is not None:
            raw_body = getattr(response, "body", b"") or b""
            with contextlib.suppress(Exception):
                body = raw_body.decode("utf-8", errors="ignore").strip()
        detail = body or str(exc)
        write_output(args.error_output, detail)
        print(detail, file=sys.stderr)
        return 1
    except Exception as exc:
        detail = str(exc)
        write_output(args.error_output, detail)
        print(detail, file=sys.stderr)
        return 1

    write_output(args.output, text)
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
