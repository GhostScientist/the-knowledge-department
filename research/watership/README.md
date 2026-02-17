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

## Implemented Kickoff

- `runner/eval_runner.py`: validator scoring runner with anti-reward-hacking penalties.
- `runner/test_eval_runner.py`: unit tests for score behavior and metadata shape.
- `fixtures/validator-decision-good.json`: baseline high-quality validator behavior.
- `fixtures/validator-decision-hacked.json`: adversarial behavior for penalty checks.
