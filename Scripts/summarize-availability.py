"""Summarize five rounds of the four beta journeys on each platform."""

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path


PLATFORMS = {"ios": "iPhone 시뮬레이터", "edge": "Windows Edge"}
JOURNEYS = {"journal": "운동 기록", "routine": "루틴", "catalog": "동작 도감", "coach": "코치"}
STATES = {"pass": "통과", "fail": "실패", "missing": "누락"}
ROUNDS = range(1, 6)
REQUIRED = 19
PER_PLATFORM = len(ROUNDS) * len(JOURNEYS)


def full_sha(value):
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise argparse.ArgumentTypeError("GitHub 커밋의 소문자 40자리 전체 SHA를 입력하세요.")
    return value


def unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("중복된 JSON 키")
        result[key] = value
    return result


def read_round(path, platform, round_number, commit):
    if path.is_symlink() or not path.is_file():
        raise ValueError("일반 파일이 아님")
    data = json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=unique_keys)
    if not isinstance(data, dict) or data.keys() != {"platform", "round", "commit", "results"}:
        raise ValueError("필수 필드 또는 추가 필드 확인 필요")
    if data["platform"] != platform or type(data["round"]) is not int or data["round"] != round_number:
        raise ValueError("파일명과 플랫폼 또는 회차가 다름")
    if data["commit"] != commit:
        raise ValueError("요청한 커밋과 다른 SHA")
    results = data["results"]
    if not isinstance(results, dict) or results.keys() != JOURNEYS.keys():
        raise ValueError("네 가지 여정 필드가 정확히 일치하지 않음")
    if any(not isinstance(value, str) or value not in STATES for value in results.values()):
        raise ValueError("허용되지 않은 결과 값")
    return results


def collect(directory, commit):
    rounds = {(p, n): dict.fromkeys(JOURNEYS, "missing") for p in PLATFORMS for n in ROUNDS}
    filenames = {f"{p}-{n}.json": (p, n) for p, n in rounds}
    candidates = defaultdict(list)
    for path in directory.rglob("*.json"):
        if path.name in filenames:
            candidates[path.name].append(path)

    issues = []
    for name, (platform, number) in filenames.items():
        paths = candidates[name]
        if not paths:
            issues.append(f"`{name}` 파일이 없음")
        elif len(paths) > 1:
            issues.append(f"`{name}` 파일이 {len(paths)}개여서 이 회차를 집계할 수 없음")
        else:
            try:
                rounds[platform, number] = read_round(paths[0], platform, number, commit)
            except (OSError, ValueError, RecursionError) as error:
                reason = "파일을 읽을 수 없음" if isinstance(error, OSError) else str(error).splitlines()[0]
                issues.append(f"`{name}` 결과를 제외함 ({reason})")
    return rounds, issues


def report(commit, rounds, issues):
    totals = {
        p: Counter(value for n in ROUNDS for value in rounds[p, n].values())
        for p in PLATFORMS
    }
    accepted = all(counts["pass"] >= REQUIRED for counts in totals.values())
    lines = [
        "# 베타 사용자 여정 검증", "",
        f"커밋 `{commit}`", "",
        f"판정 **{'통과' if accepted else '미달'}**. 각 환경에서 {PER_PLATFORM}회 중 {REQUIRED}회 이상 통과해야 합니다.",
        "", "## 환경별 결과", "",
        "| 환경 | 통과/전체 | 실패 | 누락 | 성공률 |", "| --- | ---: | ---: | ---: | ---: |",
    ]
    for p, label in PLATFORMS.items():
        c = totals[p]
        lines.append(f"| {label} | {c['pass']}/{PER_PLATFORM} | {c['fail']} | {c['missing']} | {c['pass']/PER_PLATFORM:.1%} |")
    total = sum(totals.values(), Counter())
    count = PER_PLATFORM * len(PLATFORMS)
    lines.append(f"| 전체 | {total['pass']}/{count} | {total['fail']} | {total['missing']} | {total['pass']/count:.1%} |")
    lines.extend(["", "## 여정별 결과", "",
                  "| 환경 | 여정 | 통과/전체 | 실패 | 누락 |", "| --- | --- | ---: | ---: | ---: |"])
    for p, label in PLATFORMS.items():
        for journey, title in JOURNEYS.items():
            c = Counter(rounds[p, n][journey] for n in ROUNDS)
            lines.append(f"| {label} | {title} | {c['pass']}/{len(ROUNDS)} | {c['fail']} | {c['missing']} |")
    lines.extend(["", "## 회차별 결과", "",
                  "| 환경 | 회차 | " + " | ".join(JOURNEYS.values()) + " |",
                  "| --- | ---: | " + " | ".join("---" for _ in JOURNEYS) + " |"])
    for (p, n), result in rounds.items():
        cells = " | ".join(STATES[result[journey]] for journey in JOURNEYS)
        lines.append(f"| {PLATFORMS[p]} | {n} | {cells} |")
    if issues:
        lines.extend(["", "## 수집 문제", ""])
        lines.extend(f"- {issue}" for issue in issues)
    return "\n".join(lines) + "\n", accepted


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--commit", required=True, type=full_sha)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    # Keep an output path inside the artifact directory from overwriting a round.
    destination = args.out.resolve()
    if destination.is_relative_to(args.input.resolve()) and destination.name.casefold() in {
        f"{p}-{n}.json" for p in PLATFORMS for n in ROUNDS
    }:
        parser.error("보고서 파일과 입력 결과 파일의 이름이 겹칩니다.")
    rounds, issues = collect(args.input, args.commit)
    markdown, accepted = report(args.commit, rounds, issues)
    print(markdown, end="")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(markdown, encoding="utf-8")
    return 0 if accepted else 1


if __name__ == "__main__":
    sys.exit(main())
