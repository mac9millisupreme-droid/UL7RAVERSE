from __future__ import annotations

from dataclasses import dataclass, asdict
from datetime import datetime, timezone
import hashlib
import json
from typing import Any


VALID_STATES = {"VERIFIED", "UNKNOWN", "FAILED", "BLOCKED"}


def canonical_json(value: Any) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


@dataclass(frozen=True)
class EvidenceReceipt:
    receipt_id: str
    claim: str
    state: str
    scope: str
    policy_version: str
    evidence_hash: str
    verified_at: str
    source_type: str
    limitations: tuple[str, ...]


class EcholessCore:
    """
    Proof-first processing boundary.

    Raw evidence is processed transiently.
    Only the minimum verification receipt is retained.
    """

    def __init__(self, policy_version: str):
        self.policy_version = policy_version
        self.receipts: dict[str, EvidenceReceipt] = {}

    def verify(
        self,
        *,
        claim: str,
        evidence: Any | None,
        scope: str,
        source_type: str,
        limitations: list[str] | None = None,
    ) -> EvidenceReceipt:

        limitations = limitations or []

        if evidence is None:
            state = "UNKNOWN"
            evidence_hash = ""
        else:
            evidence_hash = sha256_bytes(canonical_json(evidence))
            state = "VERIFIED"

        verified_at = datetime.now(timezone.utc).isoformat()

        receipt_material = {
            "claim": claim,
            "state": state,
            "scope": scope,
            "policy_version": self.policy_version,
            "evidence_hash": evidence_hash,
            "verified_at": verified_at,
        }

        receipt_id = sha256_bytes(canonical_json(receipt_material))

        receipt = EvidenceReceipt(
            receipt_id=receipt_id,
            claim=claim,
            state=state,
            scope=scope,
            policy_version=self.policy_version,
            evidence_hash=evidence_hash,
            verified_at=verified_at,
            source_type=source_type,
            limitations=tuple(limitations),
        )

        # Retain receipt only. Do not retain original evidence.
        self.receipts[receipt_id] = receipt

        return receipt

    def get_receipt(self, receipt_id: str) -> EvidenceReceipt:
        if receipt_id not in self.receipts:
            raise KeyError(f"RECEIPT NOT FOUND: {receipt_id}")

        return self.receipts[receipt_id]

    def export_receipt(self, receipt_id: str) -> str:
        return json.dumps(
            asdict(self.get_receipt(receipt_id)),
            indent=2,
        )


def self_test() -> None:
    core = EcholessCore("ECHOLESS-1.0")

    evidence = {
        "requirement": "approved_control_present",
        "result": True,
    }

    receipt = core.verify(
        claim="Required security control is present.",
        evidence=evidence,
        scope="defined_security_control",
        source_type="AUTHORIZED_SYSTEM",
    )

    del evidence

    assert receipt.state == "VERIFIED"
    assert receipt.evidence_hash
    assert receipt.receipt_id

    unknown = core.verify(
        claim="Independent verification exists.",
        evidence=None,
        scope="independent_verification",
        source_type="NONE",
    )

    assert unknown.state == "UNKNOWN"
    assert unknown.evidence_hash == ""

    assert all(
        r.state in VALID_STATES
        for r in core.receipts.values()
    )

    print("ECHOLESS CORE = PASS")
    print("RAW DATA RETENTION = NONE")
    print("VERIFIED EVIDENCE RECEIPT = PASS")
    print("UNKNOWN DISCLOSURE = PASS")
    print(f"RECEIPTS = {len(core.receipts)}")


if __name__ == "__main__":
    self_test()
