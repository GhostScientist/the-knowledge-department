# Custodian Agent Scaffolds

This folder defines role-specific behavior contracts for TKD custodians.

## Roles

- `archivist/ROLE.md`
- `validator/ROLE.md`
- `reconciler/ROLE.md` (planned)
- `scout/ROLE.md` (planned)

## Usage

Each role file should evolve into:

1. Prompt/policy specification.
2. Allowed action space.
3. Rubric and veto thresholds.
4. Known failure modes and adversarial checks.

Keep these role definitions narrow and testable to support hypothesis H1 (narrow custodians outperform generalists).
