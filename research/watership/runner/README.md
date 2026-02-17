# Watership Runner (Validator v1 RLHF)

This runner scores custodian decisions under a shared rubric so prompt policies and RL policies can be compared without reward drift.

## Why this matters

- Keeps **policy optimization apples-to-apples** (`prompt` vs `rl`).
- Encodes anti-reward-hacking penalties directly into scoring.
- Produces run metadata that drops directly into `research/evals/runs/`.

## Quickstart

```bash
python3 research/watership/runner/eval_runner.py \
  --scenario research/watership/scenarios/engineering-api-naming-conflict.json \
  --decision research/watership/fixtures/validator-decision-good.json \
  --policy-mode prompt \
  --run-id run-prompt-baseline-001 \
  --output research/evals/runs/run-prompt-baseline-001.json
```

## Scoring dimensions

1. Contradiction detection
2. Confidence calibration
3. Traceability completeness
4. Reward-hacking penalties (subtractive)

## Failure modes flagged

- `contradiction_avoidance`
- `confidence_inflation`
- `citation_farming`

## Tests

```bash
cd research/watership/runner
python3 -m unittest -v test_eval_runner.py
```
