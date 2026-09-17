use std::fmt;
use std::time::{Duration, SystemTime};

use serde::{Deserialize, Serialize};
use thiserror::Error;

// ==================================================
// CORE IDENTITIES
// ==================================================

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct AgentId(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct HaloTwinId(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct MissionId(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct CapabilityId(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct BridgeVersion(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct CryptographicProfileId(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct LedgerEntryId(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct ProofId(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Nonce(pub [u8; 32]);

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Timestamp(pub SystemTime);

// ==================================================
// DECISIONS
// ==================================================

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum GovernanceAuthority {
    Allow,
    Deny,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum BridgeDecision {
    Allow,
    Deny,
}

impl BridgeDecision {
    pub fn is_allow(&self) -> bool {
        matches!(self, Self::Allow)
    }

    pub fn is_deny(&self) -> bool {
        matches!(self, Self::Deny)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum CheetahPolicyDecision {
    Allow,
    Deny,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum HaloPairStatus {
    Valid,
    Invalid,
    Stale,
    Revoked,
    Compromised,
    Replayed,
    Unknown,
}

impl HaloPairStatus {
    pub fn is_strictly_valid(&self) -> bool {
        matches!(self, Self::Valid)
    }
}

// ==================================================
// FAIL-CLOSED ERRORS
// ==================================================

#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum AuthorityError {
    #[error("No agent present")]
    NoAgent,

    #[error("No HALO twin present")]
    NoHaloTwin,

    #[error("Invalid HALO pair: {0:?}")]
    InvalidHaloPair(HaloPairStatus),

    #[error("Proof invalid or missing")]
    InvalidProof,

    #[error("Proof HALO identity does not match pair")]
    HaloPairMismatch,

    #[error("Proof mission binding does not match pair")]
    MissionMismatch,

    #[error("Proof capability binding does not match pair")]
    CapabilityMismatch,

    #[error("Pair expired")]
    PairExpired,

    #[error("Pair revoked")]
    PairRevoked,

    #[error("Pair replay detected")]
    PairReplay,

    #[error("Cheetah policy denied")]
    CheetahDenied,

    #[error("Bridge invariants violated")]
    BridgeInvariantViolation,

    #[error("Bridge authority denied")]
    BridgeDenied,

    #[error("Production cryptographic provider unavailable")]
    ProductionCryptoNotConfigured,

    #[error("Cryptographic verification failure")]
    CryptoVerificationFailure,

    #[error("Ledger verification failure")]
    LedgerVerificationFailure,
}

// ==================================================
// HALO PAIR
// ==================================================

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HaloPair {
    pub agent_id: AgentId,
    pub halo_twin_id: HaloTwinId,
    pub mission_id: MissionId,
    pub capability_id: CapabilityId,
    pub created_at: Timestamp,
    pub expires_at: Timestamp,
    pub nonce: Nonce,
    pub ledger_entry_id: LedgerEntryId,
}

impl HaloPair {
    pub fn is_expired(&self, now: SystemTime) -> bool {
        now > self.expires_at.0
    }

    pub fn lifetime(&self) -> Option<Duration> {
        self.expires_at.0.duration_since(self.created_at.0).ok()
    }
}

// ==================================================
// PROOF STATE
// ==================================================

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProofState {
    pub proof_id: ProofId,
    pub halo_pair_id: HaloTwinId,
    pub mission_id: MissionId,
    pub capability_id: CapabilityId,
    pub cryptographic_profile_id: CryptographicProfileId,
    pub issued_at: Timestamp,
    pub ledger_entry_id: LedgerEntryId,
    pub is_bound_to_mission: bool,
    pub is_bound_to_capability: bool,
    pub is_revoked: bool,
    pub is_replayed: bool,
}

impl ProofState {
    pub fn is_valid(&self) -> bool {
        !self.is_revoked
            && !self.is_replayed
            && self.is_bound_to_mission
            && self.is_bound_to_capability
    }
}

// ==================================================
// PROVIDER INTERFACES
// ==================================================

pub trait CryptographicProvider: Send + Sync {
    fn id(&self) -> CryptographicProfileId;

    fn verify_pair_binding(
        &self,
        pair: &HaloPair,
        proof: &ProofState,
    ) -> Result<(), AuthorityError>;

    fn verify_ledger_entry(&self, ledger_entry_id: &LedgerEntryId) -> Result<(), AuthorityError>;
}

pub trait CheetahPolicy: Send + Sync {
    fn evaluate(
        &self,
        pair: &HaloPair,
        proof: &ProofState,
    ) -> Result<CheetahPolicyDecision, AuthorityError>;
}

pub trait BridgeInvariants: Send + Sync {
    fn check_invariants(
        &self,
        pair: &HaloPair,
        proof: &ProofState,
        bridge_version: &BridgeVersion,
    ) -> Result<(), AuthorityError>;
}

pub trait BridgeAuthority: Send + Sync {
    fn version(&self) -> BridgeVersion;

    fn decide(&self, pair: &HaloPair, proof: &ProofState)
        -> Result<BridgeDecision, AuthorityError>;
}

// ==================================================
// CONTRACT
// ==================================================

pub struct AuthorityContract<'a> {
    pub cryptographic_provider: Option<&'a dyn CryptographicProvider>,
    pub cheetah_policy: &'a dyn CheetahPolicy,
    pub bridge_invariants: &'a dyn BridgeInvariants,
    pub bridge_authority: &'a dyn BridgeAuthority,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ActionAuthorization {
    Allowed,
    Denied(AuthorityError),
}

impl fmt::Display for ActionAuthorization {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Allowed => write!(f, "ACTION_ALLOWED"),
            Self::Denied(err) => write!(f, "ACTION_DENIED: {}", err),
        }
    }
}

impl<'a> AuthorityContract<'a> {
    pub fn authorize(
        &self,
        now: SystemTime,
        pair_status: HaloPairStatus,
        pair: Option<&HaloPair>,
        proof: Option<&ProofState>,
    ) -> ActionAuthorization {
        // ------------------------------------------
        // 1. AGENT
        // ------------------------------------------

        let pair = match pair {
            Some(p) => p,
            None => return ActionAuthorization::Denied(AuthorityError::NoAgent),
        };

        // ------------------------------------------
        // 2. HALO
        // ------------------------------------------

        if pair.halo_twin_id.0.is_empty() {
            return ActionAuthorization::Denied(AuthorityError::NoHaloTwin);
        }

        // ------------------------------------------
        // 3. PAIR STATUS
        // ------------------------------------------

        if !pair_status.is_strictly_valid() {
            return ActionAuthorization::Denied(AuthorityError::InvalidHaloPair(pair_status));
        }

        // ------------------------------------------
        // 4. EXPIRY
        // ------------------------------------------

        if pair.is_expired(now) {
            return ActionAuthorization::Denied(AuthorityError::PairExpired);
        }

        // ------------------------------------------
        // 5. PROOF
        // ------------------------------------------

        let proof = match proof {
            Some(p) => p,
            None => return ActionAuthorization::Denied(AuthorityError::InvalidProof),
        };

        // ------------------------------------------
        // 6. PROOF STATUS
        // ------------------------------------------

        if proof.is_revoked {
            return ActionAuthorization::Denied(AuthorityError::PairRevoked);
        }

        if proof.is_replayed {
            return ActionAuthorization::Denied(AuthorityError::PairReplay);
        }

        if !proof.is_bound_to_mission {
            return ActionAuthorization::Denied(AuthorityError::MissionMismatch);
        }

        if !proof.is_bound_to_capability {
            return ActionAuthorization::Denied(AuthorityError::CapabilityMismatch);
        }

        if !proof.is_valid() {
            return ActionAuthorization::Denied(AuthorityError::InvalidProof);
        }

        // ------------------------------------------
        // 7. PAIR / PROOF IDENTITY BINDING
        // ------------------------------------------

        if proof.halo_pair_id != pair.halo_twin_id {
            return ActionAuthorization::Denied(AuthorityError::HaloPairMismatch);
        }

        if proof.mission_id != pair.mission_id {
            return ActionAuthorization::Denied(AuthorityError::MissionMismatch);
        }

        if proof.capability_id != pair.capability_id {
            return ActionAuthorization::Denied(AuthorityError::CapabilityMismatch);
        }

        // ------------------------------------------
        // 8. PRODUCTION CRYPTOGRAPHIC PROVIDER
        // ------------------------------------------

        let provider = match self.cryptographic_provider {
            Some(provider) => provider,
            None => {
                return ActionAuthorization::Denied(AuthorityError::ProductionCryptoNotConfigured)
            }
        };

        // ------------------------------------------
        // 9. CRYPTOGRAPHIC PAIR VERIFICATION
        // ------------------------------------------

        if let Err(e) = provider.verify_pair_binding(pair, proof) {
            return ActionAuthorization::Denied(e);
        }

        // ------------------------------------------
        // 10. LEDGER VERIFICATION
        // ------------------------------------------

        if let Err(e) = provider.verify_ledger_entry(&proof.ledger_entry_id) {
            return ActionAuthorization::Denied(e);
        }

        // ------------------------------------------
        // 11. CHEETAH POLICY
        // ------------------------------------------

        match self.cheetah_policy.evaluate(pair, proof) {
            Ok(CheetahPolicyDecision::Allow) => {}
            Ok(CheetahPolicyDecision::Deny) => {
                return ActionAuthorization::Denied(AuthorityError::CheetahDenied)
            }
            Err(e) => return ActionAuthorization::Denied(e),
        }

        // ------------------------------------------
        // 12. BRIDGE INVARIANTS
        // ------------------------------------------

        if let Err(e) =
            self.bridge_invariants
                .check_invariants(pair, proof, &self.bridge_authority.version())
        {
            return ActionAuthorization::Denied(e);
        }

        // ------------------------------------------
        // 13. REAL BRIDGE AUTHORITY
        // ------------------------------------------

        match self.bridge_authority.decide(pair, proof) {
            Ok(BridgeDecision::Allow) => ActionAuthorization::Allowed,
            Ok(BridgeDecision::Deny) => ActionAuthorization::Denied(AuthorityError::BridgeDenied),
            Err(e) => ActionAuthorization::Denied(e),
        }
    }
}

// ==================================================
// TEST PROVIDERS ONLY
// ==================================================

pub struct TestCryptographicProvider {
    pub allow: bool,
}

impl CryptographicProvider for TestCryptographicProvider {
    fn id(&self) -> CryptographicProfileId {
        CryptographicProfileId("TEST-CRYPTO".into())
    }

    fn verify_pair_binding(
        &self,
        _pair: &HaloPair,
        _proof: &ProofState,
    ) -> Result<(), AuthorityError> {
        if self.allow {
            Ok(())
        } else {
            Err(AuthorityError::CryptoVerificationFailure)
        }
    }

    fn verify_ledger_entry(&self, _ledger_entry_id: &LedgerEntryId) -> Result<(), AuthorityError> {
        if self.allow {
            Ok(())
        } else {
            Err(AuthorityError::LedgerVerificationFailure)
        }
    }
}

pub struct AllowCheetah;

impl CheetahPolicy for AllowCheetah {
    fn evaluate(
        &self,
        _pair: &HaloPair,
        _proof: &ProofState,
    ) -> Result<CheetahPolicyDecision, AuthorityError> {
        Ok(CheetahPolicyDecision::Allow)
    }
}

pub struct DenyCheetah;

impl CheetahPolicy for DenyCheetah {
    fn evaluate(
        &self,
        _pair: &HaloPair,
        _proof: &ProofState,
    ) -> Result<CheetahPolicyDecision, AuthorityError> {
        Ok(CheetahPolicyDecision::Deny)
    }
}

pub struct AllowInvariants;

impl BridgeInvariants for AllowInvariants {
    fn check_invariants(
        &self,
        _pair: &HaloPair,
        _proof: &ProofState,
        _bridge_version: &BridgeVersion,
    ) -> Result<(), AuthorityError> {
        Ok(())
    }
}

pub struct AllowBridge;

impl BridgeAuthority for AllowBridge {
    fn version(&self) -> BridgeVersion {
        BridgeVersion("TEST-BRIDGE".into())
    }

    fn decide(
        &self,
        _pair: &HaloPair,
        _proof: &ProofState,
    ) -> Result<BridgeDecision, AuthorityError> {
        Ok(BridgeDecision::Allow)
    }
}

pub struct DenyBridge;

impl BridgeAuthority for DenyBridge {
    fn version(&self) -> BridgeVersion {
        BridgeVersion("TEST-BRIDGE".into())
    }

    fn decide(
        &self,
        _pair: &HaloPair,
        _proof: &ProofState,
    ) -> Result<BridgeDecision, AuthorityError> {
        Ok(BridgeDecision::Deny)
    }
}

// ==================================================
// TEST FIXTURES
// ==================================================

#[cfg(test)]
mod tests {
    use super::*;

    fn fixture() -> (HaloPair, ProofState) {
        let now = SystemTime::now();

        let pair = HaloPair {
            agent_id: AgentId("agent-1".into()),
            halo_twin_id: HaloTwinId("halo-1".into()),
            mission_id: MissionId("mission-1".into()),
            capability_id: CapabilityId("cap-1".into()),
            created_at: Timestamp(now),
            expires_at: Timestamp(now + Duration::from_secs(60)),
            nonce: Nonce([7u8; 32]),
            ledger_entry_id: LedgerEntryId("ledger-1".into()),
        };

        let proof = ProofState {
            proof_id: ProofId("proof-1".into()),
            halo_pair_id: HaloTwinId("halo-1".into()),
            mission_id: MissionId("mission-1".into()),
            capability_id: CapabilityId("cap-1".into()),
            cryptographic_profile_id: CryptographicProfileId("TEST-CRYPTO".into()),
            issued_at: Timestamp(now),
            ledger_entry_id: LedgerEntryId("ledger-1".into()),
            is_bound_to_mission: true,
            is_bound_to_capability: true,
            is_revoked: false,
            is_replayed: false,
        };

        (pair, proof)
    }

    fn contract<'a>(
        provider: Option<&'a dyn CryptographicProvider>,
        cheetah: &'a dyn CheetahPolicy,
        invariants: &'a dyn BridgeInvariants,
        bridge: &'a dyn BridgeAuthority,
    ) -> AuthorityContract<'a> {
        AuthorityContract {
            cryptographic_provider: provider,
            cheetah_policy: cheetah,
            bridge_invariants: invariants,
            bridge_authority: bridge,
        }
    }

    #[test]
    fn no_agent_denies() {
        let c = contract(None, &AllowCheetah, &AllowInvariants, &AllowBridge);
        let auth = c.authorize(SystemTime::now(), HaloPairStatus::Valid, None, None);

        assert!(matches!(
            auth,
            ActionAuthorization::Denied(AuthorityError::NoAgent)
        ));
    }

    #[test]
    fn no_halo_denies() {
        let (mut pair, proof) = fixture();
        pair.halo_twin_id = HaloTwinId(String::new());

        let c = contract(None, &AllowCheetah, &AllowInvariants, &AllowBridge);

        let auth = c.authorize(
            SystemTime::now(),
            HaloPairStatus::Valid,
            Some(&pair),
            Some(&proof),
        );

        assert!(matches!(
            auth,
            ActionAuthorization::Denied(AuthorityError::NoHaloTwin)
        ));
    }

    #[test]
    fn invalid_pair_denies() {
        let (pair, proof) = fixture();

        let c = contract(None, &AllowCheetah, &AllowInvariants, &AllowBridge);

        let auth = c.authorize(
            SystemTime::now(),
            HaloPairStatus::Compromised,
            Some(&pair),
            Some(&proof),
        );

        assert!(matches!(
            auth,
            ActionAuthorization::Denied(AuthorityError::InvalidHaloPair(
                HaloPairStatus::Compromised
            ))
        ));
    }

    #[test]
    fn expired_pair_denies() {
        let (mut pair, proof) = fixture();

        pair.expires_at = Timestamp(SystemTime::now() - Duration::from_secs(1));

        let c = contract(None, &AllowCheetah, &AllowInvariants, &AllowBridge);

        let auth = c.authorize(
            SystemTime::now(),
            HaloPairStatus::Valid,
            Some(&pair),
            Some(&proof),
        );

        assert!(matches!(
            auth,
            ActionAuthorization::Denied(AuthorityError::PairExpired)
        ));
    }

    #[test]
    fn missing_proof_denies() {
        let (pair, _) = fixture();

        let c = contract(None, &AllowCheetah, &AllowInvariants, &AllowBridge);

        let auth = c.authorize(SystemTime::now(), HaloPairStatus::Valid, Some(&pair), None);

        assert!(matches!(
            auth,
            ActionAuthorization::Denied(AuthorityError::InvalidProof)
        ));
    }

    #[test]
    fn revoked_proof_denies() {
        let (pair, mut proof) = fixture();
        proof.is_revoked = true;

        let c = contract(None, &AllowCheetah, &AllowInvariants, &AllowBridge);

        let auth = c.authorize(
            SystemTime::now(),
            HaloPairStatus::Valid,
            Some(&pair),
            Some(&proof),
        );

        assert!(matches!(
            auth,
            ActionAuthorization::Denied(AuthorityError::PairRevoked)
        ));
    }

    #[test]
    fn replayed_proof_denies() {
        let (pair, mut proof) = fixture();
        proof.is_replayed = true;

        let c = contract(None, &AllowCheetah, &AllowInvariants, &AllowBridge);

        let auth = c.authorize(
            SystemTime::now(),
            HaloPairStatus::Valid,
            Some(&pair),
            Some(&proof),
        );

        assert!(matches!(
            auth,
            ActionAuthorization::Denied(AuthorityError::PairReplay)
        ));
    }

    #[test]
    fn halo_pair_mismatch_denies() {
        let (pair, mut proof) = fixture();
        proof.halo_pair_id = HaloTwinId("other-halo".into());

        let c = contract(None, &AllowCheetah, &AllowInvariants, &AllowBridge);

        let auth = c.authorize(
            SystemTime::now(),
            HaloPairStatus::Valid,
            Some(&pair),
            Some(&proof),
        );

        assert!(matches!(
            auth,
            ActionAuthorization::Denied(AuthorityError::HaloPairMismatch)
        ));
    }

    #[test]
    fn mission_mismatch_denies() {
        let (pair, mut proof) = fixture();
        proof.mission_id = MissionId("other-mission".into());

        let c = contract(None, &AllowCheetah, &AllowInvariants, &AllowBridge);

        let auth = c.authorize(
            SystemTime::now(),
            HaloPairStatus::Valid,
            Some(&pair),
            Some(&proof),
        );

        assert!(matches!(
            auth,
            ActionAuthorization::Denied(AuthorityError::MissionMismatch)
        ));
    }

    #[test]
    fn capability_mismatch_denies() {
        let (pair, mut proof) = fixture();
        proof.capability_id = CapabilityId("other-cap".into());

        let c = contract(None, &AllowCheetah, &AllowInvariants, &AllowBridge);

        let auth = c.authorize(
            SystemTime::now(),
            HaloPairStatus::Valid,
            Some(&pair),
            Some(&proof),
        );

        assert!(matches!(
            auth,
            ActionAuthorization::Denied(AuthorityError::CapabilityMismatch)
        ));
    }

    #[test]
    fn no_production_crypto_denies() {
        let (pair, proof) = fixture();

        let c = contract(None, &AllowCheetah, &AllowInvariants, &AllowBridge);

        let auth = c.authorize(
            SystemTime::now(),
            HaloPairStatus::Valid,
            Some(&pair),
            Some(&proof),
        );

        assert!(matches!(
            auth,
            ActionAuthorization::Denied(AuthorityError::ProductionCryptoNotConfigured)
        ));
    }

    #[test]
    fn crypto_failure_denies() {
        let (pair, proof) = fixture();
        let provider = TestCryptographicProvider { allow: false };

        let c = contract(
            Some(&provider),
            &AllowCheetah,
            &AllowInvariants,
            &AllowBridge,
        );

        let auth = c.authorize(
            SystemTime::now(),
            HaloPairStatus::Valid,
            Some(&pair),
            Some(&proof),
        );

        assert!(matches!(
            auth,
            ActionAuthorization::Denied(AuthorityError::CryptoVerificationFailure)
        ));
    }

    #[test]
    fn cheetah_denial_blocks() {
        let (pair, proof) = fixture();
        let provider = TestCryptographicProvider { allow: true };

        let c = contract(
            Some(&provider),
            &DenyCheetah,
            &AllowInvariants,
            &AllowBridge,
        );

        let auth = c.authorize(
            SystemTime::now(),
            HaloPairStatus::Valid,
            Some(&pair),
            Some(&proof),
        );

        assert!(matches!(
            auth,
            ActionAuthorization::Denied(AuthorityError::CheetahDenied)
        ));
    }

    #[test]
    fn bridge_denial_blocks() {
        let (pair, proof) = fixture();
        let provider = TestCryptographicProvider { allow: true };

        let c = contract(
            Some(&provider),
            &AllowCheetah,
            &AllowInvariants,
            &DenyBridge,
        );

        let auth = c.authorize(
            SystemTime::now(),
            HaloPairStatus::Valid,
            Some(&pair),
            Some(&proof),
        );

        assert!(matches!(
            auth,
            ActionAuthorization::Denied(AuthorityError::BridgeDenied)
        ));
    }

    #[test]
    fn complete_valid_chain_allows_only_with_explicit_provider() {
        let (pair, proof) = fixture();
        let provider = TestCryptographicProvider { allow: true };

        let c = contract(
            Some(&provider),
            &AllowCheetah,
            &AllowInvariants,
            &AllowBridge,
        );

        let auth = c.authorize(
            SystemTime::now(),
            HaloPairStatus::Valid,
            Some(&pair),
            Some(&proof),
        );

        assert_eq!(auth, ActionAuthorization::Allowed);
    }
}
