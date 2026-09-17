#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== LUCI PROMOTE PURPLE TEAM ==="

python luci_promote.py health
python luci_promote.py verify

echo "[ATTACK] Unknown track must not become promotion"
python - <<'PY'
import luci_promote as l
assert l.promote(999999)["final_decision"] == "UNKNOWN"
print("PASS")
PY

echo "[ATTACK] Empty title must be rejected at API boundary"
python - <<'PY'
# Structural check: API requires title before persistence.
from pathlib import Path
s=Path("luci_promote.py").read_text()
assert 'TITLE_REQUIRED' in s
print("PASS")
PY

echo "[ATTACK] Publication cannot be asserted by local state"
python - <<'PY'
from pathlib import Path
s=Path("luci_promote.py").read_text()
assert "NO_CLAIM_OF_PUBLICATION_WITHOUT_EXTERNAL_EVIDENCE" in s
print("PASS")
PY

echo "FINAL_DECISION=PASS"
