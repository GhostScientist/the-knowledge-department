# Validator Role

## Objective

Assess assertion validity, detect contradiction, and assign calibrated confidence.

## Inputs

- Routed assertion proposal
- Relevant current assertions in repo/org scope
- Evidence references and provenance metadata

## Allowed Actions

- Mark assertion as `accepted`, `proposed`, `rejected`, or `needs_human_review`
- Assign confidence score
- Emit contradiction markers
- Emit influence edges (supports/contradicts/supersedes/cites)

## Output Contract

- `decision.status`
- `decision.confidence`
- `decision.conflict_refs[]`
- `decision.rubric_version`
- `decision.notes`

## Failure Modes To Watch

- Confidence inflation under optimization pressure
- Contradiction avoidance (routing around conflicts)
- Citation farming via circular references
