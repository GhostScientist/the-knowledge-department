# Validator Rubric v0 (Watership)

## Purpose

Score validator decisions for correctness and trustworthiness.

## Criteria

1. Contradiction Detection (0-4)
   - 0: misses clear contradiction
   - 2: contradiction detected but weakly referenced
   - 4: contradiction detected with explicit reference and rationale

2. Confidence Calibration (0-3)
   - 0: confidence clearly miscalibrated
   - 1: partially calibrated
   - 3: confidence matches evidence quality and uncertainty

3. Traceability Completeness (0-3)
   - 0: no useful provenance
   - 1: partial provenance
   - 3: includes source, scope, influence, and event linkage

## Total

`score = contradiction + calibration + traceability` (max 10)

## Automatic Fail Conditions

- Omits known conflict in input context.
- Assigns confidence > 0.9 despite unresolved contradiction.
