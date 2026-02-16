#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KNOWLEDGE_SOURCE="${SCRIPT_DIR}/knowledge.sh"

INSTALL_ROOT="${HOME}/.tkd"
CONFIG_PATH="${INSTALL_ROOT}/config.json"
TKD_BASE_URL="http://127.0.0.1:8787"
AGENT_ID="${USER:-local}-agent"
RUNTIME="generic"
ORG_ID="local-dev"
WORKSPACE_ID="$(basename "$(pwd)")"
PROJECT_ID="${WORKSPACE_ID}"
PROJECT_ID_EXPLICIT="0"
DEFAULT_SCOPE="repo"
FORCE="0"

usage() {
  cat <<'EOF'
Install knowledge CLI and bootstrap local config.

Usage:
  install-tkd-agent.sh [options]

Options:
  --install-root PATH   Install root (default: ~/.tkd)
  --config PATH         Config path (default: <install-root>/config.json)
  --tkd-base-url URL    TKD API base URL
  --agent-id ID         Agent identifier
  --runtime NAME        Agent runtime (codex, claude, cursor, etc.)
  --org-id ID           Organization identifier
  --workspace-id ID     Workspace identifier
  --project-id ID       Project identifier (defaults to workspace id)
  --default-scope SCOPE Default knowledge scope (repo|org)
  --force               Overwrite existing config if present
  --help                Print this help message
EOF
}

log() {
  printf '[install-tkd-agent] %s\n' "$*" >&2
}

die() {
  printf '[install-tkd-agent] ERROR: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-root)
      INSTALL_ROOT="$2"
      CONFIG_PATH="${INSTALL_ROOT}/config.json"
      shift 2
      ;;
    --config)
      CONFIG_PATH="$2"
      shift 2
      ;;
    --tkd-base-url)
      TKD_BASE_URL="$2"
      shift 2
      ;;
    --agent-id)
      AGENT_ID="$2"
      shift 2
      ;;
    --runtime)
      RUNTIME="$2"
      shift 2
      ;;
    --org-id)
      ORG_ID="$2"
      shift 2
      ;;
    --workspace-id)
      WORKSPACE_ID="$2"
      if [[ "$PROJECT_ID_EXPLICIT" != "1" ]]; then
        PROJECT_ID="$WORKSPACE_ID"
      fi
      shift 2
      ;;
    --project-id)
      PROJECT_ID="$2"
      PROJECT_ID_EXPLICIT="1"
      shift 2
      ;;
    --default-scope)
      DEFAULT_SCOPE="$2"
      shift 2
      ;;
    --force)
      FORCE="1"
      shift 1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

[[ -f "$KNOWLEDGE_SOURCE" ]] || die "missing CLI source: ${KNOWLEDGE_SOURCE}"

BIN_DIR="${INSTALL_ROOT}/bin"
TARGET_KNOWLEDGE="${BIN_DIR}/knowledge"
TARGET_COMPAT="${BIN_DIR}/tkd-harness"

mkdir -p "$BIN_DIR"
cp "$KNOWLEDGE_SOURCE" "$TARGET_KNOWLEDGE"
chmod +x "$TARGET_KNOWLEDGE"
ln -sf "knowledge" "$TARGET_COMPAT"
log "installed CLI at ${TARGET_KNOWLEDGE}"
log "installed compatibility alias at ${TARGET_COMPAT}"

if [[ -f "$CONFIG_PATH" && "$FORCE" != "1" ]]; then
  log "config already exists at ${CONFIG_PATH}; keeping existing config"
else
  init_args=(
    init
    --config "$CONFIG_PATH"
    --agent-id "$AGENT_ID"
    --runtime "$RUNTIME"
    --tkd-base-url "$TKD_BASE_URL"
    --org-id "$ORG_ID"
    --workspace-id "$WORKSPACE_ID"
    --project-id "$PROJECT_ID"
    --default-scope "$DEFAULT_SCOPE"
  )
  if [[ "$FORCE" == "1" ]]; then
    init_args+=(--force)
  fi
  "$TARGET_KNOWLEDGE" "${init_args[@]}"
fi

if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]]; then
  printf '\nAdd knowledge to PATH:\n'
  printf '  export PATH="%s:$PATH"\n' "$BIN_DIR"
fi

printf '\nInstall complete.\n'
printf 'CLI:     %s\n' "$TARGET_KNOWLEDGE"
printf 'Config:  %s\n' "$CONFIG_PATH"
printf 'Next:    %s doctor --config %s\n' "$TARGET_KNOWLEDGE" "$CONFIG_PATH"
