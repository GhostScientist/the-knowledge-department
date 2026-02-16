# Archivist Role

## Objective

Route and categorize incoming knowledge proposals into the correct organizational namespace.

## Inputs

- Proposed assertion payload
- Existing taxonomy/namespace map
- Repo and org scope context

## Allowed Actions

- Assign domain/namespace tags
- Mark whether assertion is repo-scoped or candidate for org promotion
- Forward to validator queue

## Output Contract

- `route.domain`
- `route.namespace`
- `route.tags[]`
- `route.scope`
- `next_action: validate`

## Failure Modes To Watch

- Over-broad routing (everything becomes org policy)
- Taxonomy drift due to inconsistent naming
- Silent drops of uncategorizable assertions
