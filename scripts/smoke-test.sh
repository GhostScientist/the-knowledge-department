#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MOCK_HOST="127.0.0.1"
MOCK_PORT="${TKD_MOCK_PORT:-8787}"
MODE="offline"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tkd-smoke.XXXXXX")"
MOCK_LOG="${TMP_DIR}/tkd-mock-events.jsonl"
MOCK_STATE="${TMP_DIR}/tkd-mock-state.json"
MOCK_STDOUT="${TMP_DIR}/tkd-mock.stdout.log"
TEST_HOME="${TMP_DIR}/home"
CLI_PATH="${TEST_HOME}/.tkd/bin/knowledge"
ENABLE_REPO="${TMP_DIR}/demo-repo"
ENABLE_STATUS="${TMP_DIR}/enable-status.txt"

EVENT_ENVELOPE="${TMP_DIR}/validator-event.envelope.json"
ASSERTION_ENVELOPE="${TMP_DIR}/repo-assertion.envelope.json"
PROMOTION_ENVELOPE="${TMP_DIR}/promotion.envelope.json"

usage() {
  cat <<'USAGE'
Usage:
  smoke-test.sh [--offline|--online]

Modes:
  --offline  Build scoped envelopes with --dry-run (default)
  --online   Run local mock server and submit/query HTTP flows
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline)
      MODE="offline"
      shift 1
      ;;
    --online)
      MODE="online"
      shift 1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

mkdir -p "${TEST_HOME}"

if [[ "$MODE" == "online" ]]; then
  python3 "${SCRIPT_DIR}/mock_tkd_server.py" \
    --host "${MOCK_HOST}" \
    --port "${MOCK_PORT}" \
    --log-file "${MOCK_LOG}" \
    --state-file "${MOCK_STATE}" >"${MOCK_STDOUT}" 2>&1 &
  SERVER_PID="$!"
  sleep 0.5

  if ! kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    echo "Mock server failed to start. Logs:" >&2
    cat "${MOCK_STDOUT}" >&2
    exit 1
  fi

  if ! curl -fsS "http://${MOCK_HOST}:${MOCK_PORT}/healthz" >/dev/null 2>&1; then
    echo "Mock server is not reachable at http://${MOCK_HOST}:${MOCK_PORT}/healthz" >&2
    cat "${MOCK_STDOUT}" >&2
    exit 1
  fi
fi

HOME="${TEST_HOME}" "${SCRIPT_DIR}/install-tkd-agent.sh" \
  --tkd-base-url "http://${MOCK_HOST}:${MOCK_PORT}" \
  --agent-id "smoke-agent" \
  --runtime "codex" \
  --org-id "watership" \
  --workspace-id "engineering" \
  --project-id "engineering-api" \
  --default-scope "repo"

mkdir -p "${ENABLE_REPO}"
git -C "${ENABLE_REPO}" init >/dev/null 2>&1
HOME="${TEST_HOME}" "${CLI_PATH}" enable \
  --repo-root "${ENABLE_REPO}" \
  --project-id "engineering-api" \
  --all-agents \
  --force >/dev/null
HOME="${TEST_HOME}" "${CLI_PATH}" status \
  --repo-root "${ENABLE_REPO}" >"${ENABLE_STATUS}"

if [[ "$MODE" == "online" ]]; then
  HOME="${TEST_HOME}" "${CLI_PATH}" doctor

  HOME="${TEST_HOME}" "${CLI_PATH}" event \
    --event-type "custodian.validator.checked" \
    --payload-file "${REPO_ROOT}/examples/events/validator-check.json" \
    --scope "repo" \
    --project-id "engineering-api" \
    --confidence "0.6" >/dev/null

  repo_assert_resp="$(HOME="${TEST_HOME}" "${CLI_PATH}" assert \
    --assertion-file "${REPO_ROOT}/examples/assertions/api-naming-convention.json" \
    --knowledge-key "engineering.api.json_naming" \
    --scope "repo" \
    --project-id "engineering-api" \
    --confidence "0.6")"

  repo_assert_id="$(python3 - "$repo_assert_resp" <<'PY'
import json, sys
print(json.loads(sys.argv[1]).get("assertion_id", ""))
PY
)"

  repo_revision_id="$(python3 - "$repo_assert_resp" <<'PY'
import json, sys
print(json.loads(sys.argv[1]).get("revision_id", ""))
PY
)"

  second_assert_resp="$(HOME="${TEST_HOME}" "${CLI_PATH}" assert \
    --assertion-file "${REPO_ROOT}/examples/assertions/api-naming-convention-v2.json" \
    --knowledge-key "engineering.api.json_naming" \
    --scope "repo" \
    --project-id "engineering-api" \
    --assertion-id "$repo_assert_id" \
    --parent-revision-id "$repo_revision_id" \
    --influence "supersedes:${repo_revision_id}" \
    --confidence "0.82")"

  org_assert_resp="$(HOME="${TEST_HOME}" "${CLI_PATH}" assert \
    --assertion-file "${REPO_ROOT}/examples/assertions/api-naming-convention-v2.json" \
    --knowledge-key "engineering.api.json_naming" \
    --scope "org" \
    --confidence "0.9")"

  promote_resp="$(HOME="${TEST_HOME}" "${CLI_PATH}" promote \
    --knowledge-key "engineering.api.json_naming" \
    --assertion-id "$repo_assert_id" \
    --from-scope "repo" \
    --to-scope "org" \
    --project-id "engineering-api" \
    --reason "Validated across three services and ready for org baseline." \
    --confidence "0.75")"

  repo_lookup="$(HOME="${TEST_HOME}" "${CLI_PATH}" lookup \
    --scope "repo" \
    --project-id "engineering-api" \
    --knowledge-key "engineering.api.json_naming")"

  org_lookup="$(HOME="${TEST_HOME}" "${CLI_PATH}" lookup \
    --scope "org" \
    --knowledge-key "engineering.api.json_naming")"

  timeline="$(HOME="${TEST_HOME}" "${CLI_PATH}" lookup \
    --assertion-id "$repo_assert_id" \
    --timeline)"

  echo
  echo "Smoke test complete (online mode)."
  echo "Mock log file:   ${MOCK_LOG}"
  echo "Mock state file: ${MOCK_STATE}"
  echo "Enable status:   ${ENABLE_STATUS}"
  echo
  cat "${ENABLE_STATUS}"
  echo
  echo "repo_assert_resp:"
  echo "$repo_assert_resp"
  echo
  echo "second_assert_resp:"
  echo "$second_assert_resp"
  echo
  echo "org_assert_resp:"
  echo "$org_assert_resp"
  echo
  echo "promote_resp:"
  echo "$promote_resp"
  echo
  echo "repo_lookup:"
  echo "$repo_lookup"
  echo
  echo "org_lookup:"
  echo "$org_lookup"
  echo
  echo "timeline:"
  echo "$timeline"
  exit 0
fi

HOME="${TEST_HOME}" "${CLI_PATH}" event \
  --event-type "custodian.validator.checked" \
  --payload-file "${REPO_ROOT}/examples/events/validator-check.json" \
  --scope "repo" \
  --project-id "engineering-api" \
  --confidence "0.6" \
  --dry-run \
  --envelope-out "${EVENT_ENVELOPE}" >/dev/null

HOME="${TEST_HOME}" "${CLI_PATH}" assert \
  --assertion-file "${REPO_ROOT}/examples/assertions/api-naming-convention.json" \
  --knowledge-key "engineering.api.json_naming" \
  --scope "repo" \
  --project-id "engineering-api" \
  --confidence "0.6" \
  --dry-run \
  --envelope-out "${ASSERTION_ENVELOPE}" >/dev/null

HOME="${TEST_HOME}" "${CLI_PATH}" promote \
  --knowledge-key "engineering.api.json_naming" \
  --from-scope "repo" \
  --to-scope "org" \
  --project-id "engineering-api" \
  --reason "Promote after validator convergence" \
  --confidence "0.75" \
  --dry-run \
  --envelope-out "${PROMOTION_ENVELOPE}" >/dev/null

echo
echo "Smoke test complete (offline mode)."
echo "Event envelope:      ${EVENT_ENVELOPE}"
echo "Assertion envelope:  ${ASSERTION_ENVELOPE}"
echo "Promotion envelope:  ${PROMOTION_ENVELOPE}"
echo "Enable status:       ${ENABLE_STATUS}"
echo
cat "${ENABLE_STATUS}"
echo
cat "${EVENT_ENVELOPE}"
echo
cat "${ASSERTION_ENVELOPE}"
echo
cat "${PROMOTION_ENVELOPE}"
