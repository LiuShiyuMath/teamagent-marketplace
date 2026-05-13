---
name: review-new-rules
description: Walk the user through pending rule cards captured by the Stop hook, let them review/edit/approve/reject each one, then promote approved cards from .teamagent/rules/pending/ to .teamagent/rules/active/ so PreToolUse will start enforcing them. Use when the user asks to "review rules", "approve rules", "see new rule cards", or after a session that captured corrections.
---

# review-new-rules

## When to use

After one or more sessions have captured corrections, the rule cards sit in
`.teamagent/rules/pending/`. They do NOT enforce anything until promoted to
`.teamagent/rules/active/`. This skill is the human-in-the-loop gate.

Invoke when:

- The user says "review rules" / "approve rules" / "what did teamagent learn".
- A teammate has just merged a branch that included pending rules.
- The doctor (`teamagent doctor`) reports pending rules at session start.

## Inputs

- `.teamagent/rules/pending/*.json` — candidate rule cards.
- `.teamagent/rules/active/*.json` — current enforcing rules (for conflict detection).
- Optional: `.teamagent/config.json` — allowlist/denylist of triggers.

## Output

- Files moved from `pending/` to `active/` (approved), or deleted (rejected).
- Edits to JSON cards (when the user tweaks `trigger`, `correct`, or `why`).
- A short summary printed to the user.

## Step-by-step workflow

1. List pending rules: `find .teamagent/rules/pending -name '*.json' | sort`.
2. For each card:
   - Pretty-print it (id, trigger, wrong->correct, why, confidence, created_at).
   - Check for conflicts: an active rule with the same `wrong` but a different
     `correct` is a conflict — surface it and ask the user to pick one.
   - Offer four actions: `approve`, `reject`, `edit`, `skip`.
3. On `approve`: move file to `.teamagent/rules/active/<id>.json`. Preserve mtime.
4. On `reject`: delete the file. Log to `.teamagent/rules/log.jsonl`
   (one line per decision, never any user content beyond the rule fields).
5. On `edit`: open the user's `$EDITOR` on the JSON, validate after save, then
   re-prompt approve/reject.
6. On `skip`: leave the file in pending/ for next time.
7. After the loop, print a summary:
   `Approved: N, Rejected: M, Pending remaining: K`.

## Conflict resolution

- Same `wrong`, different `correct` -> the newer card wins by default, but always
  ask the user explicitly. Record both in `log.jsonl` with `resolution: replaced` /
  `resolution: kept_existing`.
- Same `wrong`, same `correct` -> increment `confidence` on the active card and
  delete the pending one.
- `trigger` overlaps an active rule's `trigger` as a substring -> warn, do not
  auto-merge.

## Confidence promotion

A pending rule with `confidence >= 2` (captured the same correction twice) may be
auto-promoted if `.teamagent/config.json` has `"auto_promote_at_confidence": 2`.
Default is manual.

## CLI shortcut

The `teamagent` binary exposes the same flow non-interactively:

```
teamagent list                 # show all pending + active
teamagent approve <id>         # move pending/<id>.json -> active/
teamagent reject  <id>         # delete pending/<id>.json
teamagent show    <id>         # pretty-print the JSON
```

This skill is the conversational wrapper around those commands plus conflict
handling.

## Worked example

Pending file `.teamagent/rules/pending/1731530000000-moment-to-dayjs.json`:

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

User says "approve". The skill runs `teamagent approve 1731530000000-moment-to-dayjs`,
the file lands in `.teamagent/rules/active/`, and the next Bash tool call
containing `moment` will be blocked by `pretooluse-enforce.cjs`.

## Failure modes

- Pending dir missing -> "No pending rules." exit 0.
- JSON invalid -> show the parse error, offer to delete the file.
- `EDITOR` unset on `edit` -> fall back to `vi`.
- Never write outside `.teamagent/`. Never network.
