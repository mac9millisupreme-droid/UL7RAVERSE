//! HALO9 -> UL7RABRIDGE authority boundary.
//!
//! This module defines an integration contract, not a claim that the real
//! UL7RABRIDGE has been modified. The bridge remains the authority boundary.
//! The HALO pair can only be one prerequisite for authorization.

use crate::{HaloTwinPair, PairError, PairVerifier};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BridgeDecision {
    Allow,
    Deny,
}

#[derive(Debug, PartialEq, Eq)]
pub enum GateError {
    Pair(PairError),
    BridgeDenied,
}

pub trait BridgeAuthority {
    /// The real UL7RABRIDGE implementation must independently decide whether
    /// the requested action is authorized. HALO9 cannot grant authority here.
    fn authorize(&self, mission_id: &str, capability_hash: &str) -> BridgeDecision;
}

/// Combined gate: HALO pair MUST be valid AND the bridge MUST authorize.
/// Neither side can grant authority alone.
pub fn authorize_action<V, B>(
    pair: &HaloTwinPair<V>,
    bridge: &B,
    mission_id: &str,
    capability_hash: &str,
) -> Result<(), GateError>
where
    V: PairVerifier,
    B: BridgeAuthority,
{
    if !pair.action_allowed() {
        return Err(GateError::Pair(PairError::InvalidState));
    }

    match bridge.authorize(mission_id, capability_hash) {
        BridgeDecision::Allow => Ok(()),
        BridgeDecision::Deny => Err(GateError::BridgeDenied),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{AgentHalf, HaloHalf, PairEnvelope, TestVerifier};

    struct AllowBridge;
    impl BridgeAuthority for AllowBridge {
        fn authorize(&self, _: &str, _: &str) -> BridgeDecision {
            BridgeDecision::Allow
        }
    }

    struct DenyBridge;
    impl BridgeAuthority for DenyBridge {
        fn authorize(&self, _: &str, _: &str) -> BridgeDecision {
            BridgeDecision::Deny
        }
    }

    fn envelope() -> PairEnvelope {
        PairEnvelope {
            agent: AgentHalf {
                agent_id: "agent-A".into(),
                agent_key_id: "ak-A".into(),
                mission_id: "M1".into(),
                pair_serial: "S1".into(),
                sequence: 1,
                capability_hash: "cap-1".into(),
                proof_root: "proof-1".into(),
            },
            halo: HaloHalf {
                halo_id: "halo-A".into(),
                halo_key_id: "hk-A".into(),
                mission_id: "M1".into(),
                pair_serial: "S1".into(),
                sequence: 1,
                capability_hash: "cap-1".into(),
                proof_root: "proof-1".into(),
                expires_at_epoch: 1000,
                revoked: false,
            },
            signature: b"TEST-VALID".to_vec(),
            crypto_suite: "TEST_ONLY".into(),
        }
    }

    #[test]
    fn valid_pair_plus_bridge_allow_is_required() {
        let mut pair = HaloTwinPair::new(TestVerifier);
        assert!(pair.establish_pair(&envelope(), 10, "N1").is_ok());
        assert_eq!(authorize_action(&pair, &AllowBridge, "M1", "cap-1"), Ok(()));
    }

    #[test]
    fn valid_pair_cannot_override_bridge_deny() {
        let mut pair = HaloTwinPair::new(TestVerifier);
        assert!(pair.establish_pair(&envelope(), 10, "N1").is_ok());
        assert_eq!(
            authorize_action(&pair, &DenyBridge, "M1", "cap-1"),
            Err(GateError::BridgeDenied)
        );
    }

    #[test]
    fn invalid_pair_cannot_reach_bridge_allow() {
        let pair = HaloTwinPair::new(TestVerifier);
        assert_eq!(
            authorize_action(&pair, &AllowBridge, "M1", "cap-1"),
            Err(GateError::Pair(PairError::InvalidState))
        );
    }
}
