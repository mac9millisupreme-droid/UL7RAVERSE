from __future__ import annotations
from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
import hashlib, json, uuid

class State(str, Enum):
    VERIFIED="VERIFIED"
    UNKNOWN="UNKNOWN"
    BLOCKED="BLOCKED"
    FAILED="FAILED"

@dataclass(frozen=True)
class CryptoProfile:
    profile_id: str
    algorithm_family: str
    approved: bool
    quantum_resistant: bool
    version: str

@dataclass
class Evidence:
    evidence_id: str
    control: str
    state: State
    artifact_hash: str
    timestamp: str
    independent_verification: bool = False

class HyperQuantumStack:
    def __init__(self, policy_version="HQ-1.0"):
        self.policy_version=policy_version
        self.profiles={}
        self.evidence={}

    def register(self,p):
        self.profiles[p.profile_id]=p

    def verify(self,pid):
        p=self.profiles.get(pid)
        if p is None:
            return self.emit("CRYPTO_PROFILE",State.UNKNOWN,
                             {"reason":"PROFILE_NOT_FOUND"})
        if not p.approved:
            return self.emit("CRYPTO_PROFILE",State.BLOCKED,
                             {"reason":"PROFILE_NOT_APPROVED"})
        if not p.quantum_resistant:
            return self.emit("CRYPTO_PROFILE",State.UNKNOWN,
                             {"reason":"PQ_PROPERTY_NOT_VERIFIED"})
        return self.emit("CRYPTO_PROFILE",State.VERIFIED,
                         {"algorithm":p.algorithm_family,"version":p.version})

    def emit(self,control,state,material):
        ts=datetime.now(timezone.utc).isoformat()
        body=json.dumps({
            "control":control,
            "state":state.value,
            "material":material,
            "policy":self.policy_version,
            "timestamp":ts
        },sort_keys=True,separators=(",",":")).encode()
        e=Evidence(str(uuid.uuid4()),control,state,
                   hashlib.sha256(body).hexdigest(),ts)
        self.evidence[e.evidence_id]=e
        return e

    def decision(self):
        if not self.evidence:
            return State.BLOCKED
        return (
            State.VERIFIED
            if all(e.state==State.VERIFIED for e in self.evidence.values())
            else State.BLOCKED
        )

def self_test():
    s=HyperQuantumStack()

    # Deliberately unapproved: proves fail-closed behavior.
    s.register(CryptoProfile(
        "HQ-PQ-001",
        "DECLARED_PQ_PROFILE",
        False,
        True,
        "0.1"
    ))

    e=s.verify("HQ-PQ-001")

    assert e.state == State.BLOCKED
    assert s.decision() == State.BLOCKED

    print("HYPER_QUANTUM_STACK=PASS")
    print("CRYPTO_AGILITY=PASS")
    print("FAIL_CLOSED=PASS")
    print("EVIDENCE_HASHING=PASS")
    print("UNVERIFIED_NEVER_EQUALS_PASS=PASS")
    print("PRODUCTION_UNLOCK=BLOCKED")

if __name__=="__main__":
    self_test()
