# UL7RA Racing Intelligence

Domain implementation within UL7RAVERSE.

Initial release is research/paper mode only.

Pipeline:

INGEST
→ NORMALIZE
→ VALIDATE
→ FEATURE EXTRACTION
→ ANALYSIS
→ PROBABILITY
→ MARKET COMPARISON
→ VALUE
→ ADVERSARIAL REVIEW
→ VERIFICATION
→ GOVERNANCE
→ PAPER DECISION

Decision states:

WATCH
VALUE_CANDIDATE
NO_BET
BLOCKED
FAILED

Rules:

- Never fabricate race data.
- Missing data remains explicitly missing.
- Unverified never equals pass.
- Unknown remains unknown.
- Probability is not confidence.
- Market implied probability is distinct from model probability.
- Expected value requires valid market information.
- Failed critical assurance gates prevent promotion.
- No autonomous wagering.
- No sportsbook integration.
- No profitability claims without reproducible out-of-sample evidence.
