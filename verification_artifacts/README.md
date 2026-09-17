# UL7RAVERSE Verification Artifact Contract

## Purpose

This directory defines the phone-side verification artifact boundary.

It does not replace existing UL7RAVERSE verification systems.

It records the state required to make verification runs:

- inspectable
- replayable
- diffable
- hashable
- provenance-aware
- governance-aware

## Authority

The artifact records:

`PHONE_SIDE_UL7RAVERSE_GOVERNANCE`

Copilot, Codespaces, or any engineering agent is not promotion authority.

## Gate order

BUILD
→ TEST
→ ADVERSARIAL
→ PROVENANCE
→ TEMPORAL
→ AIL
→ LUCITEST
→ TRINITY
→ DECISION
→ PROMOTION

## Initial state

A newly initialized artifact is:

`NO_PROMOTE`

because verification has not yet occurred.

UNKNOWN is not PASS.

Missing evidence is not PASS.

A failed required gate must never be converted into PASS by this artifact layer.

## Integrity

Canonical JSON serialization is hashed with SHA-256.

Historical artifacts should be treated as append-only records.

Corrections should create a new artifact rather than silently rewriting historical evidence.

## Important

This first implementation intentionally does not execute the production verification pipeline.

It establishes the artifact contract only.
