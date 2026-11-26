import io
import json
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).with_name("ios-availability.py")
parser = runpy.run_path(str(SCRIPT))
METHODS = parser["METHODS"]
extract = parser["extract_results"]


def case(scenario, result, suite="WorkoutJournalUITests", **extra):
    return {
        "nodeType": "Test Case", "nodeIdentifier": f"{suite}/{METHODS[scenario]}()",
        "result": result, **extra,
    }


def bundle(*cases, name="BodyNoteUITests"):
    return {"nodeType": "UI test bundle", "name": name, "children": [
        {"nodeType": "Test Suite", "name": "WorkoutJournalUITests", "children": list(cases)}
    ]}


def tree(*bundles):
    return {"testNodes": [{"nodeType": "Test Plan", "result": "Passed", "children": list(bundles)}]}


class IOSAvailabilityTests(unittest.TestCase):
    def test_each_measurement_names_a_real_xctest(self):
        source = SCRIPT.parents[1] / "BodyNoteUITests/WorkoutJournalUITests.swift"
        swift = source.read_text(encoding="utf-8")
        self.assertEqual(set(METHODS), {"journal", "routine", "catalog", "coach"})
        self.assertEqual(len(set(METHODS.values())), 4)
        for method in METHODS.values():
            self.assertIn(f"func {method}()", swift)
        self.assertEqual(extract(tree(bundle(*(case(key, "Passed") for key in METHODS)))),
                         dict.fromkeys(METHODS, "pass"))

    def test_individual_outcomes_take_precedence_over_plan_and_other_targets(self):
        own = bundle(case("journal", "Passed"), case("routine", "Failed"), case("catalog", "Skipped"),
                     case("coach", "Passed", suite="OtherSuite"))
        other = bundle(case("coach", "Passed"), name="OtherUITests")
        self.assertEqual(extract(tree(own, other)),
                         {"journal": "pass", "routine": "fail", "catalog": "missing", "coach": "missing"})

    def test_duplicates_skips_and_unknown_results_never_pass(self):
        own = bundle(case("journal", "Passed"), case("journal", "Passed"),
                     case("routine", "Expected Failure"), case("catalog", "Future Result"), case("coach", None))
        self.assertEqual(extract(tree(own)),
                         {"journal": "missing", "routine": "fail", "catalog": "missing", "coach": "missing"})
        for children in [
            [{"nodeType": "Repetition", "result": "Passed"}] * 2,
            [{"nodeType": "Test Case Run", "result": "Failed"}, {"nodeType": "Test Case Run", "result": "Passed"}],
            [{"nodeType": "Test Case Run", "result": "Skipped"}],
            [{"nodeType": "Failure Message", "name": "assertion failed"}],
        ]:
            with self.subTest(children=children):
                self.assertEqual(extract(tree(bundle(case("coach", "Passed", children=children))))["coach"], "missing")

    def test_cli_writes_evidence_even_if_the_bundle_or_export_is_missing(self):
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            result = Path(directory) / "WorkoutLog.xcresult"
            out = Path(directory) / "reports/ios-3.json"
            args = ["--result", str(result), "--round", "3", "--commit", "a" * 40, "--out", str(out)]
            self.assertEqual(parser["main"](args), 1)
            expected = {"platform": "ios", "round": 3, "commit": "a" * 40, "results": dict.fromkeys(METHODS, "missing")}
            self.assertEqual(json.loads(out.read_text()), expected)
            result.mkdir()
            for raw in ["unreadable", "{}", '{"testNodes": {"children":[]}}']:
                with self.subTest(raw=raw), patch("subprocess.run", return_value=subprocess.CompletedProcess([], 0, raw)):
                    self.assertEqual(parser["main"](args), 1)
                    self.assertEqual(json.loads(out.read_text()), expected)
            raw = json.dumps(tree(bundle(case("catalog", "Passed"))))
            with patch("subprocess.run", return_value=subprocess.CompletedProcess([], 0, raw)) as export:
                self.assertEqual(parser["main"](args), 1)
                self.assertEqual(export.call_args.args[0],
                                 ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", str(result)])
            expected["results"]["catalog"] = "pass"
            self.assertEqual(json.loads(out.read_text()), expected)
            complete = json.dumps(tree(bundle(*(case(key, "Passed") for key in METHODS))))
            with patch("subprocess.run", return_value=subprocess.CompletedProcess([], 0, complete)):
                self.assertEqual(parser["main"](args), 0)


if __name__ == "__main__":
    unittest.main()
