# HALO Twin Pair V1

UL7RAVERSE fail-closed agent/halo security state machine.

## Prime invariant

**NO VALID HALO TWIN PAIR -> NO ACTION.**

The agent and Digital Halo Twin are separate halves of a serialized pair. A mismatch, missing half, replay, expiry, revocation, unknown crypto suite, invalid proof, or rollback blocks the action path.

## Important security boundary

This repository intentionally does **not** ship homemade production cryptography or pretend that a test verifier is secure. `FailClosedVerifier` refuses all cryptographic authorization. The real crypto provider must be injected later using a standardized, independently reviewed implementation (including a PQC-capable provider where required).

`TestVerifier` exists only under `cfg(test)` and accepts the literal test signature `TEST-VALID`. It must never be used for production authorization.

## State flow

`UNPAIRED -> PAIRING -> VALID -> EXECUTING -> PROOF_PENDING -> ROLLING -> VALID`

Any invalid condition transitions to `BLOCKED` or another explicitly non-actionable state.

## Run

```bash
cargo test
cargo run --bin halo9-demo
```

Expected demo result:

```text
state=Unpaired
action_allowed=false
production_crypto_provider=NOT_CONFIGURED
production_unlock=BLOCKED
```

## Next hardening gate

1. Integrate a reviewed cryptographic provider.
2. Define canonical serialization for signed envelopes.
3. Add anti-rollback durable storage.
4. Add capability leases and resource limits.
5. Add PQC/hybrid crypto integration without changing the governance state machine.
6. Add fuzz/property tests.
7. Independently review the implementation.
8. Keep production unlock blocked until evidence exists.
