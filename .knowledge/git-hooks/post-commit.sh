#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
knowledge_bin="${KNOWLEDGE_BIN:-${HOME}/.tkd/bin/knowledge}"
commit_sha="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || true)"
if [[ -z "$commit_sha" ]]; then
  exit 0
fi

payload_file="$(mktemp "${TMPDIR:-/tmp}/knowledge-git-commit.XXXXXX.json")"
trap 'rm -f "$payload_file"' EXIT

python3 - "$repo_root" "$commit_sha" "$payload_file" <<'PY'
import json
import subprocess
import sys

repo_root = sys.argv[1]
commit_sha = sys.argv[2]
payload_file = sys.argv[3]

subject = ""
author = ""
try:
    subject = subprocess.check_output(
        ["git", "-C", repo_root, "show", "-s", "--format=%s", commit_sha],
        text=True,
    ).strip()
    author = subprocess.check_output(
        ["git", "-C", repo_root, "show", "-s", "--format=%an <%ae>", commit_sha],
        text=True,
    ).strip()
except Exception:
    pass

payload = {
    "event": "git.post_commit",
    "commit_sha": commit_sha,
    "subject": subject,
    "author": author,
}

with open(payload_file, "w", encoding="utf-8") as file:
    json.dump(payload, file)
PY

"$knowledge_bin" event   --config "/Users/dakotakim/.tkd/config.json"   --event-type "git.commit.recorded"   --payload-file "$payload_file"   --scope repo   --project-id "the-knowledge-department" >/dev/null 2>&1 || true
exit 0
