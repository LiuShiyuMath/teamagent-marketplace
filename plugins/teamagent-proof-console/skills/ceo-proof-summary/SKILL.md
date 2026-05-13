---
name: ceo-proof-summary
description: Write a single CEO summary paragraph (one paragraph, no code, no jargon) that opens with the verbatim headline "Previous Claude Code made this mistake. New Claude Code tried to repeat it. TeamAgent blocked it." and contains exactly three concrete numbers about a TeamAgent rule and its block events. Designed for slides, email, or a status-page tile. Reads the rule card and matching events; writes nothing back to .teamagent/rules/ or .teamagent/events/.
---

# ceo-proof-summary

The tightest possible artifact: one paragraph a non-coder CEO can paste into a board email. No bullets, no code, no jargon. The paragraph leads with the headline sentence and contains exactly three concrete numbers.

## When to use

- After `generate-proof-packet` ran and the caller wants a one-paragraph headline for a slide or message.
- After `audit-feature-evidence` ran and the caller wants the audit boiled to a paragraph.
- "give me one sentence for the CEO"
- "/proof" command's optional final step.

## Inputs

- A rule id (required).
- Optional: path to an `audit.json` from `audit-feature-evidence` (gives you the three numbers for a windowed view).
- Optional: path to a `hook-events.jsonl` from `generate-proof-packet` (gives you the three numbers for a single-packet view).

If neither is supplied, compute the three numbers directly by scanning `.teamagent/events/*.json` for the rule id (last 7 days by default).

## The three numbers (pick by context)

For a single-event packet:
1. blocks for this rule (count)
2. distinct sessions affected
3. days since the original user correction

For a windowed audit:
1. blocks in window
2. distinct sessions in window
3. trend ratio (last 7 days vs prior 7 days), e.g. "2x more this week than last week"

Never fabricate a number. If a number isn't available (e.g. no audit input, no events on disk), substitute a clearly-labelled qualitative phrase like "armed but not yet triggered" and reduce the count of numbers — better to publish two real numbers than three fake ones.

## Output

Write to `.teamagent/proof/<unix>-<rule_id>-ceo.md`. Single file, single paragraph, no headings beyond an optional `# Headline` line at the top.

Also echo the paragraph to stdout so the caller can pipe it directly into an email or slide.

## The fixed structure

```
[headline sentence verbatim] [one sentence naming the rule and the original mistake] [one sentence with the three numbers] [one sentence on what this means for the team].
```

That is ~4 sentences, ~80-110 words. Do not exceed 130 words. Do not add a second paragraph.

## Worked example

Inputs: rule `no-moment-use-dayjs`, audit window 7d, audit.json shows `block_count=2`, `distinct_sessions=2`, `trend_7d=2`, `trend_prior_7d=1`.

Output paragraph:

> Previous Claude Code made this mistake. New Claude Code tried to repeat it. TeamAgent blocked it. The original mistake was installing the deprecated `moment` library after the team standardised on `dayjs`; a user corrected it once, weeks ago. In the last seven days, TeamAgent has caught and blocked that same install attempt 2 times, across 2 separate Claude Code sessions, which is twice as many as the prior week. The pattern is clear: as more of the team uses Claude Code, the same old mistakes resurface, and TeamAgent is converting each one-time correction into a permanent guardrail.

## Step-by-step

1. Load the rule card. Pull `id`, `wrong`, `correct`, `why`, `created_at`.
2. Compute (or read from supplied audit/events) the three numbers.
3. Compose the paragraph using the fixed structure above. Keep it ≤130 words.
4. Write `<unix>-<rule_id>-ceo.md` under `.teamagent/proof/`.
5. Echo the paragraph to stdout.
6. Print a one-line confirmation: `CEO summary: .teamagent/proof/<unix>-<rule_id>-ceo.md`.

## Style rules

- No bullets, no numbered lists, no code blocks.
- No words: "implementation", "PreToolUse", "hook", "JSONL", "regex". Replace with plain English ("the rule", "the check", "the file", "the pattern").
- Always start with the verbatim headline sentence. No paraphrasing.
- Always end with one forward-looking sentence about what the trend means for the team.

## Failure modes

- Rule not found: do not write a file; print `error: rule <id> not found in .teamagent/rules/{active,pending}/` and exit.
- Zero events and no audit input: still produce a paragraph, but replace the "three numbers" sentence with "TeamAgent has the rule armed and is watching for the next attempt".
- Word count exceeded: trim the "what this means" sentence first, then the "naming the rule" sentence, never the headline.
