#!/usr/bin/env python3
"""Local mock server for TKD MVP harness testing."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import pathlib
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class TKDMockHandler(BaseHTTPRequestHandler):
    server_version = "TKDMock/0.1"

    def _write_json(self, status: int, body: dict) -> None:
        payload = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def _log_record(self, path: str, body: dict) -> str:
        request_id = f"req_{uuid.uuid4().hex[:20]}"
        log_path = pathlib.Path(self.server.log_file)  # type: ignore[attr-defined]
        log_path.parent.mkdir(parents=True, exist_ok=True)
        record = {
            "received_at": dt.datetime.now(dt.timezone.utc).isoformat(),
            "request_id": request_id,
            "path": path,
            "body": body,
        }
        with log_path.open("a", encoding="utf-8") as log_file:
            log_file.write(json.dumps(record) + "\n")
        return request_id

    def do_GET(self) -> None:  # noqa: N802 (required by BaseHTTPRequestHandler)
        if self.path != "/healthz":
            self._write_json(404, {"error": "not_found"})
            return
        self._write_json(
            200,
            {
                "ok": True,
                "service": "tkd-mock",
                "time": dt.datetime.now(dt.timezone.utc).isoformat(),
            },
        )

    def do_POST(self) -> None:  # noqa: N802
        if self.path not in ("/v1/agents/events", "/v1/knowledge/assertions"):
            self._write_json(404, {"error": "not_found"})
            return

        body_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(body_length) if body_length else b"{}"
        try:
            body = json.loads(raw_body.decode("utf-8"))
        except json.JSONDecodeError:
            self._write_json(400, {"error": "invalid_json"})
            return

        request_id = self._log_record(self.path, body)
        self._write_json(
            202,
            {
                "accepted": True,
                "request_id": request_id,
                "path": self.path,
            },
        )

    def log_message(self, *_args) -> None:  # noqa: D401
        # Keep output clean for scripted smoke tests.
        return


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a local TKD mock server")
    parser.add_argument("--host", default="127.0.0.1", help="Bind host")
    parser.add_argument("--port", type=int, default=8787, help="Bind port")
    parser.add_argument(
        "--log-file",
        default="/tmp/tkd-mock-events.jsonl",
        help="JSONL file to append incoming requests",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    server = ThreadingHTTPServer((args.host, args.port), TKDMockHandler)
    server.log_file = args.log_file  # type: ignore[attr-defined]
    print(
        f"tkd-mock listening on http://{args.host}:{args.port} (log: {args.log_file})",
        flush=True,
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
