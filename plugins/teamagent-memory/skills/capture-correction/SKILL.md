---
name: capture-correction
description: Turn a visible user correction in the transcript into a durable rule card (trigger/wrong/correct/why) under .teamagent/rules/pending/. Designed to be invoked from the Stop hook so that the next Claude Code session in this project, or any teammate's session, is warned before repeating the same mistake. Use when the user said things like "no, use X instead", "don't use Y", "stop using Z", "should be W" after a tool call.
---

# capture-correction

## When to use

Invoke this skill at the end of a Claude Code session when the transcript contains an
explicit user correction directed at a prior assistant action — typically a tool call
(Bash, Edit, Write) that picked the wrong library, command, file, or convention.

The classic example: assistant ran `npm install moment`, user replied
"no, use dayjs instead". That single exchange should become a persistent rule card so
that any future Claude Code session in this project (or, if promoted to user scope,
on this machine) gets blocked before re-running `npm install moment`.

## Inputs

- `transcript_path` (from the Stop hook payload). Path to a JSONL transcript of the
  current session.
- Optional: `cwd` of the project (defaults to `process.cwd()`).

## Output schema (rule card)

Each rule card is a JSON file written to `.teamagent/rules/pending/<unix-ms>-<slug>.json`:

```json
{
  "id": "1731530000000-moment-to-dayjs",
  "trigger": "moment",
  "wrong": "moment",
  "correct": "dayjs",
  "why": "no, use dayjs instead — moment is in maintenance mode",
  "confidence": 1,
  "created_at": "2026-05-13T10:33:20Z",
  "source": "stop-capture"
}
```

Field rules:

- `id` — `<unix-ms>-<slug>`, where slug is `kebab-case(wrong)-to-kebab-case(correct)`.
- `trigger` — the substring that, when found inside a future tool call, should fire the
  block. Default to `wrong`. You may broaden it (e.g. `moment.js`) if the user line
  makes the intent clearer.
- `wrong` / `correct` — the offending and preferred terms.
- `why` — the surrounding user line, verbatim (truncated to ~200 chars).
- `confidence` — start at 1; the same wedge re-captured later increments it.
- `source` — always `stop-capture` when written by the Stop hook.

## Step-by-step workflow

1. Read the last ~30 messages from `transcript_path` (JSONL). Each line is an event;
   keep entries with `role == "user"` and the immediately preceding assistant tool_use
   block.
2. For each user message, run the regex catalogue:
   - `\bno[,.!]?\b`
   - `don'?t use\s+(\S+)`
   - `use\s+(\S+)\s+instead`
   - `stop using\s+(\S+)`
   - `should be\s+(\S+)`
   - `use\s+(\S+)\s+not\s+(\S+)`
3. On a hit, look back one assistant turn for a tool_use that contains a plausible
   `wrong` term (library name, CLI command, file path token). Pair `wrong` <- prior
   assistant; `correct` <- regex capture.
4. Build the rule card. Slug both sides. Compute `id`.
5. Check `.teamagent/rules/pending/` and `.teamagent/rules/active/` for an existing
   rule with the same `(wrong, correct)` pair (case-insensitive). If found, bump
   `confidence` on that file instead of writing a new one.
6. Otherwise write the new card to `.teamagent/rules/pending/<id>.json` with mode 0644.
7. Print a one-line confirmation to stderr: `teamagent: captured rule <id>`. Never
   write to stdout from the Stop hook (Claude Code reserves stdout for hook protocol).

## Confidence calibration

- `confidence == 1`: captured once; rule is suggestive but unverified. Review via
  `teamagent list` then `teamagent approve <id>`.
- `confidence >= 2`: captured multiple times across sessions; safe to auto-promote.
- The `review-new-rules` skill is the gate that moves pending -> active.

## Failure modes

- Transcript missing or unreadable -> exit 0 silently. Never crash the Stop hook.
- Regex matched but no preceding tool_use -> skip. We require evidence the assistant
  was about to do `wrong`.
- Write fails (read-only fs) -> log to stderr, exit 0.
- Network calls -> never. This skill is 100% local I/O.

## Worked example: moment -> dayjs

Transcript fragment:

```
{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"npm install moment"}}]}
{"role":"user","content":[{"type":"text","text":"no, use dayjs instead — moment is in maintenance mode"}]}
```

Capture output `.teamagent/rules/pending/1731530000000-moment-to-dayjs.json`:

```json
{
  "id": "1731530000000-moment-to-dayjs",
  "trigger": "moment",
  "wrong": "moment",
  "correct": "dayjs",
  "why": "no, use dayjs instead — moment is in maintenance mode",
  "confidence": 1,
  "created_at": "2026-05-13T10:33:20Z",
  "source": "stop-capture"
}
```

Next session, the PreToolUse hook reads `active/*.json`, sees a Bash command
containing `moment`, and emits a `decision: block` with a clear citation. The
`explain-rule-hit` skill renders that block into human language for the operator.
