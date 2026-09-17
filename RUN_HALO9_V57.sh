#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/UL7RAVERSE"
V56="$ROOT/halo9_v56_authority_contract"
V57="$ROOT/halo9_v57_adapter"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/verification_artifacts/halo9_v57/$TS"
REPORT="$OUT/HALO9_V57_REPORT.txt"

mkdir -p "$V57/src" "$OUT"

log() {
    echo "$*" | tee -a "$REPORT"
}

log "=================================================="
log "HALO9 V57 NON-PRODUCTION ADAPTER"
log "=================================================="
log "UTC=$TS"
log "V56=$V56"
log "V57=$V57"
log "REAL_UL7RABRIDGE_MODIFICATION=NONE"
log "REAL_UL7RABRIDGE_INTEGRATION=NOT_PERFORMED"

# --------------------------------------------------
# Verify V56 exists
# --------------------------------------------------

if [ ! -f "$V56/Cargo.toml" ] || [ ! -f "$V56/src/lib.rs" ]; then
    log "V56=NOT_FOUND"
    log "FINAL_DECISION=BLOCKED"
    exit 1
fi

# --------------------------------------------------
# Discover actual V56 package name
# --------------------------------------------------

V56_PACKAGE="$(
    sed -n 's/^name = "\(.*\)"/\1/p' \
    "$V56/Cargo.toml" | head -1
)"

if [ -z "$V56_PACKAGE" ]; then
    log "V56_PACKAGE=NOT_FOUND"
    log "FINAL_DECISION=BLOCKED"
    exit 1
fi

log "V56_PACKAGE=$V56_PACKAGE"

# --------------------------------------------------
# Create V57 Cargo manifest
# --------------------------------------------------

cat > "$V57/Cargo.toml" <<TOML
[package]
name = "halo9_v57_adapter"
version = "0.1.0"
edition = "2021"

[dependencies]
thiserror = "2"
halo9_v56 = { package = "$V56_PACKAGE", path = "../halo9_v56_authority_contract" }
TOML

# --------------------------------------------------
# Create V57 adapter
# --------------------------------------------------

cat > "$V57/src/lib.rs" <<'RUST'
use std::sync::Arc;
use std::time::SystemTime;

use halo9_v56::{
    ActionAuthorization,
    AuthorityContract,
    AuthorityContractConfig,
    BridgeAuthority,
    BridgeDecision,
    BridgeInvariants,
    CheetahPolicy,
    CryptographicProvider,
    HaloPair,
    HaloPairStatus,
    ProofState,
};

#[derive(Debug, thiserror::Error)]
pub enum AdapterError {
    #[error("authority contract denied action: {0}")]
    ContractDenied(String),

    #[error("bridge refused action")]
    BridgeRefused,

    #[error("missing pair or proof")]
    MissingState,
}

pub type AdapterResult<T> = Result<T, AdapterError>;

pub struct UL7RABridgeAdapter {
    contract: Arc<AuthorityContract<'static>>,
}

impl UL7RABridgeAdapter {
    pub fn new(
        cryptographic_provider: &'static dyn CryptographicProvider,
        cheetah_policy: &'static dyn CheetahPolicy,
        bridge_invariants: &'static dyn BridgeInvariants,
        bridge_authority: &'static dyn BridgeAuthority,
    ) -> Self {
        let config = AuthorityContractConfig {
            production_crypto_configured: false,
        };

        let contract = AuthorityContract {
            cryptographic_provider,
            cheetah_policy,
            bridge_invariants,
            bridge_authority,
            config,
        };

        Self {
            contract: Arc::new(contract),
        }
    }

    pub fn evaluate(
        &self,
        now: SystemTime,
        pair_status: HaloPairStatus,
        pair: Option<&HaloPair>,
        proof: Option<&ProofState>,
    ) -> AdapterResult<BridgeDecision> {
        let pair = pair.ok_or(AdapterError::MissingState)?;
        let proof = proof.ok_or(AdapterError::MissingState)?;

        match self
            .contract
            .authorize(now, pair_status, Some(pair), Some(proof))
        {
            ActionAuthorization::Denied(error) => {
                Err(AdapterError::ContractDenied(error.to_string()))
            }

            ActionAuthorization::Allowed => {
                match self.contract.bridge_authority.decide(pair, proof) {
                    Ok(BridgeDecision::Allow) => Ok(BridgeDecision::Allow),
                    Ok(BridgeDecision::Deny) => Err(AdapterError::BridgeRefused),
                    Err(_) => Err(AdapterError::BridgeRefused),
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    use halo9_v56::{
        AgentId,
        AllowAllCheetahPolicy,
        CapabilityId,
        CryptographicProfileId,
        DenyAllBridgeAuthority,
        HaloTwinId,
        LedgerEntryId,
        MissionId,
        NoopCryptographicProvider,
        Nonce,
        ProofId,
        StrictBridgeInvariants,
        Timestamp,
    };

    use std::time::Duration;

    fn valid_pair(now: SystemTime) -> HaloPair {
        HaloPair {
            agent_id: AgentId("agent".into()),
            halo_twin_id: HaloTwinId("halo".into()),
            mission_id: MissionId("mission".into()),
            capability_id: CapabilityId("capability".into()),
            created_at: Timestamp(now),
            expires_at: Timestamp(now + Duration::from_secs(60)),
            nonce: Nonce([0u8; 32]),
            ledger_entry_id: LedgerEntryId("ledger".into()),
        }
    }

    fn valid_proof(now: SystemTime) -> ProofState {
        ProofState {
            proof_id: ProofId("proof".into()),
            halo_pair_id: HaloTwinId("halo".into()),
            cryptographic_profile_id: CryptographicProfileId("noop".into()),
            issued_at: Timestamp(now),
            ledger_entry_id: LedgerEntryId("ledger".into()),
            is_bound_to_mission: true,
            is_bound_to_capability: true,
            is_revoked: false,
            is_replayed: false,
        }
    }

    fn adapter() -> UL7RABridgeAdapter {
        UL7RABridgeAdapter::new(
            &NoopCryptographicProvider,
            &AllowAllCheetahPolicy,
            &StrictBridgeInvariants,
            &DenyAllBridgeAuthority,
        )
    }

    #[test]
    fn no_production_crypto_denies_before_bridge() {
        let adapter = adapter();
        let now = SystemTime::now();

        let pair = valid_pair(now);
        let proof = valid_proof(now);

        let result = adapter.evaluate(
            now,
            HaloPairStatus::Valid,
            Some(&pair),
            Some(&proof),
        );

        assert!(result.is_err());
    }

    #[test]
    fn missing_pair_denies() {
        let adapter = adapter();
        let now = SystemTime::now();
        let proof = valid_proof(now);

        let result = adapter.evaluate(
            now,
            HaloPairStatus::Valid,
            None,
            Some(&proof),
        );

        assert!(matches!(result, Err(AdapterError::MissingState)));
    }

    #[test]
    fn missing_proof_denies() {
        let adapter = adapter();
        let now = SystemTime::now();
        let pair = valid_pair(now);

        let result = adapter.evaluate(
            now,
            HaloPairStatus::Valid,
            Some(&pair),
            None,
        );

        assert!(matches!(result, Err(AdapterError::MissingState)));
    }

    #[test]
    fn invalid_pair_denies_before_bridge() {
        let adapter = adapter();
        let now = SystemTime::now();

        let pair = valid_pair(now);
        let proof = valid_proof(now);

        let result = adapter.evaluate(
            now,
            HaloPairStatus::Invalid,
            Some(&pair),
            Some(&proof),
        );

        assert!(result.is_err());
    }

    #[test]
    fn expired_pair_denies_before_bridge() {
        let adapter = adapter();
        let now = SystemTime::now();

        let mut pair = valid_pair(now);
        pair.expires_at = Timestamp(
            now.checked_sub(Duration::from_secs(1))
                .expect("valid timestamp"),
        );

        let proof = valid_proof(now);

        let result = adapter.evaluate(
            now,
            HaloPairStatus::Valid,
            Some(&pair),
            Some(&proof),
        );

        assert!(result.is_err());
    }

    #[test]
    fn revoked_proof_denies_before_bridge() {
        let adapter = adapter();
        let now = SystemTime::now();

        let pair = valid_pair(now);
        let mut proof = valid_proof(now);
        proof.is_revoked = true;

        let result = adapter.evaluate(
            now,
            HaloPairStatus::Valid,
            Some(&pair),
            Some(&proof),
        );

        assert!(result.is_err());
    }

    #[test]
    fn replayed_proof_denies_before_bridge() {
        let adapter = adapter();
        let now = SystemTime::now();

        let pair = valid_pair(now);
        let mut proof = valid_proof(now);
        proof.is_replayed = true;

        let result = adapter.evaluate(
            now,
            HaloPairStatus::Valid,
            Some(&pair),
            Some(&proof),
        );

        assert!(result.is_err());
    }

    #[test]
    fn bridge_denial_never_becomes_allow() {
        let adapter = adapter();
        let now = SystemTime::now();

        let pair = valid_pair(now);
        let proof = valid_proof(now);

        let result = adapter.evaluate(
            now,
            HaloPairStatus::Valid,
            Some(&pair),
            Some(&proof),
        );

        assert!(!matches!(result, Ok(BridgeDecision::Allow)));
    }
}
RUST

cd "$V57" || exit 1

# --------------------------------------------------
# Format
# --------------------------------------------------

cargo fmt --all
FMT_RC=$?
log "CARGO_FMT_RC=$FMT_RC"

# --------------------------------------------------
# Compile
# --------------------------------------------------

cargo check > "$OUT/cargo_check.log" 2>&1
CHECK_RC=$?

cat "$OUT/cargo_check.log" >> "$REPORT"
log "CARGO_CHECK_RC=$CHECK_RC"

# --------------------------------------------------
# Test
# --------------------------------------------------

cargo test --all-targets > "$OUT/cargo_test.log" 2>&1
TEST_RC=$?

cat "$OUT/cargo_test.log" >> "$REPORT"
log "CARGO_TEST_RC=$TEST_RC"

if grep -q "test result: ok" "$OUT/cargo_test.log"; then
    TEST_RESULT="PASS"
else
    TEST_RESULT="FAIL"
fi

log "V57_TEST_RESULT=$TEST_RESULT"

# --------------------------------------------------
# Source integrity
# --------------------------------------------------

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum src/lib.rs Cargo.toml > "$OUT/V57_SOURCE_SHA256.txt"
    log "SOURCE_HASH=RECORDED"
else
    log "SOURCE_HASH=UNAVAILABLE"
fi

# --------------------------------------------------
# Governance
# --------------------------------------------------

log ""
log "=================================================="
log "V57 GOVERNANCE GATE"
log "=================================================="

log "ADAPTER_SCOPE=NON_PRODUCTION"
log "PROOF_DOES_NOT_EQUAL_AUTHORITY=ENFORCED"
log "HALO9_AUTHORITY_CONTRACT=REQUIRED"
log "BRIDGE_AUTHORITY=REQUIRED"
log "REAL_UL7RABRIDGE_MODIFICATION=NONE"
log "REAL_UL7RABRIDGE_INTEGRATION=NOT_PERFORMED"
log "PRODUCTION_CRYPTO=NOT_CONFIGURED"
log "PRODUCTION_UNLOCK=BLOCKED"

if [ "$FMT_RC" -eq 0 ] &&
   [ "$CHECK_RC" -eq 0 ] &&
   [ "$TEST_RC" -eq 0 ] &&
   [ "$TEST_RESULT" = "PASS" ]; then

    FINAL="PASS_WITH_PRODUCTION_BLOCK"
else
    FINAL="REVIEW_REQUIRED"
fi

log "HALO9_V57_FINAL_DECISION=$FINAL"

cat > "$OUT/FINAL_DECISION.txt" <<DECISION
HALO9_V57_FINAL_DECISION=$FINAL
CARGO_FMT_RC=$FMT_RC
CARGO_CHECK_RC=$CHECK_RC
CARGO_TEST_RC=$TEST_RC
V57_TEST_RESULT=$TEST_RESULT
ADAPTER_SCOPE=NON_PRODUCTION
REAL_UL7RABRIDGE_MODIFICATION=NONE
REAL_UL7RABRIDGE_INTEGRATION=NOT_PERFORMED
PRODUCTION_CRYPTO=NOT_CONFIGURED
PRODUCTION_UNLOCK=BLOCKED
DECISION

log "REPORT=$REPORT"
log "EVIDENCE=$OUT"
log "=================================================="

exit 0
