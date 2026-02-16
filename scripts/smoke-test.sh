#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MOCK_HOST="127.0.0.1"
MOCK_PORT="${TKD_MOCK_PORT:-8787}"
MODE="offline"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tkd-smoke.XXXXXX")"
MOCK_LOG="${TMP_DIR}/tkd-mock-events.jsonl"
MOCK_STDOUT="${TMP_DIR}/tkd-mock.stdout.log"
TEST_HOME="${TMP_DIR}/home"
CLI_PATH="${TEST_HOME}/.tkd/bin/knowledge"
EVENT_ENVELOPE="${TMP_DIR}/validator-event.envelope.json"
ASSERTION_ENVELOPE="${TMP_DIR}/assertion.envelope.json"

usage() {
  cat <<'EOF'
Usage:
  smoke-test.sh [--offline|--online]

Modes:
  --offline  Build provenance envelopes with --dry-run (default)
  --online   Run local mock server and submit over HTTP
EOF
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
    --log-file "${MOCK_LOG}" >"${MOCK_STDOUT}" 2>&1 &
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
  --workspace-id "engineering"

if [[ "$MODE" == "online" ]]; then
  HOME="${TEST_HOME}" "${CLI_PATH}" doctor
  HOME="${TEST_HOME}" "${CLI_PATH}" event \
    --event-type "custodian.validator.checked" \
    --payload-file "${REPO_ROOT}/examples/events/validator-check.json" \
    --confidence "0.6"
  HOME="${TEST_HOME}" "${CLI_PATH}" assert \
    --assertion-file "${REPO_ROOT}/examples/assertions/api-naming-convention.json" \
    --confidence "0.6"
  echo
  echo "Smoke test complete (online mode)."
  echo "Mock log file: ${MOCK_LOG}"
  echo
  cat "${MOCK_LOG}"
  exit 0
fi

HOME="${TEST_HOME}" "${CLI_PATH}" event \
  --event-type "custodian.validator.checked" \
  --payload-file "${REPO_ROOT}/examples/events/validator-check.json" \
  --confidence "0.6" \
  --dry-run \
  --envelope-out "${EVENT_ENVELOPE}" >/dev/null

HOME="${TEST_HOME}" "${CLI_PATH}" assert \
  --assertion-file "${REPO_ROOT}/examples/assertions/api-naming-convention.json" \
  --confidence "0.6" \
  --dry-run \
  --envelope-out "${ASSERTION_ENVELOPE}" >/dev/null

echo
echo "Smoke test complete (offline mode)."
echo "Event envelope: ${EVENT_ENVELOPE}"
echo "Assertion envelope: ${ASSERTION_ENVELOPE}"
echo
cat "${EVENT_ENVELOPE}"
echo
cat "${ASSERTION_ENVELOPE}"
