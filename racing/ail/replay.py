from .evidence import evidence_hash

def verify_replay(original_hash: str, reconstructed_data: Dict[str, Any]) -> bool:
    return evidence_hash(reconstructed_data) == original_hash
