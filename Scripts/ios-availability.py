#!/usr/bin/env python3
"""Read one simulator round from Xcode's per-test result tree."""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys


BUNDLE = "BodyNoteUITests"
SUITE = "WorkoutJournalUITests"
METHODS = {
    "journal": "testDraftSurvivesExerciseGuideAndRelaunchBeforeCountingAsOneWorkout",
    "routine": "testFirstRoutinePrefillsTodayWithoutChangingTheTemplateOrCountingADraft",
    "catalog": "testCatalogFiltersBySelectedBodyAreaAndAliasAndAppliesTheExerciseUnit",
    "coach": "testUnsentCoachMessageSurvivesRelaunchAndEmptyHistoryHasNoInventedActivity",
}


def walk(nodes):
    if not isinstance(nodes, list):
        raise ValueError("xcresult test nodes must be an array")
    for node in nodes:
        if not isinstance(node, dict):
            raise ValueError("invalid xcresult test node")
        yield node
        yield from walk(node.get("children", []))


def case_result(case):
    result = case.get("result")
    children = list(walk(case.get("children", [])))
    for kind in ("Device", "Test Plan Configuration", "Repetition", "Test Case Run"):
        executions = [child.get("result") for child in children if child.get("nodeType") == kind]
        if executions and executions != [result]:
            return "missing"
    if result in ("Failed", "Expected Failure"):
        return "fail"
    if result == "Passed" and not any(child.get("nodeType") == "Failure Message" for child in children):
        return "pass"
    return "missing"


def extract_results(report):
    if not isinstance(report, dict) or "testNodes" not in report:
        raise ValueError("xcresult has no testNodes")
    identifiers = {f"{SUITE}/{method}": scenario for scenario, method in METHODS.items()}
    found = {scenario: [] for scenario in METHODS}
    for bundle in walk(report["testNodes"]):
        if bundle.get("nodeType") != "UI test bundle" or bundle.get("name") not in (BUNDLE, BUNDLE + ".xctest"):
            continue
        for case in walk(bundle.get("children", [])):
            identifier = case.get("nodeIdentifier")
            if case.get("nodeType") != "Test Case" or not isinstance(identifier, str):
                continue
            scenario = identifiers.get(identifier.removeprefix(BUNDLE + ".").removesuffix("()"))
            if scenario:
                found[scenario].append(case_result(case))
    return {scenario: matches[0] if len(matches) == 1 else "missing" for scenario, matches in found.items()}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--result", required=True, type=Path)
    parser.add_argument("--round", required=True, type=int)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args(argv)
    if args.round < 1 or not re.fullmatch(r"[0-9a-fA-F]{40}", args.commit):
        parser.error("--round must be positive and --commit must be a full Git commit SHA")

    try:
        if not args.result.is_dir():
            raise FileNotFoundError(f"result bundle unavailable: {args.result}")
        run = subprocess.run(
            ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", str(args.result)],
            check=True, stdout=subprocess.PIPE, encoding="utf-8", timeout=60,
        )
        tree = json.loads(run.stdout)
        results = extract_results(tree)
        if "missing" in results.values():
            nodes = list(walk(tree["testNodes"]))
            bundles = [(n.get("nodeType"), n.get("name")) for n in nodes if "bundle" in str(n.get("nodeType")).lower()]
            cases = [n.get("nodeIdentifier") for n in nodes if n.get("nodeType") == "Test Case"]
            print(f"xcresult bundles={bundles[:4]!r}, case identifiers={cases[:5]!r}", file=sys.stderr)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"iOS round {args.round}: {error}", file=sys.stderr)
        results = dict.fromkeys(METHODS, "missing")

    report = {"platform": "ios", "round": args.round, "commit": args.commit.lower(), "results": results}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"iOS round {args.round}: " + ", ".join(f"{name}={value}" for name, value in results.items()))
    return 0 if all(value == "pass" for value in results.values()) else 1


if __name__ == "__main__":
    sys.exit(main())
