# TKD Agent Connection Harness (MVP)

## Goal

Establish a provenance-first, scope-aware connection layer between agents and TKD.

The MVP allows any agent runtime (CLI, IDE, automation bot) to:

1. Bootstrap a TKD connection.
2. Emit provenance-wrapped events.
3. Submit scoped knowledge assertions (`repo` or `org`) as immutable revisions.
4. Query current state and revision timeline.
5. Propose promotion from repo knowledge to org knowledge.

## Implemented Scaffolding

- `scripts/install-tkd-agent.sh`: installs `knowledge` and bootstraps config.
- `scripts/knowledge.sh`: CLI for init, enable/status, doctor, event/assert/promote/lookup.
- `scripts/tkd-harness.sh`: compatibility alias forwarding to `knowledge`.
- `scripts/mock_tkd_server.py`: local stateful server with assertion/revision storage.
- `scripts/smoke-test.sh`: offline and online end-to-end validation.

## Knowledge Scope Model

- `repo` scope: project/repository-specific learning.
- `org` scope: organization-wide defaults and promoted policy knowledge.

Default behavior is repo-first. Promotion is explicit via `knowledge promote`.

## Provenance Envelope (v0)

Every submission is wrapped as `tkd.event.v0` and includes:

- Event identity: `event_id`, `event_type`, `occurred_at`.
- Actor identity: `agent.id`, `agent.runtime`.
- Organization: `organization.id`.
- Workspace context:
  - `workspace.id`
  - `workspace.project_id`
  - `workspace.scope`
  - `workspace.repo_id`
  - `workspace.repo_remote`, `workspace.repo_branch`, `workspace.repo_commit`, `workspace.repo_root`
- Provenance:
  - `provenance.source`
  - `provenance.payload_sha256`
  - `provenance.rubric_version`
  - `provenance.confidence`
- Domain payload: `payload`

## Assertion Payload (v0)

`knowledge assert` wraps domain content inside `tkd.assertion.payload.v0`:

- `knowledge_key`
- `scope`
- `status`
- `project_id` / `repo_id`
- `assertion_id` (optional logical id)
- `parent_revision_id` (optional revision ancestry)
- `influences` (`TYPE:REF` edges)
- `content` (your domain assertion body)

This gives wiki-like revision chains and explicit influence links.

## Install and Connect

```bash
./scripts/install-tkd-agent.sh \
  --tkd-base-url http://127.0.0.1:8787 \
  --agent-id codex-local \
  --runtime codex \
  --org-id watership \
  --workspace-id engineering \
  --project-id engineering-api \
  --default-scope repo

~/.tkd/bin/knowledge doctor

# Create repo-local hook scaffold (.knowledge/)
~/.tkd/bin/knowledge enable --all-agents --force

# Inspect current repo hook status
~/.tkd/bin/knowledge status
```

`knowledge enable` currently performs hook alignment by:

- Creating `.knowledge/` repo integration files.
- Installing managed Git wrappers at `.git/hooks/post-commit` and `.git/hooks/pre-push`.
- Writing hook targets under `.knowledge/git-hooks/`.
- Configuring Claude project hooks in `.claude/settings.local.json` (`PostToolUse` command hook).
- Recording backup copies before overwriting managed files when `--force` is used.

## Submit and Query

Submit a repo-scoped assertion:

```bash
~/.tkd/bin/knowledge assert \
  --assertion-file examples/assertions/api-naming-convention.json \
  --knowledge-key engineering.api.json_naming \
  --scope repo \
  --project-id engineering-api \
  --confidence 0.6
```

Submit a follow-up revision with explicit ancestry:

```bash
~/.tkd/bin/knowledge assert \
  --assertion-file examples/assertions/api-naming-convention-v2.json \
  --knowledge-key engineering.api.json_naming \
  --scope repo \
  --project-id engineering-api \
  --assertion-id <ASSERTION_ID> \
  --parent-revision-id <REVISION_ID> \
  --influence supersedes:<REVISION_ID>
```

Lookup current assertions:

```bash
~/.tkd/bin/knowledge lookup \
  --scope repo \
  --project-id engineering-api \
  --knowledge-key engineering.api.json_naming
```

Lookup timeline:

```bash
~/.tkd/bin/knowledge lookup --assertion-id <ASSERTION_ID> --timeline
```

Promote repo knowledge toward org scope:

```bash
~/.tkd/bin/knowledge promote \
  --knowledge-key engineering.api.json_naming \
  --assertion-id <ASSERTION_ID> \
  --from-scope repo \
  --to-scope org \
  --project-id engineering-api \
  --reason "Validated across services"
```

## Local Demo

Offline mode (works without local port binding):

```bash
./scripts/smoke-test.sh
```

Online mode (uses mock server and query endpoints):

```bash
./scripts/smoke-test.sh --online
```

## Next Iteration

1. Add signed envelopes (`agent_pubkey_id`, detached signature).
2. Add idempotency keys and replay protection.
3. Add scoped API tokens by custodian role.
4. Add redaction pipeline before persistence.
5. Replace mock storage with PocketBase-backed service.
