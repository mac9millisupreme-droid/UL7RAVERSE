#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/UL7RAVERSE"
FORGE="$ROOT/UL7RAFORGE"

mkdir -p \
  "$FORGE"/{kernel,orchestrator,agents,policies,sandbox,tests,security,purple,verification,provenance,evidence,deployment,observability,knowledge,config,logs,artifacts}

printf '%s\n' \
  'UL7RAFORGE BOOTSTRAP' \
  '====================' \
  'MODE=EXECUTION' \
  'STATE=BOOTSTRAPPING' \
  'VERIFICATION=REQUIRED'

command -v git >/dev/null || pkg install -y git
command -v python >/dev/null || pkg install -y python
command -v jq >/dev/null || pkg install -y jq

cd "$ROOT"

git init 2>/dev/null || true

cat > "$FORGE/config/factory.json" <<'JSON'
{
  "name": "UL7RAFORGE",
  "mode": "execution",
  "verification_required": true,
  "fail_closed": true,
  "provider_independent": true,
  "purple_team": "perpetual_authorized_test_environment_only",
  "release_requires": [
    "BUILD",
    "TEST",
    "SECURITY",
    "POLICY",
    "PURPLE",
    "PROVENANCE",
    "VERIFICATION",
    "ROLLBACK"
  ]
}
JSON

cat > "$FORGE/kernel/state.json" <<'JSON'
{
  "factory": "UL7RAFORGE",
  "state": "BOOTSTRAPPED",
  "task_state": "READY",
  "artifact_state": "READY",
  "test_state": "PENDING",
  "security_state": "PENDING",
  "policy_state": "PENDING",
  "verification_state": "PENDING",
  "evidence_state": "PENDING",
  "release_state": "BLOCKED"
}
JSON

cat > "$FORGE/kernel/health.py" <<'PY'
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
state = json.loads((root / "kernel/state.json").read_text())

required = [
    "factory", "state", "task_state", "artifact_state",
    "test_state", "security_state", "policy_state",
    "verification_state", "evidence_state", "release_state"
]

missing = [x for x in required if x not in state]

if missing:
    raise SystemExit("HEALTHCHECK_FAILED:" + ",".join(missing))

print(json.dumps({
    "factory": state["factory"],
    "state": state["state"],
    "healthcheck": "PASS"
}, indent=2))
PY

python "$FORGE/kernel/health.py"

git add .
git commit -m "UL7RAFORGE bootstrap" 2>/dev/null || true

printf '\nUL7RAFORGE_BOOTSTRAP=PASS\n'
printf 'FACTORY_STATE=BOOTSTRAPPED\n'
printf 'RELEASE_STATE=BLOCKED_UNTIL_VERIFIED\n'
