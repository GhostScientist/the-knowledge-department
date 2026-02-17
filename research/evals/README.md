# Evaluation Runs Scaffold

Use this folder for experiment definitions and result captures.

## Suggested Structure

- `runs/`: immutable run outputs keyed by timestamp or run id.
- `configs/`: run configuration files (policy type, rubric version, scenario set).
- `reports/`: aggregated summaries for publication and iteration.

## Minimum Run Metadata

- `run_id`
- `timestamp`
- `policy_mode` (`prompt` or `rl`)
- `scenario_ids[]`
- `rubric_version`
- `scores`
- `failure_modes_observed[]`

This keeps prompt-policy and RL-policy runs comparable under identical reward conditions.

## Added Assets

- `configs/validator-baseline-v1.json`: baseline local run config.
- `WATERSHIP-RLHF-EXECUTION-PLAN.md`: top-3 execution priorities for non-naive RLHF progress.
- `MANUAL-REDTEAM-PLAYBOOK.md`: manual adversarial testing protocol to complement automated checks.
