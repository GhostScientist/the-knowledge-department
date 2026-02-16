#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

printf '[tkd-harness] %s\n' "deprecated command; use knowledge instead" >&2
exec "${SCRIPT_DIR}/knowledge.sh" "$@"
