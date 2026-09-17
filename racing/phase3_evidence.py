"""
Phase 3: Governed Evidence Integration

Produces a deterministic, provenance-aware evidence package from verified
Phase-2 outputs (RaceStateSnapshot and AbilityEstimate). This package does
not make betting decisions; it only prepares evidence for downstream AIL.
"""
from dataclasses import dataclass, field
from typing import Dict, Any, List, Optional
from datetime import datetime
import math
import json
import hashlib

class Phase3ValidationError(Exception):
    """Raised when evidence fails temporal or provenance checks."""
    pass

@dataclass
class Phase3EvidencePackage:
    race_id: str
    decision_timestamp: str
    race_start_timestamp: str
    race_state: Dict[str, Any]
    ability_estimates: List[Dict[str, Any]]
    quality_flags: List[str] = field(default_factory=list)
    feature_observation_timestamps: Dict[str, str] = field(default_factory=dict)
    serialization_version: str = "1.0"

    def validate_temporal(self) -> None:
        """Ensure all evidence timestamps are <= decision_timestamp."""
        try:
            dt_decision = datetime.fromisoformat(self.decision_timestamp)
        except Exception as e:
            raise Phase3ValidationError(f"Invalid decision timestamp: {e}")
        try:
            dt_race = datetime.fromisoformat(self.race_start_timestamp)
            if dt_race <= dt_decision:
                raise Phase3ValidationError("race_start_timestamp <= decision_timestamp")
        except Phase3ValidationError:
            raise
        except Exception as e:
            raise Phase3ValidationError(f"Invalid race start timestamp: {e}")

        # Check each feature observation timestamp
        for feature_name, obs_ts in self.feature_observation_timestamps.items():
            try:
                dt_obs = datetime.fromisoformat(obs_ts)
            except Exception as e:
                raise Phase3ValidationError(f"Invalid observation timestamp for {feature_name}: {e}")
            if dt_obs > dt_decision:
                raise Phase3ValidationError(
                    f"Feature '{feature_name}' observed after decision"
                )

        # Check ability estimates for temporal markers
        for est in self.ability_estimates:
            obs_ts = est.get("observation_timestamp")
            if obs_ts:
                try:
                    dt_obs = datetime.fromisoformat(obs_ts)
                    if dt_obs > dt_decision:
                        raise Phase3ValidationError(
                            f"Ability estimate for {est.get('horse_id')} observed after decision"
                        )
                except Exception as e:
                    raise Phase3ValidationError(f"Invalid ability observation timestamp: {e}")

    def validate_provenance(self) -> None:
        """Ensure ability estimates have provenance."""
        for est in self.ability_estimates:
            if not est.get("provenance"):
                # Missing provenance is not fatal here; just flag it
                self.quality_flags.append("ABILITY_PROVENANCE_MISSING")

    def horse_coverage(self) -> Dict[str, int]:
        """Return entries seen vs ability estimates."""
        entries_seen = len(self.race_state.get("entries", []))
        with_ability = len(self.ability_estimates)
        without_ability = entries_seen - with_ability
        return {
            "entries_seen": entries_seen,
            "entries_with_ability": with_ability,
            "entries_without_ability": max(0, without_ability),
        }

    def to_dict(self) -> Dict[str, Any]:
        """Deterministic dict representation."""
        return {
            "race_id": self.race_id,
            "decision_timestamp": self.decision_timestamp,
            "race_start_timestamp": self.race_start_timestamp,
            "race_state": self.race_state,
            "ability_estimates": sorted(self.ability_estimates, key=lambda x: x.get("horse_id", "")),
            "quality_flags": sorted(self.quality_flags),
            "feature_observation_timestamps": dict(sorted(self.feature_observation_timestamps.items())),
            "serialization_version": self.serialization_version,
        }

    def to_json(self) -> str:
        """Deterministic JSON string."""
        return json.dumps(self.to_dict(), sort_keys=True, default=str)

    def to_hash(self) -> str:
        """SHA256 hash of canonical JSON."""
        return hashlib.sha256(self.to_json().encode()).hexdigest()
