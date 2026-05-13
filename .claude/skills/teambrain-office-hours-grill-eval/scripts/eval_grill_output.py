#!/usr/bin/env python3
"""
Heuristic non-structural evaluator for TeamBrain office-hours grill outputs.

Usage:
  python scripts/eval_grill_output.py path/to/answer.md
  cat answer.md | python scripts/eval_grill_output.py -

This script intentionally does NOT check heading names or exact structure.
It checks for substance signals that correlate with a strong office-hours-style grill.
For final scoring, pair this with references/judge-prompt.md using an LLM judge.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple


DIMENSIONS = {
    "wedge_clarity": {
        "positive": [
            r"\bwedge\b",
            r"narrow(est)?",
            r"primary",
            r"first product",
            r"core",
            r"old .* mistake .* not .* repeat",
            r"repeat(ed)? mistake",
            r"do(es)?n'?t repeat",
            r"pretooluse",
            r"rule .* enforce",
            r"memory.*enforcement",
        ],
        "negative": [
            r"three equally",
            r"all features",
            r"platform for everything",
        ],
        "required_any": [r"\bwedge\b|narrow|primary|core|first product"],
    },
    "demand_reality": {
        "positive": [
            r"demand",
            r"customer",
            r"user pain",
            r"pay",
            r"install",
            r"willing(ness)?",
            r"behavior",
            r"workaround",
            r"hours?",
            r"money",
            r"review burden",
            r"adoption",
        ],
        "negative": [
            r"everyone needs",
            r"all developers",
            r"obviously",
        ],
        "required_any": [r"demand|customer|pay|install|behavior|workaround"],
    },
    "status_quo": {
        "positive": [
            r"status quo",
            r"CLAUDE\.md",
            r"team docs?",
            r"checklist",
            r"review",
            r"senior engineer",
            r"Slack",
            r"Notion",
            r"copy[- ]?paste",
            r"human memory",
            r"current workaround",
        ],
        "negative": [],
        "required_any": [r"status quo|CLAUDE\.md|workaround|checklist|team docs?"],
    },
    "icp_specificity": {
        "positive": [
            r"\bICP\b",
            r"eng(ineering)? lead",
            r"10[-–]50",
            r"AI-heavy",
            r"startup",
            r"buyer",
            r"user profile",
            r"trigger",
            r"blocker",
            r"role",
            r"team size",
        ],
        "negative": [
            r"all engineering teams",
            r"every developer",
        ],
        "required_any": [r"ICP|eng(ineering)? lead|buyer|user profile|team size|trigger"],
    },
    "ceo_proof_loop": {
        "positive": [
            r"\bCEO\b",
            r"proof[- ]?of[- ]?work",
            r"proof loop",
            r"before/after",
            r"transcript",
            r"correction",
            r"rule card",
            r"next session",
            r"hook event",
            r"blocked?",
            r"evidence artifact",
            r"saved time",
        ],
        "negative": [
            r"activity equals proof",
        ],
        "required_any": [r"CEO|proof[- ]?of[- ]?work|proof loop|before/after|rule card"],
    },
    "shipped_vs_vision_honesty": {
        "positive": [
            r"shipped",
            r"vision",
            r"roadmap",
            r"prototype",
            r"preship",
            r"unshipped",
            r"not yet",
            r"do not overclaim",
            r"honest",
            r"unknown",
            r"validated",
        ],
        "negative": [
            r"fully shipped",
            r"already complete",
        ],
        "required_any": [r"shipped|vision|roadmap|prototype|unshipped|not yet|validated"],
    },
    "marketplace_skill_packaging": {
        "positive": [
            r"marketplace",
            r"plugin",
            r"skill",
            r"SKILL\.md",
            r"scripts/",
            r"references/",
            r"assets/",
            r"hooks/",
            r"commands/",
            r"plugin\.json",
            r"teamagent-memory",
            r"package",
        ],
        "negative": [
            r"one giant plugin",
        ],
        "required_any": [r"marketplace|plugin|skill|SKILL\.md|teamagent-memory"],
    },
    "security_trust": {
        "positive": [
            r"security",
            r"trust",
            r"privacy",
            r"permissions?",
            r"local",
            r"upload",
            r"hooks?",
            r"install",
            r"uninstall",
            r"disable",
            r"data .* leave",
            r"curl \| bash",
            r"boss visibility",
            r"video",
        ],
        "negative": [
            r"trust.*automatic",
        ],
        "required_any": [r"security|trust|privacy|permissions?|uninstall|data .* leave|upload"],
    },
    "actionability": {
        "positive": [
            r"next step",
            r"assignment",
            r"acceptance criteria",
            r"48 hours?",
            r"deliverable",
            r"measure",
            r"run .* users?",
            r"collect .* mistakes?",
            r"demo/",
            r"must",
            r"do not",
            r"build",
        ],
        "negative": [
            r"consider exploring",
            r"might be useful",
        ],
        "required_any": [r"next step|assignment|acceptance criteria|deliverable|demo/|measure"],
    },
    "sharpness": {
        "positive": [
            r"kill",
            r"keep",
            r"demote",
            r"promote",
            r"red flag",
            r"must",
            r"not",
            r"wrong",
            r"danger",
            r"focus",
            r"cut",
            r"do not",
            r"biggest problem",
        ],
        "negative": [
            r"great job",
            r"nice project",
            r"interesting",
        ],
        "required_any": [r"kill|keep|demote|red flag|must|do not|cut|focus"],
    },
}


AUTO_FAIL_PATTERNS = [
    (r"(?is)^\s*(TeamBrain|TeamAgent) is .*?(platform|tool).*?\.\s*$", "Only one-line generic summary."),
    (r"(?is)revolutionary .* platform", "Hype language without proof."),
]


def count_matches(text: str, patterns: List[str]) -> int:
    return sum(1 for p in patterns if re.search(p, text, flags=re.IGNORECASE | re.MULTILINE))


def score_dimension(text: str, cfg: Dict[str, List[str]]) -> Tuple[int, List[str]]:
    pos = count_matches(text, cfg.get("positive", []))
    neg = count_matches(text, cfg.get("negative", []))
    has_required = any(
        re.search(p, text, flags=re.IGNORECASE | re.MULTILINE)
        for p in cfg.get("required_any", [])
    )

    notes = []
    if not has_required:
        notes.append("missing required substance signal")

    raw = 0
    if has_required and pos >= 2:
        raw = 1
    if has_required and pos >= 4:
        raw = 2
    if has_required and pos >= 7:
        raw = 3

    if neg:
        raw = max(0, raw - neg)
        notes.append(f"negative signals: {neg}")

    return raw, notes


def evaluate(text: str) -> Dict[str, object]:
    fatal = []
    for pattern, reason in AUTO_FAIL_PATTERNS:
        if re.search(pattern, text):
            fatal.append(reason)

    scores = {}
    notes = {}
    for name, cfg in DIMENSIONS.items():
        score, dim_notes = score_dimension(text, cfg)
        scores[name] = score
        if dim_notes:
            notes[name] = dim_notes

    total = sum(scores.values())

    threshold_pass = (
        total >= 22
        and scores["wedge_clarity"] >= 2
        and scores["ceo_proof_loop"] >= 2
        and scores["shipped_vs_vision_honesty"] >= 2
        and scores["actionability"] >= 2
        and scores["security_trust"] >= 1
        and not fatal
    )

    weak = [k for k, v in scores.items() if v <= 1]

    return {
        "pass": threshold_pass,
        "score_total": total,
        "scores": scores,
        "weak_dimensions": weak,
        "notes": notes,
        "fatal_issues": fatal,
        "interpretation": interpret(total, threshold_pass, weak, fatal),
    }


def interpret(total: int, passed: bool, weak: List[str], fatal: List[str]) -> str:
    if fatal:
        return "auto-fail: " + "; ".join(fatal)
    if passed:
        return "pass: substantive office-hours-style grill"
    if total >= 22:
        return "near pass but failed one required gate: " + ", ".join(weak)
    if total >= 16:
        return "medium: contains useful critique but lacks enough decision pressure"
    return "fail: likely summary, hype, or structure-only output"


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: eval_grill_output.py path/to/answer.md OR -", file=sys.stderr)
        sys.exit(2)

    source = sys.argv[1]
    if source == "-":
        text = sys.stdin.read()
    else:
        text = Path(source).read_text(encoding="utf-8")

    result = evaluate(text)
    print(json.dumps(result, ensure_ascii=False, indent=2))

    sys.exit(0 if result["pass"] else 1)


if __name__ == "__main__":
    main()
