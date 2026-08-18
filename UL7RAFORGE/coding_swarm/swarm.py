import json, hashlib, uuid, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent

ROLES = [
    "architect",
    "builder",
    "refactorer",
    "test_engineer",
    "security_engineer",
    "performance_engineer",
    "infrastructure_engineer",
    "debugger",
    "reviewer"
]

def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2))

def digest(data):
    return hashlib.sha256(
        json.dumps(data, sort_keys=True).encode()
    ).hexdigest()

task = {
    "task_id": str(uuid.uuid4()),
    "created": time.time(),
    "state": "QUEUED",
    "mode": "ISOLATED",
    "promotion": "BLOCKED",
    "required_gates": [
        "BUILD",
        "TEST",
        "SECURITY",
        "REVIEW",
        "TRINITY_VERIFY",
        "PURPLE_VERIFY"
    ]
}

for role in ROLES:
    write_json(
        ROOT / "workers" / role / "worker.json",
        {
            "role": role.upper(),
            "authority": "PROPOSE_ONLY",
            "production_access": False,
            "network_access": False,
            "credential_access": False,
            "sandbox_required": True
        }
    )

task["architecture_hash"] = digest({
    "roles": ROLES,
    "gates": task["required_gates"]
})

write_json(ROOT / "queue" / f'{task["task_id"]}.json', task)

state = {
    "system": "UL7RAFORGE_CODING_SWARM",
    "status": "READY",
    "workers": len(ROLES),
    "task_queue": "READY",
    "production_promotion": "BLOCKED",
    "trinity_verification": "REQUIRED",
    "purple_team": "REQUIRED"
}

write_json(ROOT / "state" / "swarm.json", state)

with (ROOT / "logs" / "execution.jsonl").open("a") as f:
    f.write(json.dumps({
        "event": "CODING_SWARM_INITIALIZED",
        "task_id": task["task_id"],
        "architecture_hash": task["architecture_hash"],
        "timestamp": time.time()
    }) + "\n")

print(json.dumps(state, indent=2))
