from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class RaceRecord:
    race_id: str
    date: str
    track: str
    race_number: int
    distance: Optional[float]
    surface: Optional[str]
    track_condition: Optional[str]
    field_size: Optional[int]
    horse_id: str
    horse_name: str
    post: Optional[int]
    age: Optional[int]
    sex: Optional[str]
    weight: Optional[float]
    jockey: Optional[str]
    trainer: Optional[str]
    recent_form: Optional[object]
    historical_performance: Optional[object]
    class_rating: Optional[float]
    speed_rating: Optional[float]
    pace_rating: Optional[float]
    conditions_rating: Optional[float]
    odds: Optional[float]
    odds_timestamp: Optional[str]
    provenance: str
