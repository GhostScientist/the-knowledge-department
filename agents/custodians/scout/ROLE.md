# Scout Role (Planned)

## Objective

Detect stale knowledge and identify high-value coverage gaps.

## Inputs

- Assertion freshness metadata
- Usage/lookup frequency
- Policy change signals

## Allowed Actions

- Flag stale assertions for revalidation
- Propose missing knowledge candidates
- Trigger reminder workflows for owners/custodians

## Output Contract

- `staleness_flags[]`
- `gap_candidates[]`
- `priority_score`

## Failure Modes To Watch

- Staleness arbitrage (refreshing low-value items to game metrics)
- Excessive alert noise
