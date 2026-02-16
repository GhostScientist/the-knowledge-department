#!/usr/bin/env bash
set -euo pipefail

knowledge_bin="${KNOWLEDGE_BIN:-${HOME}/.tkd/bin/knowledge}"
input_file="$(mktemp "${TMPDIR:-/tmp}/knowledge-claude-hook-in.XXXXXX.json")"
payload_file="$(mktemp "${TMPDIR:-/tmp}/knowledge-claude-hook-payload.XXXXXX.json")"
trap 'rm -f "$input_file" "$payload_file"' EXIT

cat >"$input_file"

python3 - "$input_file" "$payload_file" <<'PY'
import json
import sys

input_file = sys.argv[1]
payload_file = sys.argv[2]

with open(input_file, "r", encoding="utf-8") as file:
    event = json.load(file)

payload = {
    "event": "claude.post_tool_use",
    "session_id": event.get("session_id", ""),
    "transcript_path": event.get("transcript_path", ""),
    "tool_name": event.get("tool_name", ""),
    "tool_input": event.get("tool_input", {}),
}

with open(payload_file, "w", encoding="utf-8") as file:
    json.dump(payload, file)
PY

"$knowledge_bin" event   --config "/Users/dakotakim/.tkd/config.json"   --event-type "agent.learned"   --payload-file "$payload_file"   --scope repo   --project-id "the-knowledge-department" >/dev/null 2>&1 || true
exit 0
