#!/usr/bin/env python3
"""Local mock server for TKD MVP harness testing.

This server intentionally models a small subset of TKD behavior:
- append-only provenance event capture
- scoped assertions (`repo` vs `org`)
- immutable assertion revisions
- simple current/timeline lookup endpoints
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import pathlib
import threading
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import parse_qs, urlparse


DEFAULT_STATE: dict[str, Any] = {
    "assertions": {},
    "assertion_revisions": {},
    "events": [],
    "promotions": [],
}


def now_utc() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def random_id(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex[:20]}"


def slugify(value: str) -> str:
    cleaned = []
    for ch in value.lower().strip():
        if ch.isalnum():
            cleaned.append(ch)
        elif ch in (" ", "/", ".", "_", "-"):
            cleaned.append("-")
    slug = "".join(cleaned).strip("-")
    while "--" in slug:
        slug = slug.replace("--", "-")
    return slug or "unknown"


def load_state(state_file: pathlib.Path) -> dict[str, Any]:
    if not state_file.exists():
        return json.loads(json.dumps(DEFAULT_STATE))
    with state_file.open("r", encoding="utf-8") as file:
        raw = json.load(file)
    state = json.loads(json.dumps(DEFAULT_STATE))
    state.update(raw)
    for key in DEFAULT_STATE:
        state.setdefault(key, json.loads(json.dumps(DEFAULT_STATE[key])))
    return state


def save_state(state_file: pathlib.Path, state: dict[str, Any]) -> None:
    state_file.parent.mkdir(parents=True, exist_ok=True)
    with state_file.open("w", encoding="utf-8") as file:
        json.dump(state, file, indent=2)
        file.write("\n")


def assertion_identity(
    scope: str,
    org_id: str,
    project_id: str,
    repo_id: str,
    knowledge_key: str,
    explicit_assertion_id: str,
) -> str:
    if explicit_assertion_id:
        return explicit_assertion_id
    if scope == "org":
        return f"ast_org_{slugify(org_id)}_{slugify(knowledge_key)}"
    return f"ast_repo_{slugify(project_id)}_{slugify(repo_id)}_{slugify(knowledge_key)}"


class TKDMockHandler(BaseHTTPRequestHandler):
    server_version = "TKDMock/0.2"

    def _write_json(self, status: int, body: dict[str, Any]) -> None:
        payload = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def _request_json(self) -> dict[str, Any] | None:
        body_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(body_length) if body_length else b"{}"
        try:
            return json.loads(raw_body.decode("utf-8"))
        except json.JSONDecodeError:
            self._write_json(400, {"error": "invalid_json"})
            return None

    def _log_record(self, path: str, body: dict[str, Any], request_id: str) -> None:
        log_path = pathlib.Path(self.server.log_file)  # type: ignore[attr-defined]
        log_path.parent.mkdir(parents=True, exist_ok=True)
        record = {
            "received_at": now_utc(),
            "request_id": request_id,
            "path": path,
            "body": body,
        }
        with log_path.open("a", encoding="utf-8") as log_file:
            log_file.write(json.dumps(record) + "\n")

    def _with_state_lock(self):
        return self.server.state_lock  # type: ignore[attr-defined]

    def _state(self) -> dict[str, Any]:
        return self.server.state  # type: ignore[attr-defined]

    def _state_file(self) -> pathlib.Path:
        return pathlib.Path(self.server.state_file)  # type: ignore[attr-defined]

    def _persist_state(self) -> None:
        save_state(self._state_file(), self._state())

    def _build_current_records(self, filtered_assertions: list[dict[str, Any]]) -> list[dict[str, Any]]:
        revisions = self._state().get("assertion_revisions", {})
        records: list[dict[str, Any]] = []
        for assertion in filtered_assertions:
            current_revision_id = assertion.get("current_revision_id", "")
            current_revision = revisions.get(current_revision_id, {})
            records.append(
                {
                    "assertion": assertion,
                    "current_revision": current_revision,
                }
            )
        return records

    def _filter_assertions(self, query: dict[str, list[str]]) -> list[dict[str, Any]]:
        knowledge_key = query.get("knowledge_key", [""])[0]
        scope = query.get("scope", [""])[0]
        project_id = query.get("project_id", [""])[0]
        repo_id = query.get("repo_id", [""])[0]

        assertions = list(self._state().get("assertions", {}).values())
        filtered: list[dict[str, Any]] = []
        for assertion in assertions:
            if knowledge_key and assertion.get("knowledge_key") != knowledge_key:
                continue
            if scope and assertion.get("scope") != scope:
                continue
            if project_id and assertion.get("project_id") != project_id:
                continue
            if repo_id and assertion.get("repo_id") != repo_id:
                continue
            filtered.append(assertion)
        filtered.sort(key=lambda item: item.get("updated_at", ""), reverse=True)
        return filtered

    def _handle_health(self) -> None:
        state = self._state()
        self._write_json(
            200,
            {
                "ok": True,
                "service": "tkd-mock",
                "time": now_utc(),
                "counts": {
                    "assertions": len(state.get("assertions", {})),
                    "revisions": len(state.get("assertion_revisions", {})),
                    "events": len(state.get("events", [])),
                    "promotions": len(state.get("promotions", [])),
                },
            },
        )

    def _handle_current_assertions(self, query: dict[str, list[str]]) -> None:
        with self._with_state_lock():
            filtered = self._filter_assertions(query)
            records = self._build_current_records(filtered)
        self._write_json(200, {"count": len(records), "records": records})

    def _handle_timeline(self, assertion_id: str) -> None:
        with self._with_state_lock():
            assertion = self._state().get("assertions", {}).get(assertion_id)
            if not assertion:
                self._write_json(404, {"error": "assertion_not_found", "assertion_id": assertion_id})
                return
            revisions = [
                rev
                for rev in self._state().get("assertion_revisions", {}).values()
                if rev.get("assertion_id") == assertion_id
            ]
            revisions.sort(key=lambda item: item.get("revision_number", 0), reverse=True)
        self._write_json(
            200,
            {
                "assertion": assertion,
                "count": len(revisions),
                "revisions": revisions,
            },
        )

    def _handle_event_submission(self, body: dict[str, Any], request_id: str) -> None:
        event_record = {
            "request_id": request_id,
            "received_at": now_utc(),
            "event": body,
        }
        with self._with_state_lock():
            self._state().setdefault("events", []).append(event_record)
            self._persist_state()
        self._write_json(202, {"accepted": True, "request_id": request_id, "path": "/v1/agents/events"})

    def _handle_promotion_submission(self, body: dict[str, Any], request_id: str) -> None:
        promotion_record = {
            "promotion_id": random_id("prom"),
            "request_id": request_id,
            "received_at": now_utc(),
            "event": body,
        }
        with self._with_state_lock():
            self._state().setdefault("promotions", []).append(promotion_record)
            self._persist_state()
        self._write_json(
            202,
            {
                "accepted": True,
                "request_id": request_id,
                "path": "/v1/knowledge/promotions",
                "promotion_id": promotion_record["promotion_id"],
            },
        )

    def _extract_assertion_payload(self, envelope: dict[str, Any]) -> dict[str, Any]:
        payload = envelope.get("payload", {})
        workspace = envelope.get("workspace", {})
        org_id = envelope.get("organization", {}).get("id", "")

        if isinstance(payload, dict) and payload.get("schema_version") == "tkd.assertion.payload.v0":
            normalized = dict(payload)
        else:
            normalized = {
                "schema_version": "tkd.assertion.payload.v0",
                "knowledge_key": payload.get("knowledge_key") or slugify(payload.get("title", "untitled")),
                "scope": payload.get("scope") or workspace.get("scope") or "repo",
                "status": payload.get("status") or "proposed",
                "influences": payload.get("influences", []),
                "content": payload,
            }

        normalized.setdefault("knowledge_key", "unknown")
        normalized.setdefault("scope", workspace.get("scope") or "repo")
        normalized.setdefault("status", "proposed")
        normalized.setdefault("influences", [])
        normalized.setdefault("content", {})
        normalized.setdefault("project_id", workspace.get("project_id", workspace.get("id", "")))
        normalized.setdefault("repo_id", workspace.get("repo_id", ""))
        normalized.setdefault("org_id", org_id)
        return normalized

    def _handle_assertion_submission(self, body: dict[str, Any], request_id: str) -> None:
        payload = self._extract_assertion_payload(body)
        org_id = body.get("organization", {}).get("id", "")
        knowledge_key = payload.get("knowledge_key", "unknown")
        scope = payload.get("scope", "repo")
        project_id = payload.get("project_id", "")
        repo_id = payload.get("repo_id", "")
        explicit_assertion_id = payload.get("assertion_id", "")

        assertion_id = assertion_identity(
            scope=scope,
            org_id=org_id,
            project_id=project_id,
            repo_id=repo_id,
            knowledge_key=knowledge_key,
            explicit_assertion_id=explicit_assertion_id,
        )

        with self._with_state_lock():
            state = self._state()
            assertions = state.setdefault("assertions", {})
            revisions = state.setdefault("assertion_revisions", {})

            existing = assertions.get(assertion_id)
            revision_number = 1
            if existing:
                revision_number = int(existing.get("revision_count", 0)) + 1
            else:
                assertions[assertion_id] = {
                    "assertion_id": assertion_id,
                    "knowledge_key": knowledge_key,
                    "scope": scope,
                    "org_id": org_id,
                    "project_id": project_id,
                    "repo_id": repo_id,
                    "created_at": now_utc(),
                    "updated_at": now_utc(),
                    "revision_count": 0,
                    "current_revision_id": "",
                    "status": payload.get("status", "proposed"),
                }

            revision_id = random_id("rev")
            revision = {
                "revision_id": revision_id,
                "assertion_id": assertion_id,
                "revision_number": revision_number,
                "status": payload.get("status", "proposed"),
                "knowledge_key": knowledge_key,
                "scope": scope,
                "project_id": project_id,
                "repo_id": repo_id,
                "event_id": body.get("event_id", ""),
                "parent_revision_id": payload.get("parent_revision_id", ""),
                "influences": payload.get("influences", []),
                "provenance": body.get("provenance", {}),
                "content": payload.get("content", {}),
                "created_at": now_utc(),
            }
            revisions[revision_id] = revision

            assertion = assertions[assertion_id]
            assertion["updated_at"] = now_utc()
            assertion["revision_count"] = revision_number
            assertion["current_revision_id"] = revision_id
            assertion["status"] = revision["status"]

            state.setdefault("events", []).append(
                {
                    "request_id": request_id,
                    "received_at": now_utc(),
                    "event": body,
                }
            )
            self._persist_state()

        self._write_json(
            202,
            {
                "accepted": True,
                "request_id": request_id,
                "path": "/v1/knowledge/assertions",
                "assertion_id": assertion_id,
                "revision_id": revision_id,
                "revision_number": revision_number,
                "scope": scope,
                "knowledge_key": knowledge_key,
            },
        )

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        if path == "/healthz":
            self._handle_health()
            return

        if path in ("/v1/knowledge/assertions/current", "/v1/knowledge/assertions"):
            self._handle_current_assertions(query)
            return

        segments = path.strip("/").split("/")
        if len(segments) == 5 and segments[:3] == ["v1", "knowledge", "assertions"] and segments[4] == "timeline":
            self._handle_timeline(segments[3])
            return

        self._write_json(404, {"error": "not_found"})

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path

        if path not in ("/v1/agents/events", "/v1/knowledge/assertions", "/v1/knowledge/promotions"):
            self._write_json(404, {"error": "not_found"})
            return

        body = self._request_json()
        if body is None:
            return

        request_id = random_id("req")
        self._log_record(path, body, request_id)

        if path == "/v1/agents/events":
            self._handle_event_submission(body, request_id)
            return

        if path == "/v1/knowledge/promotions":
            self._handle_promotion_submission(body, request_id)
            return

        self._handle_assertion_submission(body, request_id)

    def log_message(self, *_args) -> None:
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
    parser.add_argument(
        "--state-file",
        default="/tmp/tkd-mock-state.json",
        help="State snapshot for assertions/revisions/events",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    state_file = pathlib.Path(args.state_file)

    server = ThreadingHTTPServer((args.host, args.port), TKDMockHandler)
    server.log_file = args.log_file  # type: ignore[attr-defined]
    server.state_file = str(state_file)  # type: ignore[attr-defined]
    server.state_lock = threading.Lock()  # type: ignore[attr-defined]
    server.state = load_state(state_file)  # type: ignore[attr-defined]

    print(
        "tkd-mock listening on "
        f"http://{args.host}:{args.port} "
        f"(log: {args.log_file}, state: {args.state_file})",
        flush=True,
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
