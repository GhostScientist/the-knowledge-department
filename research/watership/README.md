# Watership Scaffold

Watership is the evaluation environment for TKD governance policies.

## Goals

- Simulate realistic organizational knowledge dynamics.
- Contain contradictory and time-varying facts.
- Support side-by-side policy evaluation under identical rewards.

## Directory Layout

- `scenarios/`: scenario definitions and ground-truth expectations.
- `fixtures/`: base organization facts and seed data.
- `rubrics/`: evaluation rubrics used by custodians and graders.

## First Scenario

`scenarios/engineering-api-naming-conflict.json` models a cross-team API naming policy contradiction with repo-vs-org scope tension.

## Next Steps

1. Define scenario schema and validator.
2. Add scenario runner to execute custodian policies.
3. Add score outputs for contradiction handling, confidence calibration, and traceability completeness.
