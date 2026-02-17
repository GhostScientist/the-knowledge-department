# Watership Eval + RL/RLHF: Top 3 Frontier Tasks (Executed Kickoff)

This document names the three highest-leverage tasks for making TKD's Watership research program real (not naive), and records what has already been executed in this repo to begin each one.

## Task 1 — Hardening the Reward Surface (anti-hacking by design)

### Why this is top-3
Naive reward design will collapse under optimization pressure. We need a reward surface that makes gaming expensive and visible.

### Scope
- Formalize scored dimensions + explicit penalties.
- Track failure-mode taxonomy as first-class output (`failure_modes_observed`).
- Keep reward function identical across prompt-policy and RL runs.

### Executed now
- Added runnable scorer that applies weighted rubric + penalties.
- Added failure-mode flags for contradiction avoidance, confidence inflation, and citation farming.
- Added sample "good" and "hacked" decisions to validate that penalties trigger in realistic ways.

---

## Task 2 — Reproducible Evaluation Pipeline (prompt vs RL comparability)

### Why this is top-3
Without consistent run metadata and deterministic scoring, comparisons are anecdotal and non-publishable.

### Scope
- Build a scenario+decision runner that emits immutable run JSON.
- Require minimum metadata (`run_id`, policy mode, rubric version, scenario ids, scores, failure modes).
- Make generated artifacts drop into `research/evals/runs/` structure.

### Executed now
- Added `eval_runner.py` CLI with stable report shape.
- Added runner README and usage for baseline execution.
- Added an example run config to standardize local experiment invocation.

---

## Task 3 — Testing Discipline for RLHF Loop (automated + manual red teaming)

### Why this is top-3
Frontier-grade RLHF requires both automated regression checks and human adversarial probes. Purely automated checks miss strategic exploit behaviors.

### Scope
- Automated tests for score behavior, penalties, and metadata integrity.
- Manual test playbook focused on adversarial policy behaviors and reward-model blind spots.
- Explicit pass/fail evidence capture for iteration cycles.

### Executed now
- Added unit tests that assert high score for quality behavior and low score + failure mode tagging for hacked behavior.
- Added a manual red-team playbook tailored to Watership validator workflows.

---

## Near-Term Next Iteration (recommended)

1. Add at least 10 more Watership scenarios with temporal drift and cross-department conflicts.
2. Introduce inter-rater calibration protocol for manual grading on the same runs.
3. Add off-policy evaluation tooling (counterfactual scoring on held-out trajectories) before PPO.
