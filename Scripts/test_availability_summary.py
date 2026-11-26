"""Exercise the per-platform availability gate through its command-line entry point."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("summarize-availability.py")
COMMIT = "a" * 40
JOURNEYS = ("journal", "routine", "catalog", "coach")


class AvailabilitySummaryTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.artifacts = self.root / "artifacts"
        for platform in ("ios", "edge"):
            for number in range(1, 6):
                path = self.result(platform, number)
                path.parent.mkdir(parents=True)
                path.write_text(json.dumps({"platform": platform, "round": number, "commit": COMMIT,
                                            "results": dict.fromkeys(JOURNEYS, "pass")}), encoding="utf-8")

    def result(self, platform, number):
        return self.artifacts / f"upload-{platform}-{number}" / f"{platform}-{number}.json"

    def change(self, stored_platform, number, **fields):
        path = self.result(stored_platform, number)
        data = json.loads(path.read_text(encoding="utf-8"))
        data.update(fields)
        path.write_text(json.dumps(data), encoding="utf-8")

    def summarize(self, *, commit=COMMIT):
        output = self.root / "report" / "summary.md"
        run = subprocess.run([sys.executable, str(SCRIPT), "--input", str(self.artifacts),
                              "--commit", commit, "--out", str(output)], capture_output=True, encoding="utf-8")
        if output.exists():
            self.assertEqual(run.stdout, output.read_text(encoding="utf-8"))
        return run

    def test_one_failure_and_one_missing_on_separate_platforms_still_meet_each_threshold(self):
        self.change("ios", 1, results={**dict.fromkeys(JOURNEYS, "pass"), "journal": "fail"})
        self.change("edge", 5, results={**dict.fromkeys(JOURNEYS, "pass"), "coach": "missing"})
        run = self.summarize()
        self.assertEqual(run.returncode, 0)
        self.assertIn("| iPhone 시뮬레이터 | 19/20 | 1 | 0 | 95.0% |", run.stdout)
        self.assertIn("| Windows Edge | 19/20 | 0 | 1 | 95.0% |", run.stdout)
        self.assertIn("| 전체 | 38/40 | 1 | 1 |", run.stdout)
        self.assertIn("| Windows Edge | 코치 | 4/5 | 0 | 1 |", run.stdout)
        self.assertIn("| Windows Edge | 5 | 통과 | 통과 | 통과 | 누락 |", run.stdout)

    def test_ninety_five_percent_combined_cannot_hide_two_failures_on_one_platform(self):
        self.change("ios", 2, results={"journal": "pass", "routine": "pass", "catalog": "fail", "coach": "fail"})
        run = self.summarize()
        self.assertEqual(run.returncode, 1)
        self.assertIn("| iPhone 시뮬레이터 | 18/20 | 2 | 0 |", run.stdout)
        self.assertIn("| 전체 | 38/40 | 2 | 0 | 95.0% |", run.stdout)

    def test_missing_ambiguous_or_malformed_files_never_award_passes(self):
        self.change("ios", 1, commit="b" * 40)
        self.change("ios", 2, round=2.0)
        self.change("ios", 3, results=dict.fromkeys(JOURNEYS, "PASS"))
        duplicate = self.artifacts / "duplicate" / "ios-4.json"
        duplicate.parent.mkdir()
        duplicate.write_bytes(self.result("ios", 4).read_bytes())
        self.change("ios", 5, results={"journal": "pass"})
        duplicate_key = self.result("edge", 1)
        duplicate_key.write_text(duplicate_key.read_text().replace('"journal": "pass"',
                                 '"journal": "fail", "journal": "pass"'), encoding="utf-8")
        self.result("edge", 2).unlink()
        self.change("edge", 3, platform="ios")
        self.change("edge", 4, extra="pass")
        run = self.summarize()
        self.assertEqual(run.returncode, 1)
        self.assertIn("| iPhone 시뮬레이터 | 0/20 | 0 | 20 |", run.stdout)
        self.assertIn("| Windows Edge | 4/20 | 0 | 16 |", run.stdout)
        self.assertIn("| 전체 | 4/40 | 0 | 36 |", run.stdout)
        self.assertIn("중복된 JSON 키", run.stdout)
        self.assertIn("파일이 2개", run.stdout)

    def test_short_commit_is_rejected(self):
        run = self.summarize(commit=COMMIT[:7])
        self.assertNotEqual(run.returncode, 0)
        self.assertFalse((self.root / "report" / "summary.md").exists())


if __name__ == "__main__":
    unittest.main()
