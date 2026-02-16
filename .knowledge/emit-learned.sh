#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: emit-learned.sh PAYLOAD_FILE [CONFIDENCE]" >&2
  exit 1
fi

payload_file="$1"
confidence="${2:-}"
knowledge_bin="${KNOWLEDGE_BIN:-${HOME}/.tkd/bin/knowledge}"

args=(
  event
  --config "/Users/dakotakim/.tkd/config.json"
  --event-type "agent.learned"
  --payload-file "$payload_file"
  --scope "repo"
  --project-id "the-knowledge-department"
)

if [[ -n "$confidence" ]]; then
  args+=(--confidence "$confidence")
fi

"$knowledge_bin" "${args[@]}"
