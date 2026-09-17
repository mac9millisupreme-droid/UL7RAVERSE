import argparse

from . import discovery
from . import verification
from . import evidence
from . import governance
from . import purple


def main():
    parser = argparse.ArgumentParser(
        prog="ul7ra-continue"
    )

    parser.add_argument(
        "command",
        nargs="?",
        default="state",
        choices=[
            "state",
            "verify",
            "evidence",
            "purple",
            "continue",
        ],
    )

    args = parser.parse_args()

    state = discovery.discover_state()

    if args.command == "state":
        discovery.print_state(state)
        return 0

    verified = verification.verify_state(state)

    if args.command == "verify":
        verification.print_verification(verified)
        return 0

    if args.command == "purple":
        result = purple.analyze(verified)
        purple.print_purple(result)
        return 0

    recorded = evidence.write_evidence(
        state,
        verified,
    )

    if args.command == "evidence":
        evidence.print_evidence(recorded)
        return 0

    governed = governance.govern(verified)

    print("=== UL7RA CONTINUE BRIDGE v0.1.1 ===")
    print("STATE DISCOVERED")
    print(f"STATUS: {governed['status']}")
    print(f"PURPLE: {governed['purple']['purple_state']}")
    print(f"NEXT: {governed['next']}")
    print(f"PROMOTION: {governed['promotion']}")
    print(
        "EXECUTION AUTHORIZED: "
        f"{governed['execution_authorized']}"
    )
    print(
        "WORKAROUND PERMITTED: "
        f"{governed['workaround_permitted']}"
    )
    print(f"EVIDENCE: {recorded['path']}")
    print(governed["message"])

    return 0
