# The Knowledge Department

A research and systems project exploring how AI agents can safely create, maintain, and govern shared organizational knowledge.

## Why This Exists

Inside real organizations, knowledge is messy. Policies change, documents conflict, ownership shifts, and institutional memory decays.

The Knowledge Department (TKD) is built around one core question:

> How do AI systems collaborate with humans to maintain trustworthy knowledge over time?

TKD treats organizational knowledge as a living system that must be curated, validated, versioned, and audited, not as static context.

## What We Are Building

TKD combines two tightly-coupled layers:

- **Product Layer**: a lightweight, self-hosted knowledge infrastructure with structured assertions, provenance, versioning, audit logs, and access boundaries for agent contributions.
- **Research Layer**: an evaluation and learning platform for testing how knowledge-governance policies succeed or fail under pressure.

This makes TKD both deployable in practice and useful as a rigorous research environment.

## How Governance Works

Knowledge contributions are routed through specialized AI custodians with narrow responsibilities and explicit rubrics:

- **Archivist**: routes and categorizes incoming knowledge.
- **Validator**: verifies claims, scores confidence, and flags contradictions.
- **Reconciler** *(planned)*: resolves conflicts between competing assertions.
- **Scout** *(planned)*: identifies gaps and detects staleness over time.

The goal is traceable, auditable decision-making instead of silent memory mutation.

## Research Focus

TKD includes **Watership Group**, a simulated mid-sized enterprise with contradictory docs, changing policies, and adversarial edge cases.

Using Watership, we compare:

- Prompt-policy optimization (fast, interpretable, easier to iterate)
- Gradient-based RL policies (bandits to PPO under identical rewards)

A central theme is **reward hacking**: how agents game curation metrics while degrading true knowledge quality.

## What TKD Aims To Deliver

- The Watership Knowledge Curation Benchmark
- Reusable evaluation environments for organizational knowledge tasks
- Empirical comparisons of prompt-based and RL-based governance policies
- A practical blueprint for safe, scalable AI knowledge operations

## Current Status

**Phase 1 (Current):** Architectural planning and evaluation framework design.

Planned phases:

- **Phase 2**: Watership implementation and baseline evaluations
- **Phase 3**: Prompt-policy optimization and reward-hacking documentation
- **Phase 4**: RL pipeline development (bandits -> PPO)
- **Phase 5**: Benchmark publication and open-source release

## MVP Harness

To bootstrap provenance-first agent integration, this repo includes an MVP connection scaffold:

- `scripts/install-tkd-agent.sh` installs a local `knowledge` command.
- `scripts/knowledge.sh` provides `knowledge enable/status`, `knowledge event`, `knowledge assert`, `knowledge promote`, and `knowledge lookup`.
- `scripts/mock_tkd_server.py` and `scripts/smoke-test.sh` provide local end-to-end testing.

Example:
`~/.tkd/bin/knowledge assert --assertion-file examples/assertions/api-naming-convention.json --knowledge-key engineering.api.json_naming --scope repo --confidence 0.6 --dry-run`

Hook alignment:
`knowledge enable` installs managed Git hook wrappers (`post-commit`, `pre-push`) and configures Claude project hooks in `.claude/settings.local.json`.

See `docs/mvp-agent-harness.md` for architecture and commands.
See `docs/pocketbase-knowledge-model.md` for the storage/query/evolution model.
See `docs/TESTING-WHAT-WE-HAVE.md` for validation steps and testing notes templates.

## Built By

TKD is being developed by **reasoning.software**.

## Early Access

We are looking for practitioners building AI agents who want to help shape this evaluation framework.

Join the waitlist to receive updates and early access to the Watership benchmark.

## Full Vision

See `VISION.md` for the complete long-form project narrative and research direction.
