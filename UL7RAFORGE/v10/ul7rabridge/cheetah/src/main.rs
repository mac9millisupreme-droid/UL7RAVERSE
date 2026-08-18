use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Serialize, Deserialize)]
struct Envelope {
    id: String,
    direction: String,
    classification: String,
    payload_sha256: String,
    timestamp: u64,
}

fn main() {
    let payload = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "EMPTY".to_string());

    let mut hasher = Sha256::new();
    hasher.update(payload.as_bytes());

    let digest = format!("{:x}", hasher.finalize());

    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();

    let envelope = Envelope {
        id: format!("CHEETAH-{}", timestamp),
        direction: "SOVEREIGN_TO_EXTERNAL".into(),
        classification: "UNCLASSIFIED".into(),
        payload_sha256: digest,
        timestamp,
    };

    println!("{}", serde_json::to_string_pretty(&envelope).unwrap());
}
