#!/usr/bin/env python3
"""UL7RACONTINUOUSCONFORMANCE_RECONCILIATION/v1
Derived implementation. Evidence/conformance only. No authorization.
"""

from collections import Counter

REQUIRED_LOOPS = "['STATIC', 'BUILD', 'RUNTIME', 'PURPLE_Ω', 'PROOF', 'GOVERNANCE', 'BRIDGE']"

def derive_loop_status(observations, loop_id):
    obs = [x for x in observations if x["loop_id"] == loop_id]

    if not obs:
        return "UNKNOWN"

    if any(x.get("integrity") == "HASHINVALID" for x in obs):
        return "FAILED"

    if any(
        x.get("predicate_result") == "FAIL"
        or x.get("proof_state") == "FAILED"
        or x.get("observation_status") == "FAILED"
        for x in obs
    ):
        return "FAILED"

    results = {
        x.get("predicate_result")
        for x in obs
        if x.get("predicate_result") in {"PASS", "FAIL"}
    }

    if "PASS" in results and "FAIL" in results:
        return "CONFLICTED"

    if any(
        x.get("predicate_result") == "CONFLICTED"
        or x.get("proof_state") == "CONFLICTED"
        or x.get("observation_status") == "CONFLICTED"
        for x in obs
    ):
        return "CONFLICTED"

    if any(
        x.get("freshness") == "STALE"
        or x.get("predicate_result") == "STALE"
        or x.get("proof_state") == "STALE"
        or x.get("observation_status") == "STALE"
        for x in obs
    ):
        return "STALE"

    if any(
        x.get("predicate_result") == "UNKNOWN"
        or x.get("proof_state") == "UNKNOWN"
        or x.get("observation_status") == "UNKNOWN"
        for x in obs
    ):
        return "UNKNOWN"

    if all(
        x.get("predicate_result") == "PASS"
        and x.get("proof_state") == "VERIFIED"
        and x.get("observation_status") == "VERIFIED"
        and x.get("integrity") == "HASHVALID"
        and x.get("freshness") == "FRESH"
        for x in obs
    ):
        return "VERIFIED"

    return "UNKNOWN"

def replay_valid(observations):
    return all(
        bool(x.get("replay_id"))
        and x.get("integrity") == "HASHVALID"
        for x in observations
    )

def reconcile(current_state, observations, required_loops=None):
    required = required_loops or REQUIRED_LOOPS

    status = {
        loop: derive_loop_status(observations, loop)
        for loop in required
    }

    values = list(status.values())

    if "FAILED" in values:
        state = "FAILED"
    elif "CONFLICTED" in values:
        state = "CONFLICTED"
    elif "STALE" in values:
        state = "STALE"
    elif "UNKNOWN" in values:
        state = "UNKNOWN"
    elif all(v == "VERIFIED" for v in values) and replay_valid(observations):
        state = "PASS"
    else:
        state = "UNKNOWN"

    return {
        "current_state": current_state,
        "loop_status": status,
        "replay_valid": replay_valid(observations),
        "conformance_state": state,
    }

# Deliberately no authorization/release/activate/bridge functions.
