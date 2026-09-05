# UL7RAFORGE External S9 Attestation Contract

## Purpose

Establish independent verification of an S9 candidate without allowing
the local execution environment to self-attest external independence.

## Required external properties

The verifier MUST:

1. Execute outside the candidate's local Termux environment.
2. Retrieve evidence through a neutral store or equivalent independent channel.
3. Independently verify the evidence SHA-256.
4. Independently verify the repository commit anchor.
5. Execute the S9 verification procedure.
6. Identify its verifier environment.
7. Identify its credential domain.
8. Sign the resulting attestation using an externally controlled signing key.

## Required identity fields

VERIFIER_ENV_ID
VERIFIER_CREDENTIAL_DOMAIN
NEUTRAL_STORE
VERIFIER_ATTESTATION_KEY_ID

## Required attestation

schema_version
candidate
repository_commit
evidence_sha256
verifier_env_id
credential_domain
decision
independence
attestation_key_id
signature
timestamp

## Fail-closed rules

Missing identity, neutral-store, signing, evidence, commit, or verification
requirements MUST produce BLOCKED.

A local process MUST NEVER claim:

external_independence = PROVEN

solely because local environment variables are populated.

A locally generated signature MUST NOT satisfy the external attestation gate.

Production remains LOCKED until a valid external attestation is reconciled.
