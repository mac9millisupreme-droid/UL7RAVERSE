use std::sync::Arc;
use std::time::SystemTime;

use halo9_v56::{
    ActionAuthorization, AuthorityContract, AuthorityContractConfig, BridgeAuthority,
    BridgeDecision, BridgeInvariants, CheetahPolicy, CryptographicProvider, HaloPair,
    HaloPairStatus, ProofState,
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
        AgentId, AllowAllCheetahPolicy, CapabilityId, CryptographicProfileId,
        DenyAllBridgeAuthority, HaloTwinId, LedgerEntryId, MissionId, Nonce,
        NoopCryptographicProvider, ProofId, StrictBridgeInvariants, Timestamp,
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

        let result = adapter.evaluate(now, HaloPairStatus::Valid, Some(&pair), Some(&proof));

        assert!(result.is_err());
    }

    #[test]
    fn missing_pair_denies() {
        let adapter = adapter();
        let now = SystemTime::now();
        let proof = valid_proof(now);

        let result = adapter.evaluate(now, HaloPairStatus::Valid, None, Some(&proof));

        assert!(matches!(result, Err(AdapterError::MissingState)));
    }

    #[test]
    fn missing_proof_denies() {
        let adapter = adapter();
        let now = SystemTime::now();
        let pair = valid_pair(now);

        let result = adapter.evaluate(now, HaloPairStatus::Valid, Some(&pair), None);

        assert!(matches!(result, Err(AdapterError::MissingState)));
    }

    #[test]
    fn invalid_pair_denies_before_bridge() {
        let adapter = adapter();
        let now = SystemTime::now();

        let pair = valid_pair(now);
        let proof = valid_proof(now);

        let result = adapter.evaluate(now, HaloPairStatus::Invalid, Some(&pair), Some(&proof));

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

        let result = adapter.evaluate(now, HaloPairStatus::Valid, Some(&pair), Some(&proof));

        assert!(result.is_err());
    }

    #[test]
    fn revoked_proof_denies_before_bridge() {
        let adapter = adapter();
        let now = SystemTime::now();

        let pair = valid_pair(now);
        let mut proof = valid_proof(now);
        proof.is_revoked = true;

        let result = adapter.evaluate(now, HaloPairStatus::Valid, Some(&pair), Some(&proof));

        assert!(result.is_err());
    }

    #[test]
    fn replayed_proof_denies_before_bridge() {
        let adapter = adapter();
        let now = SystemTime::now();

        let pair = valid_pair(now);
        let mut proof = valid_proof(now);
        proof.is_replayed = true;

        let result = adapter.evaluate(now, HaloPairStatus::Valid, Some(&pair), Some(&proof));

        assert!(result.is_err());
    }

    #[test]
    fn bridge_denial_never_becomes_allow() {
        let adapter = adapter();
        let now = SystemTime::now();

        let pair = valid_pair(now);
        let proof = valid_proof(now);

        let result = adapter.evaluate(now, HaloPairStatus::Valid, Some(&pair), Some(&proof));

        assert!(!matches!(result, Ok(BridgeDecision::Allow)));
    }
}
