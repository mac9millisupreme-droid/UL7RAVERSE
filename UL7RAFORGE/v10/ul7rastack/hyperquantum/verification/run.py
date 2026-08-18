from pathlib import Path
import hashlib,json,subprocess,sys
from datetime import datetime,timezone

ROOT=Path(__file__).resolve().parents[4]
BASE=ROOT/"v10/ul7rastack/hyperquantum"
SNAP=Path(sys.argv[1])

def sha(p):
    h=hashlib.sha256()
    with p.open("rb") as f:
        for x in iter(lambda:f.read(1048576),b""):
            h.update(x)
    return h.hexdigest()

stack=BASE/"core/stack.py"

compile_result=subprocess.run(
    [sys.executable,"-m","py_compile",str(stack)],
    capture_output=True,text=True
)

test_result=subprocess.run(
    [sys.executable,str(stack)],
    capture_output=True,text=True
)

result={
    "system":"UL7RAVERSE",
    "component":"HYPER_QUANTUM_STACK",
    "timestamp":datetime.now(timezone.utc).isoformat(),
    "compile":"PASS" if compile_result.returncode==0 else "FAIL",
    "self_test":"PASS" if test_result.returncode==0 else "FAIL",
    "production":"LOCKED",
    "certification_claim":False,
    "quantum_computing_claim":False,
    "quantum_resistant_implementation_claim":False,
    "rule":"UNVERIFIED_NEVER_EQUALS_PASS",
    "evidence":{
        "source_sha256":sha(stack)
    }
}

result["status"] = (
    "VERIFIED_FOUNDATION"
    if result["compile"]=="PASS" and result["self_test"]=="PASS"
    else "BLOCKED"
)

canonical=json.dumps(
    result,sort_keys=True,separators=(",",":")
).encode()

result["evidence_hash"]=hashlib.sha256(canonical).hexdigest()

(SNAP/"hyperquantum_result.json").write_text(
    json.dumps(result,indent=2,sort_keys=True)
)

print(json.dumps(result,indent=2,sort_keys=True))
