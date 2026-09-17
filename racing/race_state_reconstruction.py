"""
Race-State Reconstruction Engine

Creates a temporally valid snapshot of the race as known at decision time.
Enforces observation_timestamp <= decision_timestamp and decision_timestamp < race_start_timestamp.
"""
from dataclasses import dataclass, field
from typing import Dict, Any, List, Optional
from datetime import datetime
import math

class TemporalViolation(Exception):
    """Raised when a snapshot contains information not available at decision time."""
    def __init__(self, message, field=None, horse_id=None, observation_timestamp=None, decision_timestamp=None):
        self.field = field
        self.horse_id = horse_id
        self.observation_timestamp = observation_timestamp
        self.decision_timestamp = decision_timestamp
        super().__init__(message)

@dataclass
class RaceStateSnapshot:
    race_id: str
    decision_timestamp: str
    race_start_timestamp: str
    track: Optional[str] = None
    surface: Optional[str] = None
    distance: Optional[float] = None
    field_size: Optional[int] = None
    entries: List[Dict[str, Any]] = field(default_factory=list)

    def validate_temporal(self) -> None:
        """Validate temporal integrity of all components."""
        # Validate decision timestamp
        try:
            dt_decision = datetime.fromisoformat(self.decision_timestamp)
        except Exception as e:
            raise TemporalViolation(f"Invalid decision timestamp: {e}")

        # Validate race start timestamp
        try:
            dt_race = datetime.fromisoformat(self.race_start_timestamp)
        except Exception as e:
            raise TemporalViolation(f"Invalid race start timestamp: {e}")

        if dt_race <= dt_decision:
            raise TemporalViolation(
                f"race_start_timestamp <= decision_timestamp",
                field="race_start_timestamp",
                observation_timestamp=self.race_start_timestamp,
                decision_timestamp=self.decision_timestamp
            )

        # Validate entries
        for entry in self.entries:
            obs_ts = entry.get("observation_timestamp")
            if obs_ts is None:
                # If entry has any evidence fields, require timestamp
                if any(k in entry for k in ("odds", "speed_rating", "pace_rating", "form")):
                    raise TemporalViolation(
                        f"Entry {entry.get('horse_id', 'unknown')} missing observation_timestamp for evidence",
                        field="observation_timestamp",
                        horse_id=entry.get("horse_id")
                    )
                continue
            try:
                dt_obs = datetime.fromisoformat(obs_ts)
            except Exception as e:
                raise TemporalViolation(
                    f"Invalid observation timestamp for {entry.get('horse_id', 'unknown')}: {e}",
                    field="observation_timestamp",
                    horse_id=entry.get("horse_id")
                )
            if dt_obs > dt_decision:
                raise TemporalViolation(
                    f"Entry {entry.get('horse_id')} observed after decision",
                    field="observation_timestamp",
                    horse_id=entry.get("horse_id"),
                    observation_timestamp=obs_ts,
                    decision_timestamp=self.decision_timestamp
                )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "race_id": self.race_id,
            "decision_timestamp": self.decision_timestamp,
            "race_start_timestamp": self.race_start_timestamp,
            "track": self.track,
            "surface": self.surface,
            "distance": self.distance,
            "field_size": self.field_size,
            "entries": self.entries,
        }
