# TKD Agent Connection Harness (MVP)

## Goal

Establish a practical foundation for provenance-first agent integration into TKD.

The MVP should let any agent runtime (CLI agent, IDE agent, automation bot) do three things:

1. Bootstrap connection config quickly.
2. Prove it can talk to TKD endpoints.
3. Submit provenance-wrapped events and assertions.

## MVP Scope

Implemented scaffolding:

- `scripts/install-tkd-agent.sh`: installs `knowledge` and bootstraps local config.
- `scripts/knowledge.sh`: portable CLI for init, health checks, and submissions.
- `scripts/tkd-harness.sh`: compatibility alias that forwards to `knowledge`.
- `scripts/mock_tkd_server.py`: local test server for `/healthz`, `/v1/agents/events`, and `/v1/knowledge/assertions`.
- `scripts/smoke-test.sh`: end-to-end runnable demo.

Out of scope for MVP (next phases):

- Strong auth and signing keys.
- Custodian workflow orchestration.
- Persistent knowledge graph / reconciliation engine.
- Multi-tenant policy enforcement.

## Provenance Envelope (v0)

Every submission is wrapped in a normalized event envelope:

- `schema_version`
- `event_id`
- `event_type`
- `occurred_at`
- `agent.id`, `agent.runtime`
- `organization.id`
- `workspace.id` + best-effort git context
- `provenance.source`, `provenance.payload_sha256`, `provenance.rubric_version`, `provenance.confidence`
- `payload` (domain-specific body)

Why this matters:

- Assertions are not opaque writes.
- Downstream systems can audit origin, confidence, and policy lineage.
- Identical envelopes can support both prompt-policy and RL evaluation loops.

## Install and Connect Flow

From repository root:

```bash
./scripts/install-tkd-agent.sh \
  --tkd-base-url http://127.0.0.1:8787 \
  --agent-id codex-local \
  --runtime codex \
  --org-id watership \
  --workspace-id engineering
```

Then verify connectivity:

```bash
~/.tkd/bin/knowledge doctor
```

Submit event + assertion:

```bash
~/.tkd/bin/knowledge event \
  --event-type custodian.validator.checked \
  --payload-file examples/events/validator-check.json \
  --confidence 0.6

~/.tkd/bin/knowledge assert \
  --assertion-file examples/assertions/api-naming-convention.json \
  --confidence 0.6
```

Offline envelope preview:

```bash
~/.tkd/bin/knowledge event \
  --event-type custodian.validator.checked \
  --payload-file examples/events/validator-check.json \
  --confidence 0.6 \
  --dry-run
```

## Realistic Local Demo

Run one command in offline mode (works without local port binding):

```bash
./scripts/smoke-test.sh
```

Run online mode (starts mock server and sends HTTP requests):

```bash
./scripts/smoke-test.sh --online
```

Both modes install the harness into a temporary home directory and generate provenance-wrapped custodian event and assertion data.

## How This Maps to TKD Vision

- Provenance is required for every write.
- Narrow custodian actions can be represented as typed events.
- Confidence and rubric versions are explicit, enabling contradiction and reward-hacking analysis.
- The same harness contract can be adopted by many agent runtimes, similar to broad installer patterns.

## Next Iteration (V1)

1. Add signed envelopes (`agent_pubkey_id`, detached signatures).
2. Add idempotency keys and replay protection.
3. Add scoped API tokens with least-privilege access by custodian role.
4. Add append-only provenance store and auditor queries.
5. Add a compatibility shim for external agent frameworks.
