# RL + Evaluation Throughline

This document captures the concrete plan for reinforcing the “knowledge custodians under optimization pressure” storyline that runs through The Knowledge Department (TKD).

## 1. Environments Mirroring Custodians
We design a trio of reinforcement-learning environments that each map to an existing or planned custodian role:

| Environment | Custodian focus | Sketch |
| --- | --- | --- |
| **Policy Diff & Routing** | Archivist | Agent receives a stream of Watership change requests + existing policies, must assign knowledge keys, detect duplicates, and queue contradictions. Rewards favor correct routing, provenance completeness, and latency bounds. |
| **Confidence-Gated Validation** | Validator | Agent consumes structured assertions, source docs, and historical confidence bands. Actions include approve/reject, request clarification, and emit calibrated confidence. Rewards penalize confidence inflation, missing citations, and contradiction avoidance. |
| **Ledger Reconciliation** | Reconciler (planned) | Agent reconciles conflicting spreadsheets/budgets, proposes merges, and annotates rationale. Rewards combine numeric accuracy, audit trail completeness, and human rubric scores for readability.

Implementation notes:
- State serialization is compatible with the `knowledge` CLI payloads so we can replay real traffic.
- Action spaces are intentionally narrow to keep outcomes auditable and to mimic real custodian permissions.

## 2. Data Creation + Provenance Loop
To keep experiments grounded in Watership reality, we establish a lightweight data factory:
- **Human prompts:** guided writing sessions that produce realistic policy memos, compliance escalations, and spreadsheet changes.
- **Frontier distillation:** Claude/other models generate candidate reasoning traces; humans tag them for quality and highlight reward-hacking behaviors.
- **Crowd QA:** targeted micro-tasks (e.g., “identify contradictions,” “grade confidence statements”) with automatic provenance injection (knowledge key, source doc hash, author, timestamp).
- Outputs land in `research/watership/data/` with schema-aligned manifests.

## 3. Evaluation + Reward Signals
Rubric-based evaluation is treated as both science instrument and reward function:
- **Automatic metrics:** win-rate vs base models, citation accuracy, latency, hallucination rate, spreadsheet delta error.
- **Rubrics:** human-readable checklists for chain-of-thought clarity, provenance storytelling, and intervention cost.
- **Reward-hacking probes:** scripted tests for confidence inflation, contradiction dodging, unnecessary edits (“doc vandalism”), and quota gaming. Failures feed back into reward shaping.
- **Dashboards:** lightweight notebooks/Streamlit app tying together metrics, rubric scores, and reward diagnostics.

## 4. Product Checkpoints
Every experiment cycle ends with a product-facing demo:
1. Deploy the tuned policy behind `knowledge validator-assist` and run it against fresh Watership scenarios.
2. Capture audit logs, latency numbers, and rubric results in `research/evals/`.
3. Decide whether the policy (or only its data) graduates into TKD’s product layer.

This loop ensures the entire TKD project—research and product—shares a single objective: relentlessly test whether narrow, auditable RL policies can keep organizational knowledge trustworthy without inviting reward hacking.
