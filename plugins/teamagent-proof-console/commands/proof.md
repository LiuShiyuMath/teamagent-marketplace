---
description: Render a CEO-readable proof packet showing TeamAgent blocked a repeat mistake. Bundles transcript, rule card, hook event, and before/after diff under .teamagent/proof/.
argument-hint: "[rule-id | --since=7d | --since=30d]"
---

# /proof

Render a CEO-readable proof packet that shows the moment TeamAgent blocked a new Claude Code session from repeating an old, user-corrected mistake.

## Supported invocations

- `/proof` — render a proof packet for the most recent blocked tool call.
- `/proof <rule-id>` — render a proof packet for a specific rule (e.g. `/proof no-moment-use-dayjs`).
- `/proof --since=7d` — windowed audit, last 7 days, across all rules.
- `/proof --since=30d` — windowed audit, last 30 days, across all rules.

## What to do

Parse the argument. Then:

### Case 1: no argument

Use the `generate-proof-packet` skill with rule id `latest`. The skill will find the most recent file under `.teamagent/events/` and assemble the packet. After the packet writes, invoke `ceo-proof-summary` with the same rule id to also produce the one-paragraph headline.

Print three things at the end:
1. Path to `summary.html` (the CEO-readable headline document).
2. Path to the CEO paragraph file.
3. One-line summary: rule id and block count.

### Case 2: positional rule id

Use the `generate-proof-packet` skill with the supplied rule id. Then invoke `ceo-proof-summary` with the same rule id. Same final three-line output as Case 1.

### Case 3: `--since=7d` or `--since=30d`

Use the `audit-feature-evidence` skill with rule id `all` and the supplied window. After the audit writes, invoke `ceo-proof-summary` once per rule that has at least one block in the window, passing the per-rule `audit.json` so the three numbers are windowed.

Print at the end:
1. Path to the audit directory.
2. Top 3 rules by block count in the window (one line each: rule id, block count, distinct sessions).
3. Total blocks across all rules in the window.

## Read-only / write-only contract

- Read-only: `.teamagent/rules/{active,pending}/`, `.teamagent/events/`. Never modify these.
- Write-only: `.teamagent/proof/<unix>-<rule_id>/` and `.teamagent/proof/<unix>-<rule_id>-audit/`. Never modify any other directory.

## Failure modes

- If `.teamagent/events/` is empty and the user ran `/proof` with no args, print exactly: `No block events recorded yet. TeamAgent rules are armed; nothing has tried to repeat a mistake.`
- If a supplied rule id does not exist in `active/` or `pending/`, list the available rule files and stop.
- If `--since=` is given a value other than `7d`, `30d`, `90d`, or `all`, print the accepted values and stop.

## Why this command exists

The headline a non-coder CEO must be able to read in ~30 seconds is:

> Previous Claude Code made this mistake. New Claude Code tried to repeat it. TeamAgent blocked it.

`/proof` is the single entry point that produces the artifacts proving that sentence is true for this team, this week.
