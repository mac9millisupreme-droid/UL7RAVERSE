from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
import json
import hashlib

ROOT = Path(__file__).resolve().parent
CLAIMS = ROOT / "claims"
REPORTS = ROOT / "reports"
for p in (CLAIMS, REPORTS):
    p.mkdir(exist_ok=True)

PROOF_STATES = {
    "HYPOTHESIS",
    "UNVERIFIED",
    "COMMUNITY_SIGNAL",
    "CORROBORATED",
    "VERIFIED",
    "CONFLICTED",
    "STALE",
    "REPEATABLE",
    "SCALE_READY",
}

DECISIONS = {"SCALE", "TEST", "HOLD", "KILL"}

@dataclass
class Claim:
    claim_id: str
    text: str
    source_type: str
    source: str
    timestamp: str
    evidence_count: int = 0
    independent_sources: int = 0
    contradictory_sources: int = 0
    proof_state: str = "UNVERIFIED"
    confidence: int = 0

def claim_id(text, source):
    raw = f"{text}|{source}".encode()
    return hashlib.sha256(raw).hexdigest()[:16]

def create_claim(text, source_type, source):
    cid = claim_id(text, source)
    c = Claim(
        claim_id=cid,
        text=text,
        source_type=source_type,
        source=source,
        timestamp=datetime.now(timezone.utc).isoformat(),
    )
    (CLAIMS / f"{cid}.json").write_text(
        json.dumps(asdict(c), indent=2), encoding="utf-8"
    )
    return c

def purple_attack(c):
    attacks = [
        "Could the source be stale?",
        "Could the claim be based on one person's experience?",
        "Could multiple reports originate from the same source?",
        "Could the situation have changed?",
        "Could this be promotional or adversarial?",
        "Is there contradictory evidence?",
        "Could publication unfairly damage a business?",
        "Does the evidence actually support the claim?",
        "Does commerce influence the proof state?",
    ]
    failures = []
    if c.evidence_count < 2 and c.proof_state == "VERIFIED":
        failures.append("VERIFIED requires stronger evidence.")
    if c.contradictory_sources:
        failures.append("Contradictory evidence exists.")
    return attacks, failures

def score_opportunity(
    pain, buyer, urgency, speed, capital, margin,
    whitespace, measurable, friction, repeatability
):
    values = [
        pain, buyer, urgency, speed, capital, margin,
        whitespace, measurable, friction, repeatability
    ]
    weights = [15,15,15,10,10,10,10,10,5,10]
    raw = sum(v*w for v,w in zip(values, weights))
    return round(raw / 1.1, 2)

def decision(score, purple_pass, proof_state):
    if not purple_pass:
        return "HOLD"
    if score >= 95 and proof_state in {"VERIFIED", "REPEATABLE", "SCALE_READY"}:
        return "SCALE"
    if score >= 80:
        return "TEST"
    return "HOLD"

if __name__ == "__main__":
    opportunities = [
        {
            "name": "Vendor Revenue Engine",
            "scores": [95,95,95,90,95,95,70,95,85,95]
        },
        {
            "name": "Fair Concierge",
            "scores": [90,90,95,95,95,95,75,95,90,95]
        },
        {
            "name": "Vendor Content Factory",
            "scores": [90,90,95,98,98,90,70,95,95,90]
        },
        {
            "name": "Fair Spillover Network",
            "scores": [88,90,90,85,90,95,65,90,70,95]
        },
        {
            "name": "Queue / Time Intelligence",
            "scores": [92,90,95,80,90,90,60,95,65,90]
        },
    ]

    ranked = []
    for o in opportunities:
        score = score_opportunity(*o["scores"])
        ranked.append({
            "opportunity": o["name"],
            "score": score,
            "proof_state": "HYPOTHESIS",
            "purple_team": "INCOMPLETE",
            "final_decision": "TEST" if score >= 80 else "HOLD",
            "revenue_verified": 0,
            "profit_verified": 0,
        })

    ranked.sort(key=lambda x: x["score"], reverse=True)

    report = {
        "project": "OMNIPULSE",
        "proof_layer": "UL7RAPROOF",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "status": "HYPOTHESIS_STAGE",
        "important": (
            "Scores are opportunity scores, not probabilities of commercial success. "
            "No opportunity is VERIFIED until real evidence exists."
        ),
        "ranked_opportunities": ranked,
        "required_next_loop": [
            "LIVE_RECON",
            "MICRO_TEST",
            "FIRST_PAYMENT",
            "PROOF",
            "PURPLE_ATTACK",
            "RETEST",
            "SCALE_OR_KILL",
        ],
    }

    (REPORTS / "INITIAL_DECISION.json").write_text(
        json.dumps(report, indent=2), encoding="utf-8"
    )

    print(json.dumps(report, indent=2))
