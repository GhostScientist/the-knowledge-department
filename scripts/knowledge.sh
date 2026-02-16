#!/usr/bin/env bash
set -euo pipefail

HARNESS_VERSION="0.1.0-mvp"
DEFAULT_CONFIG_PATH="${TKD_CONFIG:-${HOME}/.tkd/config.json}"

usage() {
  cat <<'EOF'
Usage:
  knowledge init [options]
  knowledge doctor [options]
  knowledge event --event-type TYPE --payload-file FILE [options]
  knowledge assert --assertion-file FILE [options]

Commands:
  init              Create a local TKD agent config
  doctor            Validate connectivity to TKD /healthz
  event             Submit a provenance-wrapped agent event
  assert            Submit a provenance-wrapped knowledge assertion
  submit-event      Deprecated alias for event
  submit-assertion  Deprecated alias for assert

Options (shared):
  --config PATH     Config path (default: ~/.tkd/config.json or $TKD_CONFIG)
  --help            Print this help message

init options:
  --agent-id ID
  --runtime NAME
  --tkd-base-url URL
  --org-id ID
  --workspace-id ID
  --force

event options:
  --event-type TYPE
  --payload-file FILE
  --confidence FLOAT
  --dry-run
  --envelope-out PATH

assert options:
  --assertion-file FILE
  --confidence FLOAT
  --dry-run
  --envelope-out PATH
EOF
}

log() {
  printf '[knowledge] %s\n' "$*" >&2
}

die() {
  printf '[knowledge] ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "missing required command: ${cmd}"
  fi
}

sha256_file() {
  local file_path="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file_path" | awk '{print $1}'
    return
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file_path" | awk '{print $1}'
    return
  fi
  die "no SHA-256 utility found (expected shasum or sha256sum)"
}

config_get() {
  local config_path="$1"
  local key="$2"
  python3 - "$config_path" "$key" <<'PY'
import json
import sys

config_path = sys.argv[1]
key = sys.argv[2]

with open(config_path, "r", encoding="utf-8") as config_file:
    config = json.load(config_file)

value = config.get(key, "")
if isinstance(value, (dict, list)):
    print(json.dumps(value))
else:
    print(value)
PY
}

git_context() {
  local repo_remote=""
  local repo_branch=""
  local repo_commit=""

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    repo_remote="$(git config --get remote.origin.url 2>/dev/null || true)"
    repo_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    repo_commit="$(git rev-parse HEAD 2>/dev/null || true)"
  fi

  printf '%s\n%s\n%s\n' "$repo_remote" "$repo_branch" "$repo_commit"
}

write_config() {
  local config_path="$1"
  local agent_id="$2"
  local runtime="$3"
  local tkd_base_url="$4"
  local org_id="$5"
  local workspace_id="$6"

  mkdir -p "$(dirname "$config_path")"
  python3 - "$config_path" "$agent_id" "$runtime" "$tkd_base_url" "$org_id" "$workspace_id" <<'PY'
import json
import sys

config_path = sys.argv[1]
agent_id = sys.argv[2]
runtime = sys.argv[3]
tkd_base_url = sys.argv[4]
org_id = sys.argv[5]
workspace_id = sys.argv[6]

config = {
    "schema_version": "tkd.agent.config.v0",
    "agent_id": agent_id,
    "runtime": runtime,
    "tkd_base_url": tkd_base_url.rstrip("/"),
    "org_id": org_id,
    "workspace_id": workspace_id,
}

with open(config_path, "w", encoding="utf-8") as config_file:
    json.dump(config, config_file, indent=2)
    config_file.write("\n")
PY
}

build_envelope_file() {
  local payload_file="$1"
  local event_type="$2"
  local confidence="$3"
  local agent_id="$4"
  local runtime="$5"
  local org_id="$6"
  local workspace_id="$7"
  local repo_remote="$8"
  local repo_branch="$9"
  local repo_commit="${10}"
  local payload_sha="${11}"
  local output_file="${12}"

  python3 - "$payload_file" "$event_type" "$confidence" "$agent_id" "$runtime" "$org_id" \
    "$workspace_id" "$repo_remote" "$repo_branch" "$repo_commit" "$payload_sha" "$HARNESS_VERSION" \
    "${TKD_RUBRIC_VERSION:-mvp-v0}" >"$output_file" <<'PY'
import datetime as dt
import json
import sys
import uuid

payload_path = sys.argv[1]
event_type = sys.argv[2]
confidence_raw = sys.argv[3]
agent_id = sys.argv[4]
runtime = sys.argv[5]
org_id = sys.argv[6]
workspace_id = sys.argv[7]
repo_remote = sys.argv[8]
repo_branch = sys.argv[9]
repo_commit = sys.argv[10]
payload_sha = sys.argv[11]
harness_version = sys.argv[12]
rubric_version = sys.argv[13]

with open(payload_path, "r", encoding="utf-8") as payload_file:
    payload = json.load(payload_file)

confidence = None
if confidence_raw != "":
    confidence = float(confidence_raw)

envelope = {
    "schema_version": "tkd.event.v0",
    "event_id": f"evt_{uuid.uuid4().hex[:20]}",
    "event_type": event_type,
    "occurred_at": dt.datetime.now(dt.timezone.utc).isoformat(),
    "agent": {
        "id": agent_id,
        "runtime": runtime,
    },
    "organization": {
        "id": org_id,
    },
    "workspace": {
        "id": workspace_id,
        "repo_remote": repo_remote,
        "repo_branch": repo_branch,
        "repo_commit": repo_commit,
    },
    "provenance": {
        "source": f"knowledge/{harness_version}",
        "payload_sha256": f"sha256:{payload_sha}",
        "rubric_version": rubric_version,
        "confidence": confidence,
    },
    "payload": payload,
}

print(json.dumps(envelope))
PY
}

post_json_file() {
  local url="$1"
  local json_file="$2"

  local curl_args=(
    -fsS
    -X POST
    "$url"
    -H "Content-Type: application/json"
    --data-binary "@${json_file}"
  )

  if [[ -n "${TKD_API_KEY:-}" ]]; then
    curl_args+=(-H "Authorization: Bearer ${TKD_API_KEY}")
  fi

  curl "${curl_args[@]}"
}

cmd_init() {
  local config_path="$DEFAULT_CONFIG_PATH"
  local agent_id="${USER:-local}-agent"
  local runtime="generic"
  local tkd_base_url="http://127.0.0.1:8787"
  local org_id="local-dev"
  local workspace_id
  workspace_id="$(basename "$(pwd)")"
  local force="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        config_path="$2"
        shift 2
        ;;
      --agent-id)
        agent_id="$2"
        shift 2
        ;;
      --runtime)
        runtime="$2"
        shift 2
        ;;
      --tkd-base-url)
        tkd_base_url="$2"
        shift 2
        ;;
      --org-id)
        org_id="$2"
        shift 2
        ;;
      --workspace-id)
        workspace_id="$2"
        shift 2
        ;;
      --force)
        force="1"
        shift 1
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        die "unknown init option: $1"
        ;;
    esac
  done

  require_cmd python3

  if [[ -f "$config_path" && "$force" != "1" ]]; then
    die "config already exists at ${config_path} (use --force to overwrite)"
  fi

  write_config "$config_path" "$agent_id" "$runtime" "$tkd_base_url" "$org_id" "$workspace_id"
  log "wrote config: ${config_path}"
}

cmd_doctor() {
  local config_path="$DEFAULT_CONFIG_PATH"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        config_path="$2"
        shift 2
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        die "unknown doctor option: $1"
        ;;
    esac
  done

  require_cmd curl
  require_cmd python3

  [[ -f "$config_path" ]] || die "config not found: ${config_path}"
  local tkd_base_url
  tkd_base_url="$(config_get "$config_path" "tkd_base_url")"
  [[ -n "$tkd_base_url" ]] || die "tkd_base_url missing in config"

  local health_url="${tkd_base_url%/}/healthz"
  log "checking ${health_url}"
  curl -fsS "$health_url"
  printf '\n'
}

submit_with_provenance() {
  local config_path="$1"
  local endpoint="$2"
  local event_type="$3"
  local payload_file="$4"
  local confidence="$5"
  local dry_run="$6"
  local envelope_out="$7"

  require_cmd python3
  if [[ "$dry_run" != "1" ]]; then
    require_cmd curl
  fi

  [[ -f "$config_path" ]] || die "config not found: ${config_path}"
  [[ -f "$payload_file" ]] || die "payload file not found: ${payload_file}"

  local tkd_base_url agent_id runtime org_id workspace_id
  tkd_base_url="$(config_get "$config_path" "tkd_base_url")"
  agent_id="$(config_get "$config_path" "agent_id")"
  runtime="$(config_get "$config_path" "runtime")"
  org_id="$(config_get "$config_path" "org_id")"
  workspace_id="$(config_get "$config_path" "workspace_id")"

  local payload_sha
  payload_sha="$(sha256_file "$payload_file")"

  local repo_remote repo_branch repo_commit
  local context
  context="$(git_context)"
  repo_remote="$(printf '%s\n' "$context" | sed -n '1p')"
  repo_branch="$(printf '%s\n' "$context" | sed -n '2p')"
  repo_commit="$(printf '%s\n' "$context" | sed -n '3p')"

  local envelope_file
  envelope_file="$(mktemp "${TMPDIR:-/tmp}/tkd-envelope.XXXXXX.json")"

  build_envelope_file \
    "$payload_file" "$event_type" "$confidence" "$agent_id" "$runtime" "$org_id" \
    "$workspace_id" "$repo_remote" "$repo_branch" "$repo_commit" "$payload_sha" "$envelope_file"

  if [[ -n "$envelope_out" ]]; then
    mkdir -p "$(dirname "$envelope_out")"
    cp "$envelope_file" "$envelope_out"
  fi

  if [[ "$dry_run" == "1" ]]; then
    cat "$envelope_file"
    printf '\n'
    rm -f "$envelope_file"
    return
  fi

  local submit_url="${tkd_base_url%/}${endpoint}"
  log "submitting ${event_type} to ${submit_url}"
  post_json_file "$submit_url" "$envelope_file"
  printf '\n'
  rm -f "$envelope_file"
}

cmd_event() {
  local config_path="$DEFAULT_CONFIG_PATH"
  local event_type=""
  local payload_file=""
  local confidence=""
  local dry_run="0"
  local envelope_out=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        config_path="$2"
        shift 2
        ;;
      --event-type)
        event_type="$2"
        shift 2
        ;;
      --payload-file)
        payload_file="$2"
        shift 2
        ;;
      --confidence)
        confidence="$2"
        shift 2
        ;;
      --dry-run)
        dry_run="1"
        shift 1
        ;;
      --envelope-out)
        envelope_out="$2"
        shift 2
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        die "unknown event option: $1"
        ;;
    esac
  done

  [[ -n "$event_type" ]] || die "--event-type is required"
  [[ -n "$payload_file" ]] || die "--payload-file is required"
  submit_with_provenance \
    "$config_path" \
    "/v1/agents/events" \
    "$event_type" \
    "$payload_file" \
    "$confidence" \
    "$dry_run" \
    "$envelope_out"
}

cmd_assert() {
  local config_path="$DEFAULT_CONFIG_PATH"
  local assertion_file=""
  local confidence=""
  local dry_run="0"
  local envelope_out=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        config_path="$2"
        shift 2
        ;;
      --assertion-file)
        assertion_file="$2"
        shift 2
        ;;
      --confidence)
        confidence="$2"
        shift 2
        ;;
      --dry-run)
        dry_run="1"
        shift 1
        ;;
      --envelope-out)
        envelope_out="$2"
        shift 2
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        die "unknown assert option: $1"
        ;;
    esac
  done

  [[ -n "$assertion_file" ]] || die "--assertion-file is required"
  submit_with_provenance \
    "$config_path" \
    "/v1/knowledge/assertions" \
    "knowledge_assertion.proposed" \
    "$assertion_file" \
    "$confidence" \
    "$dry_run" \
    "$envelope_out"
}

main() {
  local command="${1:-}"
  if [[ -z "$command" ]]; then
    usage
    exit 1
  fi
  shift || true

  case "$command" in
    init)
      cmd_init "$@"
      ;;
    doctor)
      cmd_doctor "$@"
      ;;
    event)
      cmd_event "$@"
      ;;
    submit-event)
      log "submit-event is deprecated; use knowledge event"
      cmd_event "$@"
      ;;
    assert)
      cmd_assert "$@"
      ;;
    submit-assertion)
      log "submit-assertion is deprecated; use knowledge assert"
      cmd_assert "$@"
      ;;
    --help|-h|help)
      usage
      ;;
    *)
      die "unknown command: ${command}"
      ;;
  esac
}

main "$@"
