# The Knowledge Department (TKD) — Plain-Language Abstract

## Why this exists
Organizations run on living knowledge: policies, processes, and “how we actually do things here.” That knowledge changes daily, and it gets messy fast—especially when multiple AI assistants start learning, editing, and sharing it. TKD explores how to keep that shared brain trustworthy, auditable, and usable by both humans and AI.

## Core idea
Instead of letting AI agents write directly into a company wiki or memory, TKD routes every knowledge update through narrow “custodian” roles (Archivist, Validator, future Reconciler/Scout). Each custodian has a clear job, checklist, and audit trail. Think of it like an internal Department of Knowledge: submissions go in, specialists review them, and only vetted facts make it into the official record.

## What we’re building
1. **Product layer (practical tools):** lightweight services, APIs, and CLIs that store knowledge assertions with provenance, version history, and confidence scores. This layer makes it easy to see who changed what, when, and why.
2. **Research layer (experiments + guardrails):** simulated organizations (the Watership Group) where we intentionally introduce conflicting policies, outdated docs, and adversarial prompts. We use this sandbox to test how well different AI policies behave and to document reward-hacking tricks before they show up in real deployments.

## Key questions
- How do we let AI assistants help maintain institutional memory without letting them corrupt it?
- Can narrow, well-audited roles outperform “do-everything” generalist agents when knowledge is messy?
- What telemetry and rubrics catch reward hacking early (e.g., agents inflating confidence or dodging contradictions)?
- How do prompt-engineered policies compare to reinforcement-learned ones when they face identical incentives?

## Approach
- Start with prompt-based policies and clear rubrics so we can see failure modes quickly.
- Progress to reinforcement learning (bandits → PPO) inside the Watership environment, keeping rewards constant to isolate optimization effects.
- Capture every success and failure as reusable benchmarks, so future teams can reproduce—or avoid—the same behaviors.

## Why it matters
As organizations rely on AI collaborators, inaccurate or stale knowledge compounds into broken workflows, compliance risk, and lost trust. TKD aims to make AI knowledge work:
- **Traceable:** every assertion carries provenance and confidence.
- **Auditable:** humans (and future agents) can inspect decisions and veto them.
- **Hard to game:** reward-hacking patterns are cataloged and countered.
- **Deployable:** lightweight enough to run locally or inside existing infra.

## Near-term focus
- Finalize the MVP “knowledge” CLI + hook system so agents can assert, validate, and promote facts with automatic logging.
- Flesh out the Watership benchmark scenarios (policy collisions, compliance edge cases).
- Run the “Breathing Thought” experiments to produce small, latency-friendly reasoning models that can power Validator/Reconcilers with transparent thinking.

TKD is an invitation to treat organizational knowledge with the same rigor we give to code: versioned, reviewed, and playable with collaborators—human or AI.