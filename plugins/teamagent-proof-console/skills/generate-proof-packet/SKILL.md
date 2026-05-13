---
name: generate-proof-packet
description: Assemble a CEO-readable proof packet that shows a previous Claude Code made a mistake, a new Claude Code tried to repeat it, and TeamAgent blocked the repeat mistake. Pulls the rule card, the matching PreToolUse hook event log, a transcript excerpt around the block, and a before/after diff (the would-have-been command vs the actual blocked result). Output is intended for a non-coder CEO and lives under .teamagent/proof/<unix>-<rule_id>/ with both summary.html and summary.md mirrors.
---

# generate-proof-packet

This skill builds one self-contained, read-only proof packet for a single rule and its matching block event(s). It exists so a non-coder CEO can open one HTML file and, in roughly 30 seconds, see the prevented-repeat-mistake story end-to-end.

## When to use

Invoke this skill when the user (or the `/proof` command) asks for proof that TeamAgent actually saved a repeat mistake. Typical triggers:
- "show me the proof"
- "/proof" with no arguments (most recent block)
- "/proof <rule_id>" (specific rule)
- "where is the evidence that TeamAgent worked"

Do NOT invoke for window/aggregate questions ("how many times this week"); that is `audit-feature-evidence`.

## Inputs

- A rule id (string, e.g. `no-moment-use-dayjs`) OR the literal `latest`.
- Optional: max transcript messages to extract around the event (default 8: 4 before, 4 after).

## Read-only sources (written by sibling plugin `teamagent-memory`)

- `.teamagent/rules/active/<rule_id>.json` — primary rule card.
- `.teamagent/rules/pending/<rule_id>.json` — fall back here if not yet promoted to active.
- `.teamagent/events/<unix>-block-<id>.json` — one file per PreToolUse block. Each file references the rule id it matched on.
- Current Claude Code transcript (best-effort: parse from session log path supplied by the harness, or fall back to "transcript not available" with a clear note).

Treat these as read-only. Never write into `.teamagent/rules/` or `.teamagent/events/`.

## Output directory

Create exactly one directory per packet:

```
.teamagent/proof/<unix>-<rule_id>/
  summary.html           # CEO-readable, the headline document
  summary.md             # text mirror of summary.html
  rule.json              # verbatim copy of the rule card
  transcript-excerpt.txt # N messages around the block
  hook-events.jsonl      # one JSON per matching block, newline-delimited
  diff.md                # before (would-have-run) vs after (blocked) diff
```

`<unix>` is the unix timestamp at packet generation. Never reuse a directory; always create a fresh one.

## Step-by-step

1. **Resolve the rule.**
   - If id is `latest`: list `.teamagent/events/` sorted by mtime desc, take the newest block event, read its `rule_id` field.
   - Else: use the supplied id directly.
   - Load the rule card from `.teamagent/rules/active/<id>.json`, falling back to `pending/`. If neither exists, abort with a clear error stating the rule was not found and listing what IS available.

2. **Locate matching block events.**
   - Scan `.teamagent/events/*.json` for files whose JSON `rule_id` matches.
   - For a single-event packet, take the newest. For all-events mode, list every match.
   - If zero matches, the packet still renders but `diff.md` and `summary.html` both clearly state "rule is active but has never been triggered yet" — that is a valid CEO outcome (preventive value).

3. **Extract transcript excerpt.**
   - Use the event's `transcript_path` (or `session_id` resolved to a path) if present.
   - Pull the N messages bracketing the event timestamp.
   - Redact obvious secrets (lines containing `sk-`, `ghp_`, `AKIA`, etc.) by replacing the value with `[REDACTED]`.
   - If transcript is not available, write a one-line note into `transcript-excerpt.txt`: `Transcript unavailable for event <id>; rule and hook event below stand on their own.`

4. **Write artifacts.**
   - `rule.json` — verbatim copy of the rule card. No transformation.
   - `hook-events.jsonl` — one line per matching event, JSON each, in chronological order.
   - `transcript-excerpt.txt` — plain text, one message per block, prefixed with role and timestamp.
   - `diff.md` — see "Diff format" below.
   - `summary.md` — see "CEO summary format" below.
   - `summary.html` — see "HTML format" below.

5. **Print a final 3-line confirmation to the user:**
   ```
   Packet: .teamagent/proof/<unix>-<rule_id>/
   Rule:   <rule_id> (<confidence>)
   Blocks: <N> matching events
   ```

## Diff format (`diff.md`)

Show the would-have-been action vs the actual blocked result side-by-side. Always frame it so the CEO sees "what almost happened" first, "what happened instead" second.

```markdown
# Before / After

## What new Claude Code was about to do
```
$ npm install moment
```

## What actually happened
```
[BLOCKED by TeamAgent] rule=no-moment-use-dayjs
  Reason: previously corrected by user on 2026-04-30.
  Suggested instead: npm install dayjs
```
```

## CEO summary format (`summary.md`)

Lead with the headline sentence. Then three lines of concrete numbers. Then a 4-line "what this means" paragraph in plain English. No code blocks except the diff snippet.

```markdown
# TeamAgent: prevented a repeat mistake

Previous Claude Code made this mistake. New Claude Code tried to repeat it. TeamAgent blocked it.

- Rule: no-moment-use-dayjs (confidence 0.92)
- Blocked: 1 time, in this session
- First learned: 2026-04-30 from user correction

The original mistake was installing the heavy `moment` library after the team standardised on `dayjs`. A new Claude Code session today tried to repeat the exact same install. TeamAgent recognised the pattern from the saved rule and stopped it at PreToolUse time, before any package was downloaded.
```

## HTML format (`summary.html`)

Single self-contained HTML file. No external CSS, no JS, no images. Inline `<style>` only. Structure:

1. `<h1>` headline = the verbatim sentence "Previous Claude Code made this mistake. New Claude Code tried to repeat it. TeamAgent blocked it."
2. A 3-row stat strip (rule id, block count, first-learned date) using simple flex CSS.
3. A "What almost happened" box (red left border) with the would-have-been command.
4. A "What happened instead" box (green left border) with the block reason and the suggested alternative.
5. A "Why we know this is a repeat" box quoting the original user correction from the rule card's `why` field.
6. A small footer linking to the sibling files (`rule.json`, `hook-events.jsonl`, `transcript-excerpt.txt`, `diff.md`) by relative path.

Keep the page under ~150 lines of HTML. Goal: print-friendly, screenshot-friendly, no scrolling on a 13" laptop.

## Worked example: moment -> dayjs

Suppose the rule card is:

```json
{
  "id": "no-moment-use-dayjs",
  "trigger": "npm install moment",
  "wrong": "npm install moment",
  "correct": "npm install dayjs",
  "why": "Team standardised on dayjs on 2026-04-30; moment is in maintenance mode.",
  "confidence": 0.92,
  "created_at": "2026-04-30T10:14:00Z",
  "source_session": "abc123"
}
```

And one matching event:

```json
{
  "id": "evt-9f",
  "rule_id": "no-moment-use-dayjs",
  "ts": "2026-05-13T14:02:11Z",
  "tool": "Bash",
  "blocked_input": {"command": "npm install moment"},
  "session_id": "new-session-xyz",
  "transcript_path": "/Users/m1/.claude/sessions/new-session-xyz.jsonl"
}
```

The packet directory becomes `.teamagent/proof/1715608931-no-moment-use-dayjs/` with:

- `rule.json` — copy of the rule card above.
- `hook-events.jsonl` — single line, the event JSON above.
- `transcript-excerpt.txt` — 8 messages around 2026-05-13T14:02:11Z. The line that triggered the block reads roughly: `[14:02:11] assistant tool_use Bash: npm install moment`.
- `diff.md` — as shown in the "Diff format" section.
- `summary.md` — as shown in the "CEO summary format" section.
- `summary.html` — same content, styled as described.

A CEO opens `summary.html`, reads one sentence, sees one number ("blocked 1 time"), and is done.

## Failure modes and what to do

- Rule id not found in active/ or pending/: abort, list the available rule files.
- Events directory empty: still emit the packet, but `summary.html` and `summary.md` state "rule armed, no repeats yet" — preventive value is real.
- Transcript path missing: emit the note line in `transcript-excerpt.txt` and continue; rule + event alone are enough.
- File write fails: surface the OS error verbatim, do not silently partial-write.

## Hand-off

After the packet is written, if the caller wants a one-paragraph headline for a slide or email, hand off to `ceo-proof-summary` with the same rule id. For a windowed aggregate ("last 7 days"), hand off to `audit-feature-evidence`.
