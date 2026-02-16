# TESTING WHAT WE HAVE

Use this worksheet to validate the current TKD scaffold and capture findings that should drive refinement.

## How To Use This Document

1. Run each test in order.
2. Record actual behavior in the **Notes** section under each test.
3. Mark failures and unexpected behavior explicitly.
4. Convert notes into backlog items after a full pass.

---

## Test 1: CLI Install And Config Bootstrap

### Goal

Verify installer writes `knowledge`, compatibility alias, and config with scoped defaults.

### Command

```bash
./scripts/install-tkd-agent.sh \
  --tkd-base-url http://127.0.0.1:8787 \
  --agent-id test-agent \
  --runtime codex \
  --org-id test-org \
  --workspace-id test-workspace \
  --project-id test-project \
  --default-scope repo \
  --force
```

### Expected

- `~/.tkd/bin/knowledge` exists.
- `~/.tkd/bin/tkd-harness` exists and forwards to `knowledge`.
- `~/.tkd/config.json` includes `project_id` and `default_scope`.

### Notes

- Status:
- Observations:
- Tweaks/Refinements:

---

## Test 2: CLI Help Surface

### Goal

Confirm command surface includes `event`, `assert`, `promote`, and `lookup`.

### Command

```bash
~/.tkd/bin/knowledge --help
```

### Expected

- Help output includes all core commands and scoped options.

### Notes

- Status:
- Observations:
- Tweaks/Refinements:

---

## Test 2B: Repo Hook Scaffold Enable And Status

### Goal

Verify repo-level hook scaffolding is generated for selected agents.

### Command

```bash
~/.tkd/bin/knowledge enable --all-agents --force
~/.tkd/bin/knowledge status
```

### Expected

- A `.knowledge/` directory is created in repo root.
- `.knowledge/repo-connection.json` exists with org/project/repo ids.
- `.knowledge/emit-learned.sh` exists and is executable.
- `.git/hooks/post-commit` and `.git/hooks/pre-push` exist with `# managed-by: knowledge`.
- `.claude/settings.local.json` contains a `hooks.PostToolUse` command entry to `.knowledge/hooks/claude-post-tool-use.sh`.
- `knowledge status` prints enabled scope and agent list.

### Notes

- Status:
- Observations:
- Tweaks/Refinements:

---

## Test 3: Offline Event Envelope Generation

### Goal

Validate provenance envelope structure for generic custodian events.

### Command

```bash
~/.tkd/bin/knowledge event \
  --event-type custodian.validator.checked \
  --payload-file examples/events/validator-check.json \
  --scope repo \
  --project-id engineering-api \
  --confidence 0.6 \
  --dry-run
```

### Expected

- Output is valid JSON.
- `workspace.scope` is `repo`.
- `workspace.project_id`, `workspace.repo_id`, and git context are present.

### Notes

- Status:
- Observations:
- Tweaks/Refinements:

---

## Test 4: Offline Scoped Assertion Envelope

### Goal

Validate assertion wrapper payload with scope and knowledge identity.

### Command

```bash
~/.tkd/bin/knowledge assert \
  --assertion-file examples/assertions/api-naming-convention.json \
  --knowledge-key engineering.api.json_naming \
  --scope repo \
  --project-id engineering-api \
  --status proposed \
  --confidence 0.6 \
  --dry-run
```

### Expected

- Payload includes `schema_version: tkd.assertion.payload.v0`.
- Payload includes `knowledge_key`, `scope`, `project_id`, and `content`.

### Notes

- Status:
- Observations:
- Tweaks/Refinements:

---

## Test 5: Offline Promotion Envelope

### Goal

Validate repo-to-org promotion event shape.

### Command

```bash
~/.tkd/bin/knowledge promote \
  --knowledge-key engineering.api.json_naming \
  --from-scope repo \
  --to-scope org \
  --project-id engineering-api \
  --reason "ready for org baseline" \
  --confidence 0.75 \
  --dry-run
```

### Expected

- Event type is `knowledge_assertion.promoted`.
- Payload contains `from_scope`, `to_scope`, `knowledge_key`, and reason.

### Notes

- Status:
- Observations:
- Tweaks/Refinements:

---

## Test 6: End-To-End Offline Smoke Test

### Goal

Confirm the full local scaffold works without network binding.

### Command

```bash
./scripts/smoke-test.sh
```

### Expected

- Script exits successfully.
- Event, assertion, and promotion envelopes are printed.

### Notes

- Status:
- Observations:
- Tweaks/Refinements:

---

## Test 7: Online Mock Backend Start

### Goal

Verify mock server boots and exposes health endpoint.

### Command

```bash
python3 scripts/mock_tkd_server.py --host 127.0.0.1 --port 8787
curl http://127.0.0.1:8787/healthz
```

### Expected

- Health payload includes counts for assertions, revisions, events, promotions.

### Notes

- Status:
- Observations:
- Tweaks/Refinements:

---

## Test 8: End-To-End Online Flow

### Goal

Validate persistence, lookup, and timeline behavior.

### Command

```bash
./scripts/smoke-test.sh --online
```

### Expected

- Repo assertion accepted and returns `assertion_id` + `revision_id`.
- Second repo revision increments `revision_number`.
- Org assertion accepted under `scope=org`.
- Promotion event accepted.
- `lookup` returns current records for repo and org.
- Timeline returns multiple revisions for repo assertion.

### Notes

- Status:
- Observations:
- Tweaks/Refinements:

---

## Test 9: Repo-vs-Org Retrieval Semantics

### Goal

Validate practical separation and fallback assumptions.

### Manual Steps

1. Query repo scope by key.
2. Query org scope by key.
3. Compare record content and revision pointers.
4. Decide expected fallback policy for app clients.

### Expected

- Repo and org results are separable by query filters.
- Contradictions can be surfaced rather than silently merged.

### Notes

- Status:
- Observations:
- Tweaks/Refinements:

---

## Test 10: Influence Chain Integrity

### Goal

Ensure revision influence links are captured for explainability.

### Manual Steps

1. Submit a second revision with `--influence supersedes:<REV_ID>`.
2. Query timeline for that assertion.
3. Inspect revision `influences` payload.

### Expected

- Influence metadata appears in revision records.
- Parent revision and influence references are traceable.

### Notes

- Status:
- Observations:
- Tweaks/Refinements:

---

## Test 11: PocketBase Model Review

### Goal

Validate schema blueprint matches intended workflows.

### Files To Review

- `pocketbase/collections/assertions.collection.json`
- `pocketbase/collections/assertion_revisions.collection.json`
- `pocketbase/collections/provenance_events.collection.json`
- `pocketbase/collections/influence_edges.collection.json`
- `pocketbase/collections/custodian_decisions.collection.json`
- `docs/pocketbase-knowledge-model.md`

### Expected

- Required fields for scope, revisioning, and provenance exist.
- Indexes support `current`, `timeline`, and key-based lookups.

### Notes

- Status:
- Observations:
- Tweaks/Refinements:

---

## Test 12: Phase-2 Scaffold Sanity

### Goal

Verify new product/research/agent scaffold paths exist and are discoverable.

### Files To Review

- `services/tkd-api/README.md`
- `services/tkd-api/api/openapi.yaml`
- `agents/custodians/README.md`
- `research/watership/README.md`
- `research/watership/scenarios/engineering-api-naming-conflict.json`
- `research/evals/README.md`
- `docs/REPO-STRUCTURE.md`

### Expected

- All scaffold paths exist and align with current roadmap phase.
- Team can identify where to place new API, custodian, and Watership code without ambiguity.

### Notes

- Status:
- Observations:
- Tweaks/Refinements:

---

## Final Summary Notes

### Biggest Risks Found

-

### Highest-Value Next Tweaks

-

### Decisions To Lock Before Next Build

-
