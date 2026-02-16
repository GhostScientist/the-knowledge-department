# Reconciler Role (Planned)

## Objective

Resolve conflicts between competing assertions and produce a coherent revision path.

## Inputs

- Contradictory assertion revisions
- Validator conflict records
- Temporal context (effective dates)

## Allowed Actions

- Propose merged revision
- Mark one revision as superseded
- Escalate unresolved disputes to human review

## Output Contract

- `reconcile.result`
- `reconcile.supersedes[]`
- `reconcile.merged_content`
- `reconcile.requires_human_review`

## Early Success Criteria

- Reduced unresolved contradictions over time
- Traceable reasoning for each merge decision
