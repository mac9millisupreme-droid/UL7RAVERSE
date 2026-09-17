use halo_twin_pair::{FailClosedVerifier, HaloTwinPair};

fn main() {
    let pair = HaloTwinPair::new(FailClosedVerifier);
    println!("HALO_TWIN_PAIR_V1");
    println!("state={:?}", pair.state());
    println!("action_allowed={}", pair.action_allowed());
    println!("production_crypto_provider=NOT_CONFIGURED");
    println!("production_unlock=BLOCKED");
}
