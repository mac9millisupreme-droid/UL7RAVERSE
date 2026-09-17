# HALO9 Bridge Gate V2

V2 adds a narrow **HALO9 -> UL7RABRIDGE authority contract**.

Core rule:

`NO VALID HALO TWIN PAIR -> NO ACTION`

Integration rule:

`HALO VALID AND BRIDGE ALLOW -> ACTION MAY PROCEED`

Neither component can grant authority alone. The `BridgeAuthority` trait is an integration contract; it does **not** claim that the user's existing UL7RABRIDGE source has been modified.

Production cryptography remains deliberately unconfigured. `TestVerifier` exists only under tests. A production cryptographic provider must be independently reviewed and tested before production unlock.
