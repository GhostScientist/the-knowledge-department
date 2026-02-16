# TKD Repository Structure

## Why This Exists

TKD has two parallel tracks and both need to move quickly without colliding:

- Product track: practical infrastructure for governed knowledge.
- Research track: evaluation and learning system (Watership + optimization loops).

This document defines where new work should go so velocity stays high as the team grows.

## Current Canonical Layout

- `scripts/`: CLI + setup + local test harness.
- `examples/`: sample assertion/event payloads.
- `contracts/`: JSON schemas for payload/envelope compatibility.
- `services/tkd-api/`: API service scaffold and endpoint contract.
- `agents/custodians/`: role contracts for Archivist/Validator/Reconciler/Scout.
- `research/watership/`: scenario, fixture, and rubric scaffolds.
- `research/evals/`: evaluation run metadata/report structure.
- `pocketbase/`: collection schema blueprint.
- `docs/`: architecture, model, testing guides.

## Near-Term Target Layout

- `services/tkd-api/src/`: real service implementation.
- `agents/custodians/<role>/`: runnable policy + tests per role.
- `research/watership/runner/`: scenario execution harness.
- `research/evals/runs/`: immutable experiment outputs.

## Placement Rules

1. New external-facing payload shape changes go in `contracts/` first.
2. New CLI behavior goes in `scripts/` and must be reflected in `docs/mvp-agent-harness.md`.
3. New storage model changes go in `pocketbase/` and `docs/pocketbase-knowledge-model.md`.
4. New integration behavior must add test steps in `docs/TESTING-WHAT-WE-HAVE.md`.
5. Avoid adding implementation code under `docs/` or `examples/`.

## Definition Of Done (Repo Hygiene)

Before calling a change done:

1. Run `make check`.
2. Run `make smoke`.
3. If hook/integration behavior changed, run `~/.tkd/bin/knowledge status`.
4. Update at least one doc link in `README.md` if new docs/contracts are introduced.
