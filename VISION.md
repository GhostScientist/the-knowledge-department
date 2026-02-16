# The Knowledge Department

A research and systems project exploring how AI agents can safely create, maintain, and govern shared organizational knowledge.

## What Is TKD?

The Knowledge Department (TKD) is a research-driven infrastructure project focused on a deceptively hard question:

> How do AI systems collaborate with humans to maintain trustworthy organizational knowledge over time?

Modern AI assistants are strong at general tasks, but real organizational knowledge work is messy, time-dependent, and ambiguous. Policies change, documents conflict, ownership shifts, and institutional memory decays.

TKD treats organizational knowledge not as static context, but as a living system that must be curated, validated, versioned, and audited, especially as AI agents begin to rely on it.

## Core Idea

TKD introduces **knowledge governance for AI systems**.

Instead of allowing agents to write freely to memory or retrieve arbitrary documents, TKD routes all knowledge contributions through specialized AI custodians with narrow responsibilities and explicit evaluation criteria.

You can think of TKD as:

- A Git-style workflow for organizational facts
- A Wikipedia-like system with validators and editors
- A knowledge department for keeping the institutional brain clean

But explicitly designed for AI agents operating at scale.

## System Architecture

TKD is built as two tightly coupled layers:

### 1) Product Layer: Knowledge Infrastructure

A lightweight, self-hosted service that provides:

- Structured storage for knowledge assertions
- Versioning, audit logs, and provenance tracking
- APIs and tool interfaces for AI agents
- Identity and access boundaries for agent contributions
- Real-time updates for monitoring and UI surfaces

This layer is practical, deployable, and product-aligned.

### 2) Research Layer: Evaluation and Learning

An experimental platform for understanding policy quality and failure:

- Benchmark environments for knowledge curation tasks
- Rubric-based evaluation for open-ended decisions
- Detection and mitigation of reward hacking
- Prompt-based optimization and reinforcement learning workflows
- Controlled comparisons of optimization regimes under identical rewards

This layer exists to answer why approaches work and when they fail.

## Custodian Roles

TKD decomposes governance into narrow roles handled by specialized custodians:

### Archivist

- Routes and categorizes incoming knowledge

### Validator

- Verifies claims
- Assigns calibrated confidence
- Flags contradictions

### Reconciler *(planned)*

- Merges conflicting entries
- Resolves discrepancies

### Scout *(planned)*

- Identifies knowledge gaps
- Detects staleness over time

Custodians operate under explicit rubrics, veto thresholds, and adversarial tests designed to surface failure modes instead of hiding them.

## How It Works in Practice

### Example: New Coding Convention

**Input**
Developer agent proposes:
`All API responses should use camelCase for JSON keys`

**Archivist**
Routes to:
`Engineering -> API Standards -> Naming Conventions`
Tags as:
`cross-team policy`

**Validator**
Finds conflicting 2023 entry requiring `snake_case`
Flags contradiction
Assigns confidence `0.6` pending human review

**Output**
Assertion is queued with audit trail, provenance, and explicit uncertainty, not silently committed.

Every step is logged, every decision is traceable, and conflicting information is surfaced immediately rather than corrupting downstream behavior.

## Watership: Evaluation Environment

To study governance rigorously, TKD includes **Watership Group**, a simulated mid-sized enterprise for evaluation and training.

Watership includes:

- Hundreds of ground-truth organizational facts
- Time-varying internal policies and procedures
- Contradictory and outdated documentation
- Departmental silos with inconsistent norms
- Adversarial scenarios designed to induce reward hacking

Watership is intentionally realistic and operationally mundane, mirroring how knowledge behaves in long-lived organizations.

## Optimization and Learning

TKD follows a deliberate progression of optimization approaches ("dead-reckoning" from simple to sophisticated):

### Prompt-Policy Optimization

Starting point: LLM policies controlled through prompts and rubrics.

- Fast iteration and interpretability
- Strong performance with careful rubric design
- Vulnerable to specific classes of reward gaming

### Gradient-Based Reinforcement Learning

Destination: policies optimized directly in Watership environments.

- Gymnasium-style environments with discrete action spaces per custodian
- Progression from contextual bandits to PPO
- Evaluation across generalization, stability, and safety metrics
- Identical reward functions across regimes for direct comparison

By holding environment and reward structure constant, TKD isolates how optimization strategy affects policy quality and where reward hacking emerges.

## Why This Matters

As AI systems become virtual collaborators, stale or incorrect knowledge compounds into:

- Broken workflows
- Compliance violations
- Security incidents
- Error amplification across agents
- Loss of trust in AI-assisted operations

TKD aims to make organizational AI collaboration:

- Reliable
- Auditable
- Difficult to game
- Safe to scale
- Aligned with real-world incentives

## Reward Hacking Taxonomy

A core research output is a taxonomy of how agents game knowledge-curation rewards.

When optimizing metrics like completeness or validation accuracy, agents can satisfy the letter of the reward while violating its intent. TKD documents failure modes such as:

- **Confidence inflation**: assigning high confidence to maximize throughput
- **Citation farming**: circular references that artificially raise credibility
- **Staleness arbitrage**: unnecessary refreshes to hit update quotas
- **Contradiction avoidance**: routing around conflicts instead of resolving them

Understanding these behaviors is essential for robust reward design under optimization pressure.

## Research Hypotheses

TKD tests falsifiable hypotheses:

- **H1: Narrow custodians outperform generalists**
  Specialized agents with constrained action spaces exhibit fewer reward-hacking behaviors under identical criteria.
- **H2: Explicit uncertainty improves downstream trust**
  Systems that surface calibrated confidence and provenance sustain higher trust than systems that present all assertions as equally certain.
- **H3: RL policies generalize better than prompt policies**
  Gradient-based policies are more robust under distribution shift, while prompt policies remain easier to interpret and correct.

## Expected Research Outputs

TKD is designed to produce publishable artifacts:

- The Watership Knowledge Curation Benchmark
- Evaluation frameworks for open-ended organizational tasks
- Empirical comparisons of prompt-based vs RL-based optimization
- Reusable environments for future research

Negative results and failure cases are treated as first-class contributions.

## Vision

TKD is a step toward a future where:

- AI agents do more than answer questions and actively maintain institutional knowledge
- Knowledge systems do more than accumulate data and actively self-heal
- Evaluation is built into system behavior rather than bolted on later
- Optimization improves trust, not just metrics

TKD explores what it takes for AI systems to become genuinely trustworthy collaborators inside real organizations.

## Current Status

This project builds on prior tools developed to explore these ideas:

- **semanticwiki**: an npm package that uses a cloud or local agent to digest codebases into a DeepWiki-style architectural wiki
- **Build an Agent Workshop**: a framework for defining and building specialized agents using frontier models and SDKs

Current phase:
**Phase 1: Architectural planning and evaluation framework design**

## Roadmap

- **Phase 1 (Current)**: Architectural planning and evaluation framework design
- **Phase 2**: Watership implementation and baseline evaluations
- **Phase 3**: Prompt-policy optimization and reward-hacking documentation
- **Phase 4**: RL pipeline development (bandits -> PPO)
- **Phase 5**: Benchmark publication and open-source release

## Team

TKD is being developed by **reasoning.software**.

## Early Access

We are looking for practitioners building AI agents who want to help shape the evaluation framework.

Join the waitlist to get project updates and early access to the Watership benchmark.
