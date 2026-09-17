//! HALO Twin Pair V1
//!
//! Security boundary for UL7RAVERSE agents.
//! Core invariant:
//!     NO VALID HALO TWIN PAIR -> NO ACTION.
//!
//! This V1 deliberately contains NO production cryptography and NO production
//! authorization backend. Crypto is injected through `PairVerifier` so a
//! standardized PQC implementation can be added without changing governance.

use std::collections::BTreeSet;
use std::fmt;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ProofState {
    Unknown,
    Unverified,
    Valid,
    Blocked,
    Expired,
    Revoked,
    Compromised,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PairState {
    Unpaired,
    Pairing,
    Valid,
    Executing,
    ProofPending,
    Rolling,
    Expired,
    Revoked,
    Blocked,
    Compromised,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AgentHalf {
    pub agent_id: String,
    pub agent_key_id: String,
    pub mission_id: String,
    pub pair_serial: String,
    pub sequence: u64,
    pub capability_hash: String,
    pub proof_root: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct HaloHalf {
    pub halo_id: String,
    pub halo_key_id: String,
    pub mission_id: String,
    pub pair_serial: String,
    pub sequence: u64,
    pub capability_hash: String,
    pub proof_root: String,
    pub expires_at_epoch: u64,
    pub revoked: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PairEnvelope {
    pub agent: AgentHalf,
    pub halo: HaloHalf,
    pub signature: Vec<u8>,
    pub crypto_suite: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ProofArtifact {
    pub pair_serial: String,
    pub mission_id: String,
    pub sequence: u64,
    pub result_digest: String,
    pub proof_state: ProofState,
}

#[derive(Debug, PartialEq, Eq)]
pub enum PairError {
    NoPair,
    FieldMismatch(&'static str),
    Expired,
    Revoked,
    Replay,
    SignatureInvalid,
    UnknownCryptoSuite,
    InvalidState,
}

impl fmt::Display for PairError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{:?}", self)
    }
}

pub trait PairVerifier {
    fn supported(&self, suite: &str) -> bool;
    fn verify(&self, envelope: &PairEnvelope) -> bool;
}

/// Production-safe default: refuses all cryptographic verification.
/// This prevents accidental production authorization before a real provider
/// is wired in and independently tested.
pub struct FailClosedVerifier;

impl PairVerifier for FailClosedVerifier {
    fn supported(&self, _suite: &str) -> bool {
        false
    }
    fn verify(&self, _envelope: &PairEnvelope) -> bool {
        false
    }
}

/// Test-only verifier. It accepts exactly the byte string `TEST-VALID`.
/// Never use this verifier for real authorization.
#[cfg(test)]
pub struct TestVerifier;

#[cfg(test)]
impl PairVerifier for TestVerifier {
    fn supported(&self, suite: &str) -> bool {
        suite == "TEST_ONLY"
    }
    fn verify(&self, envelope: &PairEnvelope) -> bool {
        envelope.signature == b"TEST-VALID"
    }
}

pub struct HaloTwinPair<V: PairVerifier> {
    verifier: V,
    state: PairState,
    current_sequence: Option<u64>,
    used_nonces: BTreeSet<String>,
}

impl<V: PairVerifier> HaloTwinPair<V> {
    pub fn new(verifier: V) -> Self {
        Self {
            verifier,
            state: PairState::Unpaired,
            current_sequence: None,
            used_nonces: BTreeSet::new(),
        }
    }

    pub fn state(&self) -> PairState {
        self.state
    }

    pub fn establish_pair(
        &mut self,
        envelope: &PairEnvelope,
        now_epoch: u64,
        nonce: &str,
    ) -> Result<(), PairError> {
        self.state = PairState::Pairing;

        if !self.verifier.supported(&envelope.crypto_suite) {
            return self.block(PairError::UnknownCryptoSuite);
        }
        if !self.fields_match(envelope) {
            return self.block(PairError::FieldMismatch("pair-binding"));
        }
        if envelope.halo.revoked {
            return self.block(PairError::Revoked);
        }
        if envelope.halo.expires_at_epoch <= now_epoch {
            return self.block(PairError::Expired);
        }
        if self.used_nonces.contains(nonce) {
            return self.block(PairError::Replay);
        }
        if let Some(seq) = self.current_sequence {
            if envelope.agent.sequence <= seq {
                return self.block(PairError::Replay);
            }
        }
        if !self.verifier.verify(envelope) {
            return self.block(PairError::SignatureInvalid);
        }

        self.used_nonces.insert(nonce.to_owned());
        self.current_sequence = Some(envelope.agent.sequence);
        self.state = PairState::Valid;
        Ok(())
    }

    pub fn begin_action(&mut self) -> Result<(), PairError> {
        if self.state != PairState::Valid {
            return self.block(PairError::InvalidState);
        }
        self.state = PairState::Executing;
        Ok(())
    }

    pub fn submit_proof(&mut self, proof: &ProofArtifact) -> Result<(), PairError> {
        if self.state != PairState::Executing {
            return self.block(PairError::InvalidState);
        }
        if proof.proof_state != ProofState::Valid {
            return self.block(PairError::InvalidState);
        }
        if Some(proof.sequence) != self.current_sequence {
            return self.block(PairError::Replay);
        }
        self.state = PairState::Rolling;
        Ok(())
    }

    pub fn rollover(
        &mut self,
        next: &PairEnvelope,
        now_epoch: u64,
        nonce: &str,
    ) -> Result<(), PairError> {
        if self.state != PairState::Rolling {
            return self.block(PairError::InvalidState);
        }
        self.establish_pair(next, now_epoch, nonce)
    }

    pub fn revoke(&mut self) {
        self.state = PairState::Revoked;
    }
    pub fn expire(&mut self) {
        self.state = PairState::Expired;
    }
    pub fn compromise(&mut self) {
        self.state = PairState::Compromised;
    }

    /// The only action gate. Every caller must pass this gate.
    pub fn action_allowed(&self) -> bool {
        self.state == PairState::Valid
    }

    fn fields_match(&self, e: &PairEnvelope) -> bool {
        e.agent.mission_id == e.halo.mission_id
            && e.agent.pair_serial == e.halo.pair_serial
            && e.agent.sequence == e.halo.sequence
            && e.agent.capability_hash == e.halo.capability_hash
            && e.agent.proof_root == e.halo.proof_root
    }

    fn block<T>(&mut self, err: PairError) -> Result<T, PairError> {
        self.state = PairState::Blocked;
        Err(err)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn envelope(serial: &str, mission: &str, seq: u64, sig: &[u8]) -> PairEnvelope {
        PairEnvelope {
            agent: AgentHalf {
                agent_id: "agent-A".into(),
                agent_key_id: "ak-A".into(),
                mission_id: mission.into(),
                pair_serial: serial.into(),
                sequence: seq,
                capability_hash: "cap-1".into(),
                proof_root: "proof-1".into(),
            },
            halo: HaloHalf {
                halo_id: "halo-A".into(),
                halo_key_id: "hk-A".into(),
                mission_id: mission.into(),
                pair_serial: serial.into(),
                sequence: seq,
                capability_hash: "cap-1".into(),
                proof_root: "proof-1".into(),
                expires_at_epoch: 1000,
                revoked: false,
            },
            signature: sig.to_vec(),
            crypto_suite: "TEST_ONLY".into(),
        }
    }

    #[test]
    fn valid_pair_is_actionable() {
        let mut p = HaloTwinPair::new(TestVerifier);
        assert!(p
            .establish_pair(&envelope("S1", "M1", 1, b"TEST-VALID"), 10, "N1")
            .is_ok());
        assert_eq!(p.state(), PairState::Valid);
        assert!(p.action_allowed());
    }

    #[test]
    fn missing_or_invalid_crypto_means_no_action() {
        let mut p = HaloTwinPair::new(FailClosedVerifier);
        assert_eq!(
            p.establish_pair(&envelope("S1", "M1", 1, b"anything"), 10, "N1"),
            Err(PairError::UnknownCryptoSuite)
        );
        assert!(!p.action_allowed());
    }

    #[test]
    fn mismatched_pair_is_blocked() {
        let mut e = envelope("S1", "M1", 1, b"TEST-VALID");
        e.halo.pair_serial = "S2".into();
        let mut p = HaloTwinPair::new(TestVerifier);
        assert_eq!(
            p.establish_pair(&e, 10, "N1"),
            Err(PairError::FieldMismatch("pair-binding"))
        );
        assert_eq!(p.state(), PairState::Blocked);
    }

    #[test]
    fn expired_pair_is_blocked() {
        let mut p = HaloTwinPair::new(TestVerifier);
        assert_eq!(
            p.establish_pair(&envelope("S1", "M1", 1, b"TEST-VALID"), 1000, "N1"),
            Err(PairError::Expired)
        );
        assert!(!p.action_allowed());
    }

    #[test]
    fn revoked_pair_is_blocked() {
        let mut e = envelope("S1", "M1", 1, b"TEST-VALID");
        e.halo.revoked = true;
        let mut p = HaloTwinPair::new(TestVerifier);
        assert_eq!(p.establish_pair(&e, 10, "N1"), Err(PairError::Revoked));
        assert!(!p.action_allowed());
    }

    #[test]
    fn replayed_nonce_is_blocked() {
        let mut p = HaloTwinPair::new(TestVerifier);
        let e = envelope("S1", "M1", 1, b"TEST-VALID");
        assert!(p.establish_pair(&e, 10, "N1").is_ok());
        p.state = PairState::Rolling;
        let e2 = envelope("S2", "M1", 2, b"TEST-VALID");
        assert_eq!(p.rollover(&e2, 10, "N1"), Err(PairError::Replay));
        assert!(!p.action_allowed());
    }

    #[test]
    fn old_sequence_is_blocked() {
        let mut p = HaloTwinPair::new(TestVerifier);
        let e1 = envelope("S1", "M1", 2, b"TEST-VALID");
        assert!(p.establish_pair(&e1, 10, "N1").is_ok());
        p.state = PairState::Rolling;
        let e0 = envelope("S0", "M1", 1, b"TEST-VALID");
        assert_eq!(p.rollover(&e0, 10, "N0"), Err(PairError::Replay));
        assert!(!p.action_allowed());
    }

    #[test]
    fn proof_is_required_before_rollover() {
        let mut p = HaloTwinPair::new(TestVerifier);
        let e = envelope("S1", "M1", 1, b"TEST-VALID");
        assert!(p.establish_pair(&e, 10, "N1").is_ok());
        assert!(p.begin_action().is_ok());
        let bad = ProofArtifact {
            pair_serial: "S1".into(),
            mission_id: "M1".into(),
            sequence: 1,
            result_digest: "x".into(),
            proof_state: ProofState::Unknown,
        };
        assert_eq!(p.submit_proof(&bad), Err(PairError::InvalidState));
        assert!(!p.action_allowed());
    }

    #[test]
    fn valid_proof_enables_rolling_but_not_old_action() {
        let mut p = HaloTwinPair::new(TestVerifier);
        let e1 = envelope("S1", "M1", 1, b"TEST-VALID");
        assert!(p.establish_pair(&e1, 10, "N1").is_ok());
        assert!(p.begin_action().is_ok());
        let proof = ProofArtifact {
            pair_serial: "S1".into(),
            mission_id: "M1".into(),
            sequence: 1,
            result_digest: "digest".into(),
            proof_state: ProofState::Valid,
        };
        assert!(p.submit_proof(&proof).is_ok());
        assert!(!p.action_allowed());
        let e2 = envelope("S2", "M1", 2, b"TEST-VALID");
        assert!(p.rollover(&e2, 10, "N2").is_ok());
        assert!(p.action_allowed());
    }

    #[test]
    fn explicit_revoke_is_fail_closed() {
        let mut p = HaloTwinPair::new(TestVerifier);
        assert!(p
            .establish_pair(&envelope("S1", "M1", 1, b"TEST-VALID"), 10, "N1")
            .is_ok());
        assert!(p.action_allowed());
        p.revoke();
        assert!(!p.action_allowed());
    }
}
