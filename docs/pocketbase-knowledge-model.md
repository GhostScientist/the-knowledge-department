# PocketBase Knowledge Model (MVP Draft)

## Why Repo-First + Org Promotion

TKD should distinguish:

- **Project knowledge**: context that is valid only for one codebase or service.
- **Org knowledge**: broad defaults, policies, and conventions.

The recommended default is:

1. Capture assertions at `repo` scope.
2. Validate and reconcile over time.
3. Promote qualified assertions to `org` scope explicitly.

## Core Collections

The starter schema lives in `pocketbase/collections/`:

- `assertions`: logical assertion identity and current revision pointer.
- `assertion_revisions`: immutable revision chain.
- `provenance_events`: append-only agent contributions and envelope metadata.
- `influence_edges`: explicit links (`supports`, `supersedes`, `contradicts`, etc).
- `custodian_decisions`: validator/reconciler/scout decisions with rubric context.

## Query Model

### Current truth

Resolve through `assertions.current_revision`.

### Timeline / audit

Read full revision sequence from `assertion_revisions` for one assertion id.

### Explainability

For a revision:

1. Read source `provenance_events`.
2. Traverse `influence_edges`.
3. Include `custodian_decisions` and rubric metadata.

### Scope resolution

For runtime retrieval:

1. Check `repo` assertion by `knowledge_key + project_id`.
2. If none, fall back to `org` assertion by `knowledge_key + org_id`.
3. If both exist and conflict, surface contradiction state to user/custodian.

## Evolution Rules

- Revisions are immutable.
- Updates create new `assertion_revisions` rows.
- `assertions.current_revision` changes atomically with each accepted revision.
- Promotion (`repo -> org`) creates a new org-scoped assertion/revision pair; do not mutate scope in place.

## CLI Contract Mapping

`knowledge` command writes envelope metadata that maps directly to these collections:

- Envelope -> `provenance_events`
- Assertion payload -> `assertion_revisions`
- Logical id pointer updates -> `assertions`
- `--influence TYPE:REF` -> `influence_edges`
- Validator output events -> `custodian_decisions`

## Next Implementation Steps

1. Generate PocketBase migrations from the JSON collection blueprint.
2. Add API rules per scope (`repo` write constraints, org promotion constraints).
3. Enforce immutability and ancestry checks in PocketBase hooks.
4. Add read API endpoints for `current`, `timeline`, and `explain` queries.
