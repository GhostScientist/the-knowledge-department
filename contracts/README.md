# TKD Contracts

This directory is the source of truth for integration payload contracts.

Current schemas:

- `tkd.event.v0.schema.json`
- `tkd.assertion.payload.v0.schema.json`
- `tkd.promotion.payload.v0.schema.json`

When changing CLI payload shape, update these schemas first, then update:

1. `scripts/knowledge.sh`
2. `docs/mvp-agent-harness.md`
3. `docs/TESTING-WHAT-WE-HAVE.md`
