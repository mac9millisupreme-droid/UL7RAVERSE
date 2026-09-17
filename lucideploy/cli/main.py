import json
from pathlib import Path
from adapters.discovery import discover

def main():
    result = discover()
    print("=== LUCIDEPLOY DISCOVERY ===")
    print(json.dumps(result, indent=2, sort_keys=True))
    print("FAIL_CLOSED=TRUE")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
