# PURPLEPROTOCOLOMEGA v9.0 — EXECUTE NOW

You are the implementation agent inside the existing UL7RAVERSE repository.

DO NOT START OVER.

Your task is to forensic-discover the existing PURPLEPROTOCOLOMEGA implementation, reconcile it with the canonical UL7RAVERSE architecture, and complete a runnable, testable, upgradeable v9.0 implementation.

## NON-NEGOTIABLE TRUTH RULES

UNKNOWN != PASS

UNVERIFIED != VERIFIED

NO_PROOF != TRUSTED_ACTION

FAILED != PASS

CONFLICTED != VERIFIED

STALE != VERIFIED

TEST_PASS != PRODUCTION_PROOF

CODE_EXISTENCE != OPERATIONAL_PROOF

MOCK != REAL

AGENT_OUTPUT != AUTHORITY

COMMERCE != PROOF

PAYMENT != PROOF

Never fabricate evidence, customers, revenue, integrations, deployment status, verification, or production readiness.

Fail closed.

Never convert an unknown condition into success.

---

# 1. FORENSIC DISCOVERY

First inspect the repository without destructive changes.

Run:

pwd
git status --short --branch
git rev-parse HEAD
git log --oneline -20

Search for:

PURPLEPROTOCOLOMEGA
PURPLE PROTOCOL
Protocol 52
Purple Team
UL7RAPROOF
Proof State
FAIL_CLOSED
UNKNOWN
UNVERIFIED
grounded_center
GROUNDED_CENTER
governance
verification_artifacts
UL7RA4ORGE
UL7RAFORGE
UL7RABRIDGE
SAIOS
NODE9
TRINITY CORE

Do NOT create duplicate systems if an existing implementation already exists.

Create:

verification_artifacts/purple_v9/<timestamp>/FORENSIC_DISCOVERY_REPORT.json

Record:

- existing implementation
- schemas
- tests
- CLI
- evidence systems
- ledgers
- governance
- proof-state engines
- existing integrations
- duplicate/conflicting implementations
- missing components
- recommended continuation point

---

# 2. CANONICAL GROUNDING

Locate and inspect the canonical:

UL7RAVERSE_GROUNDED_CENTER

Treat the canonical grounded center as the architectural source of truth.

Determine:

- canonical schema
- canonical status
- version
- hash
- component inventory
- governance rules
- production-unlock requirements

If multiple candidates exist, reconcile them explicitly.

Never silently choose between conflicting canonical sources.

Create:

GROUNDING_RECONCILIATION.json

---

# 3. PURPLEPROTOCOLOMEGA CORE

Implement or complete these layers:

DISCOVERY
NORMALIZATION
CLASSIFICATION
ATTACK
OBSERVATION
CORROBORATION
RECONCILIATION
EVIDENCE SCORING
PROOF STATE
GATING
DECISION
AUDIT

The system must be machine-readable and locally runnable.

Prefer existing repository architecture over introducing unnecessary dependencies.

---

# 4. REQUIRED OBJECTS

Implement versioned schemas/models for:

Claim
Evidence
EvidenceBundle
Attack
Test
Finding
Contradiction
ProofState
Gate
Decision
AuditEvent
Upgrade
VerificationRun
ProductionUnlock
SystemIdentity

Every object requires stable IDs and deterministic serialization.

---

# 5. PROOF STATES

Support at minimum:

HYPOTHESIS
UNKNOWN
UNVERIFIED
COMMUNITYSIGNAL
CORROBORATED
VERIFIED
CONFLICTED
STALE
FAILED
REPEATABLE
SCALEREADY

Do NOT treat these as a simple confidence score.

State transitions require evidence.

Illegal transitions must fail closed.

Every transition must produce an audit event.

---

# 6. ADVERSARIAL ENGINE

Implement attacks for:

false positives
false negatives
missing evidence
stale evidence
contradictory evidence
duplicate evidence
identity confusion
source substitution
timestamp manipulation
replay
configuration drift
dependency drift
environment mismatch
test-only success
mock/live confusion
authority confusion
unsupported claims
fabricated provenance
circular evidence
self-certification
incomplete execution
silent exceptions
fail-open behavior
permission escalation
unexpected dependencies
nondeterministic output
corrupted artifacts
schema mismatch

Each attack produces structured results.

---

# 7. EVIDENCE

Evidence must include where applicable:

ID
claim reference
source
collection time
evidence time
SHA-256 hash
provenance
integrity status
freshness status
verification status
relationships

Integrate with an existing ledger/Merkle system if one exists.

Do not create competing truth systems unnecessarily.

---

# 8. CONTRADICTIONS

Conflicting evidence must produce:

CONFLICTED

Do not average conflicting authoritative evidence.

Do not silently choose one.

Require explicit reconciliation.

---

# 9. DETERMINISTIC REPLAY

Every verification run must record:

inputs
input hashes
configuration hash
environment fingerprint
dependency fingerprint
test IDs
evidence references
outputs
output hash
final decision

Replay must determine whether the result is reproducible.

Do not claim REPEATABLE without evidence.

---

# 10. GOVERNANCE

Maintain strict separation:

CODE = implementation
GIT = history
TEST = evaluation
EVIDENCE = observed support
LEDGER = record
GOVERNANCE = authority
DECISION = controlled conclusion

No agent self-authorizes production.

No passing test independently unlocks production.

---

# 11. PRODUCTION UNLOCK

Production unlock remains 0 if any mandatory requirement is:

UNKNOWN
MISSING
FAILED
CONFLICTED
STALE
UNVERIFIED

Required checks should include:

- required tests
- adversarial tests
- evidence integrity
- required evidence
- contradiction status
- dependency state
- configuration integrity
- replay
- governance approval
- explicit FINAL_DECISION

Never infer production unlock.

---

# 12. CLI

Extend the existing CLI if available.

Required capabilities:

discover
verify
attack
audit
replay
status
explain
evidence
contradictions
upgrade
self-test

Support machine-readable JSON output.

Do not create a competing CLI if one already exists.

---

# 13. SELF-TESTS

Create tests proving:

UNKNOWN cannot become VERIFIED without evidence.

UNVERIFIED cannot become VERIFIED merely because a test passes.

Missing evidence blocks unlock.

Contradiction produces CONFLICTED.

Stale evidence blocks required verification.

Corrupted evidence fails integrity.

Replay detects changed inputs.

Configuration drift is detected.

Mock evidence cannot become live evidence.

Agent output cannot become authority.

Self-certification cannot satisfy governance.

Fail-open behavior is detected.

Malformed schemas are rejected.

Illegal state transitions fail.

Duplicate evidence is detected.

Source substitution is detected.

Audit events remain valid.

Production unlock remains 0 when mandatory requirements are UNKNOWN.

---

# 14. UPGRADE ENGINE

v9.0 must be upgradeable.

Implement:

current version
target version
compatibility check
migration plan
schema migration
rollback metadata
pre-upgrade snapshot
post-upgrade verification
upgrade audit event

Never silently mutate canonical evidence.

Create an upgrade manifest.

---

# 15. RESOURCE CONSTRAINTS

This may execute in Termux on constrained Android hardware.

Therefore:

- minimize dependencies
- prefer Python standard library where practical
- avoid Docker
- avoid Kubernetes
- avoid cloud requirements for core verification
- avoid unnecessary process spawning
- make tests individually runnable
- support lightweight execution
- cache expensive discovery where safe

Core functionality must work locally.

---

# 16. TESTING

Run the existing repository test suite first.

Then run all Purple tests.

Classify failures as:

REAL_FAILURE
ENVIRONMENT_BLOCK
MISSING_DEPENDENCY
EXPECTED_BLOCK
TEST_DEFECT
IMPLEMENTATION_DEFECT
UNKNOWN

Do not relabel real implementation failures as environment issues.

---

# 17. HARDENING AUDIT

Search for:

TODO
FIXME
pass
except:
silent exceptions
fail-open logic
fake success states
mock production claims
hard-coded verification claims
unsafe defaults
duplicate implementations
deprecated naming
schema mismatches
unvalidated external input
nondeterminism

Repair relevant issues.

Do not modify unrelated systems unnecessarily.

---

# 18. FINAL ARTIFACTS

Produce:

FORENSIC_DISCOVERY_REPORT.json

GROUNDING_RECONCILIATION.json

PURPLE_TEST_MATRIX.json

TEST_EXECUTION_REPORT.json

UPGRADE_MANIFEST.json

PURPLEPROTOCOLOMEGA_FINAL_DECISION.json

And documentation where appropriate.

---

# 19. FINAL DECISION

Generate:

{
  "system": "PURPLEPROTOCOLOMEGA",
  "version": "9.0",
  "final_decision": "PASS|PASS_WITH_ENVIRONMENT_BLOCK|BLOCKED|FAIL|UNKNOWN",
  "production_unlock": false,
  "verification_status": "...",
  "critical_findings": [],
  "open_unknowns": [],
  "unresolved_contradictions": [],
  "environment_blocks": [],
  "evidence_integrity": "...",
  "replay_status": "...",
  "upgrade_status": "...",
  "governance_status": "...",
  "run_id": "...",
  "root_hash": "..."
}

PASS requires evidence.

If environmental limitations prevent complete verification, use:

PASS_WITH_ENVIRONMENT_BLOCK

only when the implementation itself passed every test available in the environment and the remaining limitation is demonstrably environmental.

Otherwise use:

BLOCKED
FAIL
UNKNOWN

---

# 20. SAFETY

Before modifying anything:

git status

Never execute:

git reset --hard
git clean -fd
force push
history rewrite

Do not destroy existing user work.

Preserve uncommitted changes.

---

# 21. EXECUTION MODE

CONTINUE AUTOMATICALLY.

Do not stop after discovery.

Do not ask unnecessary questions.

If one component is blocked, record the blocker and continue independent safe work.

Do not restart an existing implementation.

Reuse valid components.

Repair broken components.

Implement missing components.

Run tests.

Run adversarial tests.

Generate evidence.

Generate final decision.

FAIL CLOSED.

At the end print:

PURPLEPROTOCOLOMEGA v9.0

IMPLEMENTATION:
TESTS:
ADVERSARIAL TESTS:
EVIDENCE:
REPLAY:
UPGRADE:
GOVERNANCE:
PRODUCTION_UNLOCK:
FINAL_DECISION:
CRITICAL_FINDINGS:
OPEN_UNKNOWNS:
ARTIFACTS:

The final report must reflect actual execution, not intended functionality.
