---
name: teambrain-office-hours-grill-eval
description: Evaluate whether an answer truly grills the TeamBrain / TeamAgent project in Garry Tan office-hours style — judging substance (wedge, demand, ICP, CEO proof loop, shipped-vs-vision honesty, marketplace packaging, security/trust, actionability, sharpness) rather than headings or formatting. Use this skill whenever the user asks to judge, grade, score, audit, critique, or eval an answer about TeamBrain, TeamAgent, the libz-renlab-ai repo, Claude Code marketplace strategy, plugin/skill packaging, CEO-facing proof-of-work demos, or startup wedge critiques — even if they don't literally say "evaluate". Also use when the user pastes someone else's grill / office-hours / YC-style critique and asks "is this any good", "does this pass", "give me a score", or "what's missing".
allowed-tools: Read, Bash, WebSearch
---

# TeamBrain Office-Hours Grill Eval

## Goal

Judge whether an answer does the actual job:

> Grill the TeamBrain / TeamAgent project using office-hours startup logic, producing a sharp, honest, CEO-readable, agent-readable critique with actionable next steps.

This eval is **non-structural**. A polished table with weak judgment must fail. A messy answer with strong diagnosis, a concrete proof loop, and honest scope boundaries can pass. Reward substance, honesty, specificity, and decision pressure — not headings.

## How to evaluate (workflow)

Two-pass evaluation. Run the cheap heuristic first to filter obvious summaries / hype / structure-only outputs, then run the LLM judge for the real semantic call.

### Pass 1 — Python heuristic gate

The heuristic does not understand meaning; it only checks for substance signals (required vocabulary + positive/negative patterns) and auto-fail traps. Use it to catch the obviously-bad cases quickly.

```bash
python scripts/eval_grill_output.py path/to/answer.md
# or stream via stdin
cat answer.md | python scripts/eval_grill_output.py -
```

It prints a JSON verdict like:

```json
{
  "pass": false,
  "score_total": 14,
  "scores": { "wedge_clarity": 1, "ceo_proof_loop": 0, ... },
  "weak_dimensions": ["ceo_proof_loop", "security_trust"],
  "fatal_issues": [],
  "interpretation": "medium: contains useful critique but lacks enough decision pressure"
}
```

Exit code is `0` on pass, `1` on fail — safe for shell pipelines and CI.

If the heuristic already returns `fatal_issues` (e.g. "Hype language without proof", "Only one-line generic summary"), stop here. The answer is a summary or a pitch, not a grill. Report and exit.

### Pass 2 — LLM judge (the real call)

The heuristic cannot tell the difference between *named* a wedge and *picked* the right wedge. For that, run an LLM judge.

Hand the judge three things:

1. The answer being evaluated.
2. `references/rubric.md` — the 10-dimension 0–3 scoring guide with strong/weak signal examples.
3. `references/judge-prompt.md` — the judge instructions + required JSON output schema + pass thresholds.

The judge must return JSON only (see `references/judge-prompt.md` for the exact schema, including `must_fix`, `best_line`, and `fatal_issue`). Pass requires `score_total >= 22` **and** the per-dimension gates on wedge_clarity, ceo_proof_loop, shipped_vs_vision_honesty, actionability, and security_trust.

### Reporting

When reporting back to the user, include:
- The pass/fail verdict.
- Total score and per-dimension scores.
- The 2–3 weakest dimensions, with the rubric's specific upgrade signal for each (so the answer's author knows what would have scored higher).
- Any fatal issues from either pass.
- A direct quote of the strongest line in the answer (`best_line`) — useful even when the answer fails, because it tells the author what to keep.

## What to evaluate (the 10 dimensions)

Full 0–3 scoring guidance with strong/weak examples lives in [`references/rubric.md`](references/rubric.md). At a glance:

1. **Wedge clarity** — narrowest believable first product; demotes the rest.
2. **Demand reality** — real pain, observable user behavior, willingness to install/pay.
3. **Status quo / competition** — what users do today (CLAUDE.md, checklists, senior engineer corrections, Slack/Notion conventions). Not "other AI startups".
4. **ICP specificity** — role + team type + trigger + adoption blocker. Not "all engineering teams".
5. **CEO proof-of-work loop** — mistake → correction → rule extraction → enforcement → prevented repeat → evidence artifact a non-coder CEO can read.
6. **Shipped vs vision honesty** — labels prototype / preship / shipped / roadmap / unknown clearly. Punishes ambiguity.
7. **Marketplace / skill packaging** — proposes a *narrow* first plugin (SKILL.md + scripts/ + references/ + assets/), not a "platform".
8. **Security / trust** — install risk, hook scope, data leaving the machine, uninstall path, boss-visibility privacy.
9. **Actionability** — concrete tasks with acceptance criteria, not "consider exploring".
10. **Sharpness** — kill / keep / demote / promote judgments. Forces tradeoffs.

## Passing standard

A passing answer must:

- Name one primary wedge.
- Demote or challenge at least one distracting feature.
- Define a CEO-readable proof loop.
- Identify a specific ICP.
- Discuss status quo alternatives.
- Mention security / trust / privacy risk.
- Give concrete next actions.
- Avoid presenting uncertain or roadmap features as shipped.

## Failing patterns to watch for

The skill auto-fails (or scores low) when an answer mainly:

- Summarizes the repo without judgment.
- Lists features without prioritization.
- Says "great project" and gives generic improvements.
- Treats dashboard / video / marketplace as equally validated.
- Ignores user demand and status quo.
- Ignores installation / privacy / security trust.
- Produces only code / package directory trees without evaluating the product.
- Uses "AI agents are the future" as the main argument.

Concrete bad lines to recognize are listed in [`assets/anti-patterns.txt`](assets/anti-patterns.txt). The heuristic script also encodes some of these as auto-fail regex.

## Bundled resources

- [`scripts/eval_grill_output.py`](scripts/eval_grill_output.py) — Python 3 heuristic gate. No external deps; standard library only. Run first.
- [`references/rubric.md`](references/rubric.md) — full 10-dimension rubric, 0–3 per dimension, with strong/weak signal examples.
- [`references/judge-prompt.md`](references/judge-prompt.md) — LLM judge prompt with JSON output schema and the pass-threshold gates.
- [`assets/cases.jsonl`](assets/cases.jsonl) — 5 reference cases (one gold, one near-miss, three fails) with expected score bands. Use these to sanity-check the judge before trusting it on new inputs.
- [`assets/anti-patterns.txt`](assets/anti-patterns.txt) — quotable bad lines that should never score well.

## Calibration check (optional but cheap)

Before scoring a new answer, you can re-grade the 5 cases in `assets/cases.jsonl` and confirm scores fall inside the expected bands (`minimum_score` / `maximum_score`). If the judge drifts (e.g. `fail-02` scores 18), the rubric or judge prompt needs tightening before trusting fresh verdicts.

## What this skill is NOT

- Not a code review skill for the TeamBrain codebase.
- Not a generic "rate this startup" rubric — the dimensions are tuned to TeamBrain/TeamAgent's specific risk surface (marketplace packaging, CEO proof-of-work, hook-based enforcement, boss-visibility privacy).
- Not a writing-style grader. Polished prose with no judgment fails.
