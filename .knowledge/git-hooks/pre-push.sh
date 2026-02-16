#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
knowledge_bin="${KNOWLEDGE_BIN:-${HOME}/.tkd/bin/knowledge}"
remote_name="${1:-}"
remote_url="${2:-}"
push_updates="$(cat || true)"

payload_file="$(mktemp "${TMPDIR:-/tmp}/knowledge-git-push.XXXXXX.json")"
trap 'rm -f "$payload_file"' EXIT

python3 - "$remote_name" "$remote_url" "$push_updates" "$payload_file" <<'PY'
import json
import sys

remote_name = sys.argv[1]
remote_url = sys.argv[2]
push_updates = sys.argv[3]
payload_file = sys.argv[4]

updates = []
for line in push_updates.splitlines():
    line = line.strip()
    if not line:
        continue
    parts = line.split()
    if len(parts) == 4:
        updates.append(
            {
                "local_ref": parts[0],
                "local_sha": parts[1],
                "remote_ref": parts[2],
                "remote_sha": parts[3],
            }
        )
    else:
        updates.append({"raw": line})

payload = {
    "event": "git.pre_push",
    "remote_name": remote_name,
    "remote_url": remote_url,
    "updates": updates,
}

with open(payload_file, "w", encoding="utf-8") as file:
    json.dump(payload, file)
PY

"$knowledge_bin" event   --config "/Users/dakotakim/.tkd/config.json"   --event-type "git.push.attempted"   --payload-file "$payload_file"   --scope repo   --project-id "the-knowledge-department" >/dev/null 2>&1 || true
exit 0
