#!/usr/bin/env bash
set -euo pipefail

KNOWLEDGE_VERSION="0.2.0-mvp"
DEFAULT_CONFIG_PATH="${TKD_CONFIG:-${HOME}/.tkd/config.json}"

usage() {
  cat <<'USAGE'
Usage:
  knowledge init [options]
  knowledge enable [options]
  knowledge status [options]
  knowledge doctor [options]
  knowledge event --event-type TYPE --payload-file FILE [options]
  knowledge assert --assertion-file FILE --knowledge-key KEY [options]
  knowledge promote --knowledge-key KEY [options]
  knowledge lookup [options]

Commands:
  init              Create local TKD agent config
  enable            Create repo-local hook scaffold for selected agents
  status            Show repo-local hook scaffold status
  doctor            Validate connectivity to TKD /healthz
  event             Submit a provenance-wrapped agent event
  assert            Submit a scoped knowledge assertion revision
  promote           Propose promotion from repo scope to org scope
  lookup            Query current knowledge assertions or timeline
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
  --project-id ID
  --default-scope repo|org
  --force

enable options:
  --repo-root PATH
  --project-id ID
  --repo-id ID
  --agent NAME                    (repeatable; default: claude)
  --all-agents                    (claude, codex, cursor, gemini)
  --force

status options:
  --repo-root PATH
  --json

event options:
  --event-type TYPE
  --payload-file FILE
  --scope repo|org
  --project-id ID
  --repo-id ID
  --confidence FLOAT
  --dry-run
  --envelope-out PATH

assert options:
  --assertion-file FILE
  --knowledge-key KEY
  --scope repo|org
  --project-id ID
  --repo-id ID
  --status STATUS                  (default: proposed)
  --assertion-id ID                (optional logical assertion id)
  --parent-revision-id ID          (optional previous revision)
  --influence TYPE:REF             (repeatable)
  --confidence FLOAT
  --dry-run
  --envelope-out PATH

promote options:
  --knowledge-key KEY
  --from-scope repo|org            (default: repo)
  --to-scope repo|org              (default: org)
  --project-id ID
  --repo-id ID
  --assertion-id ID
  --reason TEXT
  --confidence FLOAT
  --dry-run
  --envelope-out PATH

lookup options:
  --knowledge-key KEY
  --scope repo|org
  --project-id ID
  --repo-id ID
  --assertion-id ID
  --timeline
USAGE
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

sha256_string() {
  local value="$1"
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$value" | shasum -a 256 | awk '{print $1}'
    return
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$value" | sha256sum | awk '{print $1}'
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

assert_scope() {
  local scope="$1"
  case "$scope" in
    repo|org)
      ;;
    *)
      die "invalid scope: ${scope} (expected repo or org)"
      ;;
  esac
}

git_context() {
  local repo_remote=""
  local repo_branch=""
  local repo_commit=""
  local repo_root=""

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    repo_remote="$(git config --get remote.origin.url 2>/dev/null || true)"
    repo_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    repo_commit="$(git rev-parse HEAD 2>/dev/null || true)"
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  fi

  printf '%s\n%s\n%s\n%s\n' "$repo_remote" "$repo_branch" "$repo_commit" "$repo_root"
}

derive_repo_id() {
  local repo_remote="$1"
  local repo_root="$2"
  local source=""

  if [[ -n "$repo_remote" ]]; then
    source="remote:${repo_remote}"
  elif [[ -n "$repo_root" ]]; then
    source="path:${repo_root}"
  else
    source="cwd:$(pwd)"
  fi

  local digest
  digest="$(sha256_string "$source")"
  printf 'repo_%s\n' "${digest:0:12}"
}

resolve_context() {
  local config_path="$1"
  local requested_scope="$2"
  local requested_project_id="$3"
  local requested_repo_id="$4"

  [[ -f "$config_path" ]] || die "config not found: ${config_path}"

  local default_scope
  default_scope="$(config_get "$config_path" "default_scope")"
  if [[ -z "$default_scope" ]]; then
    default_scope="repo"
  fi

  local scope
  scope="${requested_scope:-$default_scope}"
  assert_scope "$scope"

  local workspace_id
  workspace_id="$(config_get "$config_path" "workspace_id")"
  local config_project_id
  config_project_id="$(config_get "$config_path" "project_id")"
  if [[ -z "$config_project_id" ]]; then
    config_project_id="$workspace_id"
  fi
  local project_id
  project_id="${requested_project_id:-$config_project_id}"

  local repo_remote repo_branch repo_commit repo_root
  local context
  context="$(git_context)"
  repo_remote="$(printf '%s\n' "$context" | sed -n '1p')"
  repo_branch="$(printf '%s\n' "$context" | sed -n '2p')"
  repo_commit="$(printf '%s\n' "$context" | sed -n '3p')"
  repo_root="$(printf '%s\n' "$context" | sed -n '4p')"

  local repo_id
  if [[ -n "$requested_repo_id" ]]; then
    repo_id="$requested_repo_id"
  else
    repo_id="$(derive_repo_id "$repo_remote" "$repo_root")"
  fi

  printf '%s\n%s\n%s\n' "$scope" "$project_id" "$repo_id"
}

determine_repo_root() {
  local requested_repo_root="$1"
  if [[ -n "$requested_repo_root" ]]; then
    printf '%s\n' "$requested_repo_root"
    return
  fi

  local context
  context="$(git_context)"
  local repo_root
  repo_root="$(printf '%s\n' "$context" | sed -n '4p')"
  if [[ -z "$repo_root" ]]; then
    repo_root="$(pwd)"
  fi
  printf '%s\n' "$repo_root"
}

write_repo_connection_file() {
  local output_file="$1"
  local org_id="$2"
  local project_id="$3"
  local repo_id="$4"
  local agent_id="$5"
  local runtime="$6"
  local agents_csv="$7"
  local config_path="$8"

  python3 - "$output_file" "$org_id" "$project_id" "$repo_id" "$agent_id" "$runtime" "$agents_csv" "$config_path" <<'PY'
import datetime as dt
import json
import pathlib
import sys

output_file = pathlib.Path(sys.argv[1])
org_id = sys.argv[2]
project_id = sys.argv[3]
repo_id = sys.argv[4]
agent_id = sys.argv[5]
runtime = sys.argv[6]
agents_csv = sys.argv[7]
config_path = sys.argv[8]

agents = [agent.strip() for agent in agents_csv.split(",") if agent.strip()]
document = {
    "schema_version": "tkd.repo.enable.v0",
    "enabled_at": dt.datetime.now(dt.timezone.utc).isoformat(),
    "organization": {
        "id": org_id,
    },
    "project": {
        "id": project_id,
    },
    "repo": {
        "id": repo_id,
    },
    "installer": {
        "agent_id": agent_id,
        "runtime": runtime,
        "config_path": config_path,
    },
    "agents": agents,
    "hooks": {
        "mode": "repo_hooks",
        "learned_event_type": "agent.learned",
        "default_scope": "repo",
    },
}

output_file.parent.mkdir(parents=True, exist_ok=True)
with output_file.open("w", encoding="utf-8") as file:
    json.dump(document, file, indent=2)
    file.write("\n")
PY
}

write_repo_template_file() {
  local output_file="$1"
  cat >"$output_file" <<'EOF'
{
  "fact_summary": "What was learned",
  "source_type": "chat|tool|doc",
  "source_refs": [
    "optional URL or doc id"
  ],
  "evidence": [
    "short evidence statement"
  ],
  "confidence_rationale": "why this confidence was assigned"
}
EOF
}

write_repo_hook_script() {
  local output_file="$1"
  local config_path="$2"
  local project_id="$3"

  cat >"$output_file" <<EOF
#!/usr/bin/env bash
set -euo pipefail

if [[ \$# -lt 1 ]]; then
  echo "Usage: emit-learned.sh PAYLOAD_FILE [CONFIDENCE]" >&2
  exit 1
fi

payload_file="\$1"
confidence="\${2:-}"
knowledge_bin="\${KNOWLEDGE_BIN:-\${HOME}/.tkd/bin/knowledge}"

args=(
  event
  --config "$config_path"
  --event-type "agent.learned"
  --payload-file "\$payload_file"
  --scope "repo"
  --project-id "$project_id"
)

if [[ -n "\$confidence" ]]; then
  args+=(--confidence "\$confidence")
fi

"\$knowledge_bin" "\${args[@]}"
EOF
  chmod +x "$output_file"
}

write_commit_hook_script() {
  local output_file="$1"
  local config_path="$2"
  local project_id="$3"

  cat >"$output_file" <<EOF
#!/usr/bin/env bash
set -euo pipefail

repo_root="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)"
knowledge_bin="\${KNOWLEDGE_BIN:-\${HOME}/.tkd/bin/knowledge}"
commit_sha="\$(git -C "\$repo_root" rev-parse HEAD 2>/dev/null || true)"
if [[ -z "\$commit_sha" ]]; then
  exit 0
fi

payload_file="\$(mktemp "\${TMPDIR:-/tmp}/knowledge-git-commit.XXXXXX")"
trap 'rm -f "\$payload_file"' EXIT

python3 - "\$repo_root" "\$commit_sha" "\$payload_file" <<'PY'
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

"\$knowledge_bin" event \
  --config "$config_path" \
  --event-type "git.commit.recorded" \
  --payload-file "\$payload_file" \
  --scope repo \
  --project-id "$project_id" >/dev/null 2>&1 || true
exit 0
EOF
  chmod +x "$output_file"
}

write_push_hook_script() {
  local output_file="$1"
  local config_path="$2"
  local project_id="$3"

  cat >"$output_file" <<EOF
#!/usr/bin/env bash
set -euo pipefail

repo_root="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)"
knowledge_bin="\${KNOWLEDGE_BIN:-\${HOME}/.tkd/bin/knowledge}"
remote_name="\${1:-}"
remote_url="\${2:-}"
push_updates="\$(cat || true)"

payload_file="\$(mktemp "\${TMPDIR:-/tmp}/knowledge-git-push.XXXXXX")"
trap 'rm -f "\$payload_file"' EXIT

python3 - "\$remote_name" "\$remote_url" "\$push_updates" "\$payload_file" <<'PY'
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

"\$knowledge_bin" event \
  --config "$config_path" \
  --event-type "git.push.attempted" \
  --payload-file "\$payload_file" \
  --scope repo \
  --project-id "$project_id" >/dev/null 2>&1 || true
exit 0
EOF
  chmod +x "$output_file"
}

write_claude_post_tool_hook_script() {
  local output_file="$1"
  local config_path="$2"
  local project_id="$3"

  cat >"$output_file" <<EOF
#!/usr/bin/env bash
set -euo pipefail

knowledge_bin="\${KNOWLEDGE_BIN:-\${HOME}/.tkd/bin/knowledge}"
input_file="\$(mktemp "\${TMPDIR:-/tmp}/knowledge-claude-hook-in.XXXXXX")"
payload_file="\$(mktemp "\${TMPDIR:-/tmp}/knowledge-claude-hook-payload.XXXXXX")"
trap 'rm -f "\$input_file" "\$payload_file"' EXIT

cat >"\$input_file"

python3 - "\$input_file" "\$payload_file" <<'PY'
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

"\$knowledge_bin" event \
  --config "$config_path" \
  --event-type "agent.learned" \
  --payload-file "\$payload_file" \
  --scope repo \
  --project-id "$project_id" >/dev/null 2>&1 || true
exit 0
EOF
  chmod +x "$output_file"
}

git_hooks_dir() {
  local repo_root="$1"
  if ! git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
    printf '\n'
    return
  fi

  local hooks_path
  hooks_path="$(git -C "$repo_root" rev-parse --git-path hooks 2>/dev/null || true)"
  if [[ -z "$hooks_path" ]]; then
    printf '\n'
    return
  fi
  if [[ "$hooks_path" != /* ]]; then
    hooks_path="${repo_root}/${hooks_path}"
  fi
  printf '%s\n' "$hooks_path"
}

install_managed_git_hook_wrapper() {
  local repo_root="$1"
  local hooks_dir="$2"
  local hook_name="$3"
  local force="$4"
  local backups_dir="$5"

  mkdir -p "$hooks_dir"
  local hook_path="${hooks_dir}/${hook_name}"
  local managed_marker="# managed-by: knowledge"

  if [[ -f "$hook_path" ]] && ! grep -q "$managed_marker" "$hook_path"; then
    if [[ "$force" != "1" ]]; then
      die "refusing to overwrite existing ${hook_name} hook at ${hook_path} (use --force)"
    fi
    mkdir -p "$backups_dir"
    local backup_file="${backups_dir}/${hook_name}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$hook_path" "$backup_file"
    log "backed up existing ${hook_name} hook to ${backup_file}"
  fi

  cat >"$hook_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
$managed_marker

repo_root="$repo_root"
hook_script="\${repo_root}/.knowledge/git-hooks/${hook_name}.sh"
if [[ -x "\$hook_script" ]]; then
  "\$hook_script" "\$@" || true
fi
exit 0
EOF
  chmod +x "$hook_path"
}

configure_claude_settings_hook() {
  local repo_root="$1"
  local hook_script_path="$2"
  local force="$3"
  local backups_dir="$4"

  local settings_dir="${repo_root}/.claude"
  local settings_file="${settings_dir}/settings.local.json"
  mkdir -p "$settings_dir"

  python3 - "$settings_file" "$hook_script_path" "$force" "$backups_dir" <<'PY'
import datetime as dt
import json
import pathlib
import shutil
import sys

settings_file = pathlib.Path(sys.argv[1])
hook_script_path = sys.argv[2]
force = sys.argv[3] == "1"
backups_dir = pathlib.Path(sys.argv[4])

data = {}
if settings_file.exists():
    raw = settings_file.read_text(encoding="utf-8")
    if raw.strip():
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as exc:
            if not force:
                raise SystemExit(
                    f"claude settings file is invalid JSON: {settings_file} ({exc})"
                )
            backups_dir.mkdir(parents=True, exist_ok=True)
            backup_file = backups_dir / (
                "claude-settings.local.invalid."
                + dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d%H%M%S")
                + ".json"
            )
            backup_file.write_text(raw, encoding="utf-8")
            data = {}

if not isinstance(data, dict):
    if not force:
        raise SystemExit(f"claude settings root must be an object: {settings_file}")
    data = {}

original = json.dumps(data, sort_keys=True)
hooks = data.get("hooks")
if not isinstance(hooks, dict):
    hooks = {}
data["hooks"] = hooks

post_tool = hooks.get("PostToolUse")
if not isinstance(post_tool, list):
    post_tool = []
hooks["PostToolUse"] = post_tool

matcher = "Write|Edit|MultiEdit|Bash"
target = None
for entry in post_tool:
    if isinstance(entry, dict) and entry.get("matcher") == matcher:
        target = entry
        break
if target is None:
    target = {"matcher": matcher, "hooks": []}
    post_tool.append(target)

if not isinstance(target.get("hooks"), list):
    target["hooks"] = []

desired = {"type": "command", "command": hook_script_path}
if desired not in target["hooks"]:
    target["hooks"].append(desired)

updated = json.dumps(data, sort_keys=True)
if updated != original:
    if settings_file.exists():
        backups_dir.mkdir(parents=True, exist_ok=True)
        backup_file = backups_dir / (
            "claude-settings.local."
            + dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d%H%M%S")
            + ".json"
        )
        shutil.copy2(settings_file, backup_file)
    settings_file.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print("configured")
else:
    print("unchanged")
PY
}

status_claude_hook_configured() {
  local repo_root="$1"
  local hook_script_path="$2"
  local settings_file="${repo_root}/.claude/settings.local.json"
  if [[ ! -f "$settings_file" ]]; then
    printf 'no\n'
    return
  fi
  python3 - "$settings_file" "$hook_script_path" <<'PY'
import json
import sys

settings_file = sys.argv[1]
hook_script_path = sys.argv[2]

try:
    with open(settings_file, "r", encoding="utf-8") as file:
        data = json.load(file)
except Exception:
    print("invalid")
    raise SystemExit

hooks = data.get("hooks", {})
post_tool = hooks.get("PostToolUse", [])
for entry in post_tool:
    for hook in entry.get("hooks", []):
        if hook.get("type") == "command" and hook.get("command") == hook_script_path:
            print("yes")
            raise SystemExit
print("no")
PY
}

status_managed_git_hook() {
  local hooks_dir="$1"
  local hook_name="$2"
  local hook_path="${hooks_dir}/${hook_name}"
  if [[ -f "$hook_path" ]] && grep -q "# managed-by: knowledge" "$hook_path"; then
    printf 'yes\n'
  else
    printf 'no\n'
  fi
}

write_config() {
  local config_path="$1"
  local agent_id="$2"
  local runtime="$3"
  local tkd_base_url="$4"
  local org_id="$5"
  local workspace_id="$6"
  local project_id="$7"
  local default_scope="$8"

  mkdir -p "$(dirname "$config_path")"
  python3 - "$config_path" "$agent_id" "$runtime" "$tkd_base_url" "$org_id" "$workspace_id" "$project_id" "$default_scope" <<'PY'
import json
import sys

config_path = sys.argv[1]
agent_id = sys.argv[2]
runtime = sys.argv[3]
tkd_base_url = sys.argv[4]
org_id = sys.argv[5]
workspace_id = sys.argv[6]
project_id = sys.argv[7]
default_scope = sys.argv[8]

config = {
    "schema_version": "tkd.agent.config.v1",
    "agent_id": agent_id,
    "runtime": runtime,
    "tkd_base_url": tkd_base_url.rstrip("/"),
    "org_id": org_id,
    "workspace_id": workspace_id,
    "project_id": project_id,
    "default_scope": default_scope,
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
  local project_id="$8"
  local scope="$9"
  local repo_id="${10}"
  local repo_remote="${11}"
  local repo_branch="${12}"
  local repo_commit="${13}"
  local repo_root="${14}"
  local payload_sha="${15}"
  local output_file="${16}"

  python3 - "$payload_file" "$event_type" "$confidence" "$agent_id" "$runtime" "$org_id" \
    "$workspace_id" "$project_id" "$scope" "$repo_id" "$repo_remote" "$repo_branch" \
    "$repo_commit" "$repo_root" "$payload_sha" "$KNOWLEDGE_VERSION" "${TKD_RUBRIC_VERSION:-mvp-v0}" \
    >"$output_file" <<'PY'
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
project_id = sys.argv[8]
scope = sys.argv[9]
repo_id = sys.argv[10]
repo_remote = sys.argv[11]
repo_branch = sys.argv[12]
repo_commit = sys.argv[13]
repo_root = sys.argv[14]
payload_sha = sys.argv[15]
knowledge_version = sys.argv[16]
rubric_version = sys.argv[17]

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
        "project_id": project_id,
        "scope": scope,
        "repo_id": repo_id,
        "repo_remote": repo_remote,
        "repo_branch": repo_branch,
        "repo_commit": repo_commit,
        "repo_root": repo_root,
    },
    "provenance": {
        "source": f"knowledge/{knowledge_version}",
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

submit_with_provenance() {
  local config_path="$1"
  local endpoint="$2"
  local event_type="$3"
  local payload_file="$4"
  local confidence="$5"
  local dry_run="$6"
  local envelope_out="$7"
  local requested_scope="$8"
  local requested_project_id="$9"
  local requested_repo_id="${10}"

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

  local resolved scope project_id repo_id
  resolved="$(resolve_context "$config_path" "$requested_scope" "$requested_project_id" "$requested_repo_id")"
  scope="$(printf '%s\n' "$resolved" | sed -n '1p')"
  project_id="$(printf '%s\n' "$resolved" | sed -n '2p')"
  repo_id="$(printf '%s\n' "$resolved" | sed -n '3p')"

  local payload_sha
  payload_sha="$(sha256_file "$payload_file")"

  local repo_remote repo_branch repo_commit repo_root
  local context
  context="$(git_context)"
  repo_remote="$(printf '%s\n' "$context" | sed -n '1p')"
  repo_branch="$(printf '%s\n' "$context" | sed -n '2p')"
  repo_commit="$(printf '%s\n' "$context" | sed -n '3p')"
  repo_root="$(printf '%s\n' "$context" | sed -n '4p')"

  local envelope_file
  envelope_file="$(mktemp "${TMPDIR:-/tmp}/tkd-envelope.XXXXXX")"

  build_envelope_file \
    "$payload_file" "$event_type" "$confidence" "$agent_id" "$runtime" "$org_id" \
    "$workspace_id" "$project_id" "$scope" "$repo_id" "$repo_remote" "$repo_branch" \
    "$repo_commit" "$repo_root" "$payload_sha" "$envelope_file"

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

write_assertion_payload() {
  local base_payload_file="$1"
  local output_file="$2"
  local knowledge_key="$3"
  local scope="$4"
  local project_id="$5"
  local repo_id="$6"
  local assertion_id="$7"
  local parent_revision_id="$8"
  local status="$9"
  local influences_blob="${10}"

  python3 - "$base_payload_file" "$output_file" "$knowledge_key" "$scope" "$project_id" "$repo_id" \
    "$assertion_id" "$parent_revision_id" "$status" "$influences_blob" <<'PY'
import json
import sys

base_payload_file = sys.argv[1]
output_file = sys.argv[2]
knowledge_key = sys.argv[3]
scope = sys.argv[4]
project_id = sys.argv[5]
repo_id = sys.argv[6]
assertion_id = sys.argv[7]
parent_revision_id = sys.argv[8]
status = sys.argv[9]
influences_blob = sys.argv[10]

with open(base_payload_file, "r", encoding="utf-8") as payload_file:
    content = json.load(payload_file)

influences = []
for line in influences_blob.splitlines():
    line = line.strip()
    if not line:
        continue
    if ":" not in line:
        raise SystemExit(f"invalid influence format '{line}', expected TYPE:REF")
    influence_type, influence_ref = line.split(":", 1)
    influences.append(
        {
            "type": influence_type.strip(),
            "ref": influence_ref.strip(),
        }
    )

payload = {
    "schema_version": "tkd.assertion.payload.v0",
    "knowledge_key": knowledge_key,
    "scope": scope,
    "status": status,
    "influences": influences,
    "content": content,
}

if project_id:
    payload["project_id"] = project_id
if repo_id:
    payload["repo_id"] = repo_id
if assertion_id:
    payload["assertion_id"] = assertion_id
if parent_revision_id:
    payload["parent_revision_id"] = parent_revision_id

with open(output_file, "w", encoding="utf-8") as out_file:
    json.dump(payload, out_file)
PY
}

write_promotion_payload() {
  local output_file="$1"
  local knowledge_key="$2"
  local from_scope="$3"
  local to_scope="$4"
  local project_id="$5"
  local repo_id="$6"
  local assertion_id="$7"
  local reason="$8"

  python3 - "$output_file" "$knowledge_key" "$from_scope" "$to_scope" "$project_id" "$repo_id" \
    "$assertion_id" "$reason" <<'PY'
import json
import sys

output_file = sys.argv[1]
knowledge_key = sys.argv[2]
from_scope = sys.argv[3]
to_scope = sys.argv[4]
project_id = sys.argv[5]
repo_id = sys.argv[6]
assertion_id = sys.argv[7]
reason = sys.argv[8]

payload = {
    "schema_version": "tkd.promotion.payload.v0",
    "knowledge_key": knowledge_key,
    "from_scope": from_scope,
    "to_scope": to_scope,
}

if project_id:
    payload["project_id"] = project_id
if repo_id:
    payload["repo_id"] = repo_id
if assertion_id:
    payload["assertion_id"] = assertion_id
if reason:
    payload["reason"] = reason

with open(output_file, "w", encoding="utf-8") as out_file:
    json.dump(payload, out_file)
PY
}

cmd_init() {
  local config_path="$DEFAULT_CONFIG_PATH"
  local agent_id="${USER:-local}-agent"
  local runtime="generic"
  local tkd_base_url="http://127.0.0.1:8787"
  local org_id="local-dev"
  local workspace_id
  workspace_id="$(basename "$(pwd)")"
  local project_id="$workspace_id"
  local project_id_explicit="0"
  local default_scope="repo"
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
        if [[ "$project_id_explicit" != "1" ]]; then
          project_id="$workspace_id"
        fi
        shift 2
        ;;
      --project-id)
        project_id="$2"
        project_id_explicit="1"
        shift 2
        ;;
      --default-scope)
        default_scope="$2"
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
  assert_scope "$default_scope"

  if [[ -f "$config_path" && "$force" != "1" ]]; then
    die "config already exists at ${config_path} (use --force to overwrite)"
  fi

  write_config "$config_path" "$agent_id" "$runtime" "$tkd_base_url" "$org_id" "$workspace_id" "$project_id" "$default_scope"
  log "wrote config: ${config_path}"
}

cmd_enable() {
  local config_path="$DEFAULT_CONFIG_PATH"
  local repo_root=""
  local project_id=""
  local repo_id=""
  local force="0"
  local all_agents="0"
  local custom_agents="0"
  local -a agents=("claude")

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        config_path="$2"
        shift 2
        ;;
      --repo-root)
        repo_root="$2"
        shift 2
        ;;
      --project-id)
        project_id="$2"
        shift 2
        ;;
      --repo-id)
        repo_id="$2"
        shift 2
        ;;
      --agent)
        if [[ "$custom_agents" != "1" ]]; then
          agents=()
          custom_agents="1"
        fi
        agents+=("$2")
        shift 2
        ;;
      --all-agents)
        all_agents="1"
        shift 1
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
        die "unknown enable option: $1"
        ;;
    esac
  done

  require_cmd python3
  [[ -f "$config_path" ]] || die "config not found: ${config_path}"

  if [[ "$all_agents" == "1" ]]; then
    agents=("claude" "codex" "cursor" "gemini")
  fi

  repo_root="$(determine_repo_root "$repo_root")"
  local resolved resolved_scope resolved_project_id resolved_repo_id
  resolved="$(resolve_context "$config_path" "repo" "$project_id" "$repo_id")"
  resolved_scope="$(printf '%s\n' "$resolved" | sed -n '1p')"
  resolved_project_id="$(printf '%s\n' "$resolved" | sed -n '2p')"
  resolved_repo_id="$(printf '%s\n' "$resolved" | sed -n '3p')"
  if [[ "$resolved_scope" != "repo" ]]; then
    die "enable only supports repo scope scaffolding"
  fi

  local metadata_dir="${repo_root}/.knowledge"
  local connection_file="${metadata_dir}/repo-connection.json"
  local template_file="${metadata_dir}/learned-payload.template.json"
  local hook_file="${metadata_dir}/emit-learned.sh"
  local hooks_dir="${metadata_dir}/hooks"
  local git_hooks_scripts_dir="${metadata_dir}/git-hooks"
  local backups_dir="${metadata_dir}/backups"
  local readme_file="${metadata_dir}/README.md"

  if [[ -f "$connection_file" && "$force" != "1" ]]; then
    die "repo already enabled at ${connection_file} (use --force to overwrite)"
  fi

  mkdir -p "$metadata_dir"
  mkdir -p "$hooks_dir" "$git_hooks_scripts_dir" "$backups_dir"

  local org_id agent_id runtime
  org_id="$(config_get "$config_path" "org_id")"
  agent_id="$(config_get "$config_path" "agent_id")"
  runtime="$(config_get "$config_path" "runtime")"

  local agents_csv
  agents_csv="$(IFS=, ; printf '%s' "${agents[*]-}")"
  write_repo_connection_file \
    "$connection_file" \
    "$org_id" \
    "$resolved_project_id" \
    "$resolved_repo_id" \
    "$agent_id" \
    "$runtime" \
    "$agents_csv" \
    "$config_path"
  write_repo_template_file "$template_file"
  write_repo_hook_script "$hook_file" "$config_path" "$resolved_project_id"
  write_commit_hook_script "${git_hooks_scripts_dir}/post-commit.sh" "$config_path" "$resolved_project_id"
  write_push_hook_script "${git_hooks_scripts_dir}/pre-push.sh" "$config_path" "$resolved_project_id"

  local hooks_path
  hooks_path="$(git_hooks_dir "$repo_root")"
  if [[ -n "$hooks_path" ]]; then
    install_managed_git_hook_wrapper "$repo_root" "$hooks_path" "post-commit" "$force" "${backups_dir}/git-hooks"
    install_managed_git_hook_wrapper "$repo_root" "$hooks_path" "pre-push" "$force" "${backups_dir}/git-hooks"
  else
    log "git hooks not installed (repo has no detected git hooks path)"
  fi

  local configured_claude="0"
  local agent
  for agent in "${agents[@]-}"; do
    if [[ "$agent" == "claude" ]]; then
      write_claude_post_tool_hook_script "${hooks_dir}/claude-post-tool-use.sh" "$config_path" "$resolved_project_id"
      configure_claude_settings_hook \
        "$repo_root" \
        "${repo_root}/.knowledge/hooks/claude-post-tool-use.sh" \
        "$force" \
        "${backups_dir}/claude" >/dev/null
      configured_claude="1"
    fi
  done

  cat >"$readme_file" <<EOF
# Knowledge Repo Hooks

This repository is connected to TKD.

Generated files:

- \`repo-connection.json\`: repo-level connection metadata
- \`learned-payload.template.json\`: starter payload template
- \`emit-learned.sh\`: helper script for submitting \`agent.learned\` events
- \`git-hooks/\`: managed hook targets invoked by Git wrappers
- \`hooks/\`: agent hook commands (e.g. Claude PostToolUse)

Installed integrations:

- Git wrappers: \`.git/hooks/post-commit\`, \`.git/hooks/pre-push\`
- Claude settings: \`.claude/settings.local.json\` -> \`.knowledge/hooks/claude-post-tool-use.sh\`

Example:

\`\`\`bash
./.knowledge/emit-learned.sh ./.knowledge/learned-payload.template.json 0.7
\`\`\`
EOF

  log "enabled repo hook scaffold at ${metadata_dir}"
  log "agents configured: ${agents_csv}"
  if [[ "$configured_claude" != "1" ]]; then
    log "note: automatic settings patch currently implemented for claude only"
  fi
}

cmd_status() {
  local repo_root=""
  local as_json="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo-root)
        repo_root="$2"
        shift 2
        ;;
      --json)
        as_json="1"
        shift 1
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        die "unknown status option: $1"
        ;;
    esac
  done

  require_cmd python3

  repo_root="$(determine_repo_root "$repo_root")"
  local connection_file="${repo_root}/.knowledge/repo-connection.json"
  [[ -f "$connection_file" ]] || die "repo not enabled: ${connection_file} not found"

  local hooks_path
  hooks_path="$(git_hooks_dir "$repo_root")"
  local post_commit_status="no"
  local pre_push_status="no"
  if [[ -n "$hooks_path" ]]; then
    post_commit_status="$(status_managed_git_hook "$hooks_path" "post-commit")"
    pre_push_status="$(status_managed_git_hook "$hooks_path" "pre-push")"
  fi
  local claude_status
  claude_status="$(status_claude_hook_configured "$repo_root" "${repo_root}/.knowledge/hooks/claude-post-tool-use.sh")"

  if [[ "$as_json" == "1" ]]; then
    python3 - "$connection_file" "$post_commit_status" "$pre_push_status" "$claude_status" <<'PY'
import json
import sys

connection_file = sys.argv[1]
post_commit = sys.argv[2]
pre_push = sys.argv[3]
claude_status = sys.argv[4]

with open(connection_file, "r", encoding="utf-8") as file:
    data = json.load(file)

data["integration_status"] = {
    "git_hooks": {
        "post_commit": post_commit,
        "pre_push": pre_push,
    },
    "agents": {
        "claude": claude_status,
    },
}

print(json.dumps(data, indent=2))
PY
    return
  fi

  python3 - "$connection_file" "$post_commit_status" "$pre_push_status" "$claude_status" <<'PY'
import json
import sys

connection_file = sys.argv[1]
post_commit = sys.argv[2]
pre_push = sys.argv[3]
claude_status = sys.argv[4]
with open(connection_file, "r", encoding="utf-8") as file:
    data = json.load(file)

print("knowledge enable status")
print(f"  schema:     {data.get('schema_version', '')}")
print(f"  enabled_at: {data.get('enabled_at', '')}")
print(f"  org:        {data.get('organization', {}).get('id', '')}")
print(f"  project:    {data.get('project', {}).get('id', '')}")
print(f"  repo:       {data.get('repo', {}).get('id', '')}")
print(f"  agents:     {', '.join(data.get('agents', []))}")
print("  git hooks:")
print(f"    post-commit: {post_commit}")
print(f"    pre-push:    {pre_push}")
print("  agent hooks:")
print(f"    claude:      {claude_status}")
PY
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

cmd_event() {
  local config_path="$DEFAULT_CONFIG_PATH"
  local event_type=""
  local payload_file=""
  local confidence=""
  local dry_run="0"
  local envelope_out=""
  local scope=""
  local project_id=""
  local repo_id=""

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
      --scope)
        scope="$2"
        shift 2
        ;;
      --project-id)
        project_id="$2"
        shift 2
        ;;
      --repo-id)
        repo_id="$2"
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
    "$envelope_out" \
    "$scope" \
    "$project_id" \
    "$repo_id"
}

cmd_assert() {
  local config_path="$DEFAULT_CONFIG_PATH"
  local assertion_file=""
  local knowledge_key=""
  local scope=""
  local project_id=""
  local repo_id=""
  local status="proposed"
  local assertion_id=""
  local parent_revision_id=""
  local confidence=""
  local dry_run="0"
  local envelope_out=""
  local -a influences=()

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
      --knowledge-key)
        knowledge_key="$2"
        shift 2
        ;;
      --scope)
        scope="$2"
        shift 2
        ;;
      --project-id)
        project_id="$2"
        shift 2
        ;;
      --repo-id)
        repo_id="$2"
        shift 2
        ;;
      --status)
        status="$2"
        shift 2
        ;;
      --assertion-id)
        assertion_id="$2"
        shift 2
        ;;
      --parent-revision-id)
        parent_revision_id="$2"
        shift 2
        ;;
      --influence)
        influences+=("$2")
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
  [[ -n "$knowledge_key" ]] || die "--knowledge-key is required"

  local resolved resolved_scope resolved_project_id resolved_repo_id
  resolved="$(resolve_context "$config_path" "$scope" "$project_id" "$repo_id")"
  resolved_scope="$(printf '%s\n' "$resolved" | sed -n '1p')"
  resolved_project_id="$(printf '%s\n' "$resolved" | sed -n '2p')"
  resolved_repo_id="$(printf '%s\n' "$resolved" | sed -n '3p')"

  local influences_blob=""
  local influence
  for influence in "${influences[@]-}"; do
    influences_blob+="${influence}"$'\n'
  done

  local wrapped_payload
  wrapped_payload="$(mktemp "${TMPDIR:-/tmp}/tkd-assertion.XXXXXX")"
  write_assertion_payload \
    "$assertion_file" \
    "$wrapped_payload" \
    "$knowledge_key" \
    "$resolved_scope" \
    "$resolved_project_id" \
    "$resolved_repo_id" \
    "$assertion_id" \
    "$parent_revision_id" \
    "$status" \
    "$influences_blob"

  submit_with_provenance \
    "$config_path" \
    "/v1/knowledge/assertions" \
    "knowledge_assertion.${status}" \
    "$wrapped_payload" \
    "$confidence" \
    "$dry_run" \
    "$envelope_out" \
    "$resolved_scope" \
    "$resolved_project_id" \
    "$resolved_repo_id"

  rm -f "$wrapped_payload"
}

cmd_promote() {
  local config_path="$DEFAULT_CONFIG_PATH"
  local knowledge_key=""
  local from_scope="repo"
  local to_scope="org"
  local project_id=""
  local repo_id=""
  local assertion_id=""
  local reason=""
  local confidence=""
  local dry_run="0"
  local envelope_out=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        config_path="$2"
        shift 2
        ;;
      --knowledge-key)
        knowledge_key="$2"
        shift 2
        ;;
      --from-scope)
        from_scope="$2"
        shift 2
        ;;
      --to-scope)
        to_scope="$2"
        shift 2
        ;;
      --project-id)
        project_id="$2"
        shift 2
        ;;
      --repo-id)
        repo_id="$2"
        shift 2
        ;;
      --assertion-id)
        assertion_id="$2"
        shift 2
        ;;
      --reason)
        reason="$2"
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
        die "unknown promote option: $1"
        ;;
    esac
  done

  [[ -n "$knowledge_key" ]] || die "--knowledge-key is required"
  assert_scope "$from_scope"
  assert_scope "$to_scope"
  if [[ "$from_scope" == "$to_scope" ]]; then
    die "--from-scope and --to-scope must differ"
  fi

  local resolved resolved_scope resolved_project_id resolved_repo_id
  resolved="$(resolve_context "$config_path" "$from_scope" "$project_id" "$repo_id")"
  resolved_scope="$(printf '%s\n' "$resolved" | sed -n '1p')"
  resolved_project_id="$(printf '%s\n' "$resolved" | sed -n '2p')"
  resolved_repo_id="$(printf '%s\n' "$resolved" | sed -n '3p')"

  local promotion_payload
  promotion_payload="$(mktemp "${TMPDIR:-/tmp}/tkd-promotion.XXXXXX")"
  write_promotion_payload \
    "$promotion_payload" \
    "$knowledge_key" \
    "$from_scope" \
    "$to_scope" \
    "$resolved_project_id" \
    "$resolved_repo_id" \
    "$assertion_id" \
    "$reason"

  submit_with_provenance \
    "$config_path" \
    "/v1/knowledge/promotions" \
    "knowledge_assertion.promoted" \
    "$promotion_payload" \
    "$confidence" \
    "$dry_run" \
    "$envelope_out" \
    "$resolved_scope" \
    "$resolved_project_id" \
    "$resolved_repo_id"

  rm -f "$promotion_payload"
}

cmd_lookup() {
  local config_path="$DEFAULT_CONFIG_PATH"
  local knowledge_key=""
  local scope=""
  local project_id=""
  local repo_id=""
  local assertion_id=""
  local timeline="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        config_path="$2"
        shift 2
        ;;
      --knowledge-key)
        knowledge_key="$2"
        shift 2
        ;;
      --scope)
        scope="$2"
        shift 2
        ;;
      --project-id)
        project_id="$2"
        shift 2
        ;;
      --repo-id)
        repo_id="$2"
        shift 2
        ;;
      --assertion-id)
        assertion_id="$2"
        shift 2
        ;;
      --timeline)
        timeline="1"
        shift 1
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        die "unknown lookup option: $1"
        ;;
    esac
  done

  require_cmd curl
  require_cmd python3

  [[ -f "$config_path" ]] || die "config not found: ${config_path}"
  local tkd_base_url
  tkd_base_url="$(config_get "$config_path" "tkd_base_url")"
  [[ -n "$tkd_base_url" ]] || die "tkd_base_url missing in config"

  if [[ "$timeline" == "1" ]]; then
    [[ -n "$assertion_id" ]] || die "--timeline requires --assertion-id"
    curl -fsS "${tkd_base_url%/}/v1/knowledge/assertions/${assertion_id}/timeline"
    printf '\n'
    return
  fi

  local resolved resolved_scope resolved_project_id resolved_repo_id
  resolved="$(resolve_context "$config_path" "$scope" "$project_id" "$repo_id")"
  resolved_scope="$(printf '%s\n' "$resolved" | sed -n '1p')"
  resolved_project_id="$(printf '%s\n' "$resolved" | sed -n '2p')"
  resolved_repo_id="$(printf '%s\n' "$resolved" | sed -n '3p')"

  local query
  query="$(python3 - "$knowledge_key" "$resolved_scope" "$resolved_project_id" "$resolved_repo_id" <<'PY'
import sys
from urllib.parse import urlencode

knowledge_key = sys.argv[1]
scope = sys.argv[2]
project_id = sys.argv[3]
repo_id = sys.argv[4]

params = {}
if knowledge_key:
    params["knowledge_key"] = knowledge_key
if scope:
    params["scope"] = scope
if project_id:
    params["project_id"] = project_id
if repo_id:
    params["repo_id"] = repo_id

print(urlencode(params))
PY
)"

  local url="${tkd_base_url%/}/v1/knowledge/assertions/current"
  if [[ -n "$query" ]]; then
    url+="?${query}"
  fi
  curl -fsS "$url"
  printf '\n'
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
    enable)
      cmd_enable "$@"
      ;;
    status)
      cmd_status "$@"
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
    promote)
      cmd_promote "$@"
      ;;
    lookup)
      cmd_lookup "$@"
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
