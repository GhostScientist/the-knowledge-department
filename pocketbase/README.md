# PocketBase Schema Blueprint

This folder contains a starter schema blueprint for implementing TKD on PocketBase.

## Files

- `collections/assertions.collection.json`
- `collections/assertion_revisions.collection.json`
- `collections/provenance_events.collection.json`
- `collections/influence_edges.collection.json`
- `collections/custodian_decisions.collection.json`

These files define the collection contract for:

- Scoped assertions (`repo` vs `org`)
- Immutable revision history
- Append-only provenance events
- Influence graph edges
- Custodian decision records

## Notes

- This is a scaffold contract and not an auto-applied migration.
- Use these files as the source of truth when creating PocketBase migrations and API rules.
- Keep `assertion_revisions` immutable; update `assertions.current_revision` only.
