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
    let direction = std::env::var("CHEETAH_DIRECTION")
        .unwrap_or_else(|_| "SOVEREIGN_TO_EXTERNAL".into());

    if direction != "SOVEREIGN_TO_EXTERNAL" {
        eprintln!("CHEETAH DENY: prohibited direction");
        std::process::exit(1);
    }

    let payload = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "EMPTY".into());

    let mut hasher = Sha256::new();
    hasher.update(payload.as_bytes());

    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();

    let envelope = Envelope {
        id: format!("CHEETAH-{}", timestamp),
        direction,
        classification: "UNCLASSIFIED".into(),
        payload_sha256: format!("{:x}", hasher.finalize()),
        timestamp,
    };

    println!("{}", serde_json::to_string_pretty(&envelope).unwrap());
}
