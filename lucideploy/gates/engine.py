from dataclasses import dataclass

@dataclass
class Gate:
    name: str
    passed: bool
    evidence: str = ""

class GateEngine:
    def evaluate(self, gates):
        gates = list(gates)
        if not gates:
            return False
        return all(g.passed for g in gates)

    def require(self, gate):
        if not gate.passed:
            raise RuntimeError(f"GATE_BLOCKED:{gate.name}")
        return gate
