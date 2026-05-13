---
name: audit-feature-evidence
description: Audit the evidence trail behind a single TeamAgent rule across a time window. Counts blocks, distinct sessions, distinct users (when metadata is present), and computes the 7-day and 30-day trend. Answers "how many times has this rule effectively saved us a repeat mistake" with numbers, not vibes. Outputs a compact audit.md and audit.json under the rule's proof directory. Read-only over .teamagent/events/ and .teamagent/rules/.
---

# audit-feature-evidence

This skill answers the rule-effectiveness question. Where `generate-proof-packet` is "show me ONE moment we stopped a repeat mistake", this skill is "show me how often THIS rule has stopped repeat mistakes over time".

## When to use

- `/proof --since=7d` or `/proof --since=30d`
- "how many times did TeamAgent save us this week"
- "is rule X actually getting hit"
- "audit rule no-moment-use-dayjs"

Do NOT invoke for single-moment proof; that is `generate-proof-packet`. Do NOT invoke for the one-paragraph CEO headline; that is `ceo-proof-summary`.

## Inputs

- A rule id (string) OR `all` to audit every active rule.
- A window string: `7d`, `30d`, `90d`, or `all` (default `30d`).

## Read-only sources

- `.teamagent/rules/active/<rule_id>.json`
- `.teamagent/rules/pending/<rule_id>.json` (audit pending too, marked clearly)
- `.teamagent/events/*.json` (one block event per file)

## Output

For a single rule, write under `.teamagent/proof/<unix>-<rule_id>-audit/`:

```
audit.md      # human-readable summary
audit.json    # machine-readable, schema below
```

For `all`, write `.teamagent/proof/<unix>-all-audit/` with one `audit.md` containing one section per rule plus a top-level totals block.

## Metrics to compute

For each rule in scope, across the requested window:

- `block_count` — number of matching events with `ts` inside the window.
- `distinct_sessions` — count of distinct `session_id` values among those events.
- `distinct_users` — count of distinct `user` / `user_email` values if present in events, else `null` (do not invent zeros — `null` means metadata was not recorded).
- `first_block_ts` — earliest event ts in window, ISO 8601, or `null`.
- `last_block_ts` — latest event ts in window, ISO 8601, or `null`.
- `trend_7d` — block count in the last 7 days.
- `trend_30d` — block count in the last 30 days.
- `rule_age_days` — days between rule `created_at` and now.
- `confidence` — copied verbatim from the rule card.
- `status` — `active` or `pending`.

If `block_count == 0`, the rule is still valuable (armed but unfired). Surface that explicitly; do not hide it.

## `audit.json` schema

```json
{
  "generated_at": "<iso8601>",
  "window": "30d",
  "rule_id": "no-moment-use-dayjs",
  "status": "active",
  "confidence": 0.92,
  "rule_age_days": 13,
  "metrics": {
    "block_count": 4,
    "distinct_sessions": 3,
    "distinct_users": 2,
    "first_block_ts": "2026-05-01T09:11:02Z",
    "last_block_ts": "2026-05-13T14:02:11Z",
    "trend_7d": 2,
    "trend_30d": 4
  },
  "events": [
    {"id": "evt-9f", "ts": "...", "session_id": "...", "tool": "Bash"}
  ]
}
```

The `events` array carries lightweight references only — full event JSON stays in `.teamagent/events/`.

## `audit.md` structure

```markdown
# Audit: no-moment-use-dayjs (last 30 days)

- Status: active (confidence 0.92, age 13d)
- Blocks in window: 4 (7d: 2, 30d: 4)
- Distinct sessions: 3
- Distinct users: 2
- First block: 2026-05-01 09:11 UTC
- Last block: 2026-05-13 14:02 UTC

## What this means

This rule has prevented 4 repeat mistakes across 3 separate Claude Code sessions in the last 30 days. The pace is accelerating: half of all blocks happened in the last 7 days, which usually means the team is onboarding more Claude Code users into the same workflow.

## Recent events

- 2026-05-13 14:02 UTC — session new-session-xyz — Bash `npm install moment`
- 2026-05-11 16:40 UTC — session sess-7k1 — Bash `npm install moment --save`
- ...
```

## Step-by-step

1. Resolve rule(s). If `all`, list every file in `.teamagent/rules/active/` plus every file in `.teamagent/rules/pending/`.
2. Parse window string into a UTC cutoff timestamp. Reject unknown strings with a clear error.
3. Stream `.teamagent/events/*.json`. For each event:
   - Parse `ts` and skip if before the cutoff.
   - Bucket by `rule_id`.
4. For each rule, compute the metrics above. Use only fields that actually exist on the event — never fabricate user emails or session ids.
5. Write `audit.json` first (so a machine reader can pick it up even if markdown rendering is interrupted), then `audit.md`.
6. Print a 3-line confirmation:
   ```
   Audit: .teamagent/proof/<unix>-<rule_id>-audit/
   Window: 30d
   Blocks: 4 across 3 sessions
   ```

## Edge cases

- Window with zero events: still write the files; `block_count: 0`, message: "rule armed, no repeats in window". This is a real CEO-relevant signal (rule is preventive).
- Rule exists but file is malformed JSON: skip with a warning line in `audit.md` under a `## Warnings` section. Do not crash the whole audit.
- Mixed pending + active in `all` mode: include both, group active first, then pending; clearly label.
- Clock skew: trust event `ts` as authoritative. If `ts` is missing on an event, fall back to file mtime and mark the row with a `~` prefix.

## Hand-off

If the caller wants a 1-paragraph CEO-language summary on top of the audit, hand off to `ceo-proof-summary` with the same rule id and pass `audit.json` as supporting data. If the caller wants one specific event's full proof packet (transcript excerpt, diff), hand off to `generate-proof-packet`.
