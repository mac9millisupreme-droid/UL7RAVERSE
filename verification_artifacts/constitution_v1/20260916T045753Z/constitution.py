
SPEC_ID = "UL7RA_CONSTITUTION/v1"

GATES = {
    "G1": ("L1_PROPOSED", "L2_BUILT", "PROPOSAL_WELLFORMED"),
    "G2": ("L2_BUILT", "L3_VERIFIED", "BUILD_REPRODUCIBLE"),
    "G3": ("L3_VERIFIED", "L4_PROVEN", "ADVERSARIAL_SURVIVAL"),
    "G4": ("L4_PROVEN", "L5_AUTHORIZED", "PROOF_COMPLETE"),
    "G5": ("L5_AUTHORIZED", "L6_BRIDGED", "AUTHORITY_VALID"),
    "G6": ("L6_BRIDGED", "L7_EFFECTED", "EFFECT_SCOPED"),
}

FORBIDDEN_RESURRECTION = {
    ("REVOKED","ACTIVE"),
    ("REVOKED","RELEASE"),
    ("RETIRED","ACTIVE"),
    ("RETIRED","RELEASE"),
}

PURPLE_MAY = {
    "DEMOTE",
    "INVALIDATE_EVIDENCE",
    "FORCE_REEVALUATION",
    "RETURN_UNKNOWN",
    "RETURN_CONFLICTED",
    "RETURN_STALE",
    "RETURN_FAILED",
}

PURPLE_MAY_NOT = {
    "AUTHORIZE",
    "RELEASE",
    "ACTIVATE",
    "BRIDGE",
    "EXECUTE",
    "PROMOTE",
}

def production_unlock(state):
    # Derived only. No stored or mutable production_unlock variable.
    return 0 if state == "BLOCKED" else 1

def gate(gate_id, state, predicate_passed):
    if gate_id not in GATES:
        return ("NON_CONFORMANT", "SCHEMATIC_DRIFT")

    expected, nxt, _ = GATES[gate_id]

    if state != expected:
        return ("NON_CONFORMANT", "UNGATED_TRANSITION")

    if not predicate_passed:
        return ("BLOCKED", "PREDICATE_UNSATISFIED")

    return (nxt, "PASS")

def lifecycle_transition(state, target):
    if (state, target) in FORBIDDEN_RESURRECTION:
        return ("NON_CONFORMANT", "SILENT_RESURRECTION")

    allowed = {
        ("RELEASE","ACTIVE"),
        ("ACTIVE","REVOKED"),
        ("REVOKED","RETIRED"),
    }

    if (state, target) not in allowed:
        return ("NON_CONFORMANT", "SCHEMATIC_DRIFT")

    return (target, "PASS")

def purple_action(action):
    if action in PURPLE_MAY:
        return ("ALLOWED", action)

    return ("NON_CONFORMANT", "PURPLE_AUTHORIZATION")

def external_effect(path):
    if path != "UL7RABRIDGE":
        return ("NON_CONFORMANT", "BRIDGE_BYPASS")

    return ("ALLOWED", "EFFECT_SCOPED")
