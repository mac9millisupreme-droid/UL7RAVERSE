
import sys
sys.path.insert(0, ".")
from constitution import *

expected = [
    ("G1","L1_PROPOSED","L2_BUILT"),
    ("G2","L2_BUILT","L3_VERIFIED"),
    ("G3","L3_VERIFIED","L4_PROVEN"),
    ("G4","L4_PROVEN","L5_AUTHORIZED"),
    ("G5","L5_AUTHORIZED","L6_BRIDGED"),
    ("G6","L6_BRIDGED","L7_EFFECTED"),
]

for gid, src, dst in expected:
    state, result = gate(gid, src, True)
    assert state == dst
    assert result == "PASS"

for gid, src, dst in expected:
    state, result = gate(gid, src, False)
    assert state == "BLOCKED"
    assert result == "PREDICATE_UNSATISFIED"
    assert production_unlock(state) == 0

for src, dst in FORBIDDEN_RESURRECTION:
    state, result = lifecycle_transition(src, dst)
    assert state == "NON_CONFORMANT"
    assert result == "SILENT_RESURRECTION"

for action in PURPLE_MAY:
    assert purple_action(action)[0] == "ALLOWED"

for action in PURPLE_MAY_NOT:
    state, result = purple_action(action)
    assert state == "NON_CONFORMANT"
    assert result == "PURPLE_AUTHORIZATION"

assert external_effect("DIRECT")[1] == "BRIDGE_BYPASS"
assert external_effect("UL7RABRIDGE")[0] == "ALLOWED"

print("CONSTITUTION_SELF_TEST=PASS")
