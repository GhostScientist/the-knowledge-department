# TKD API Tasks

## MVP Service Tasks

1. Implement HTTP server scaffold from `api/openapi.yaml`.
2. Validate inbound envelopes against `contracts/tkd.event.v0.schema.json`.
3. Route assertion payloads into PocketBase collections:
   - `provenance_events`
   - `assertions`
   - `assertion_revisions`
   - `influence_edges`
4. Implement promotion event persistence and policy checks.
5. Implement current + timeline reads with scope filters.
6. Add API-level idempotency key handling.
7. Add auth middleware for scoped write permissions.
