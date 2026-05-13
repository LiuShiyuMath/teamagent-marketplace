---
name: explain-rule-hit
description: Render a PreToolUse rule hit (block decision) into human-friendly language so the operator instantly understands why the tool call was blocked. Use whenever the PreToolUse hook returns a decision=block citing a TeamAgent rule id, or the user asks "why blocked", "what rule hit", or "why did teamagent stop me". Cites the rule card (trigger, wrong, correct, why) and suggests the correct command.
---

# explain-rule-hit

## When to use

Trigger this skill whenever:

- The PreToolUse hook emitted `{ "decision": "block", "reason": "TeamAgent rule <id>: ..." }`.
- The user asks "why blocked", "what rule fired", "explain the block".
- A reviewer is auditing the proof packet and needs the human translation of a hook event.

This is the *consumer* side of the wedge. `capture-correction` writes rules;
`pretooluse-enforce` enforces them; this skill explains the enforcement.

## Inputs

- The `decision/reason` string from the hook output (or the block log line).
- The full rule card JSON loaded from `.teamagent/rules/active/<id>.json`.
- Optionally, the original `tool_input` (Bash command, Edit file_path, Write content).

## Output schema

A short, structured explanation, suitable to print directly to the operator:

```
TeamAgent blocked this tool call.

Rule:        <id>
Trigger:     <trigger>   (matched "<wrong>" inside the tool input)
Was about:   <wrong>
Should be:   <correct>
Reason:      <why>
Confidence:  <n>

Suggested fix:
  $ <rewritten command using <correct>>

To override once: re-run the command and confirm in the next prompt.
To retire this rule: teamagent reject <id>
```

## Step-by-step workflow

1. Parse the block reason. Extract `<id>`, `<wrong>`, `<correct>`, `<why>` from the
   structured prefix `TeamAgent rule <id>:`.
2. Load the canonical rule card from `.teamagent/rules/active/<id>.json` so the
   explanation matches the file on disk (the hook may have been racing).
3. Inspect the original tool_input to produce a *Suggested fix*:
   - Bash: substring-replace `wrong` -> `correct` in the command. Example
     `npm install moment` -> `npm install dayjs`.
   - Edit/Write: point at the file_path and tell the user to swap `wrong` -> `correct`
     in the proposed content.
4. Print the structured block above. Keep it under 20 lines. No emojis. No marketing.
5. If `confidence < 2`, append a single line: `(low confidence — confirm or run \`teamagent reject <id>\`).`

## Worked example: blocking `npm install moment`

PreToolUse output:

```json
{
  "decision": "block",
  "reason": "TeamAgent rule 1731530000000-moment-to-dayjs: prev Claude tried 'moment'; team rule says 'dayjs'. Why: no, use dayjs instead — moment is in maintenance mode"
}
```

Rule card on disk `.teamagent/rules/active/1731530000000-moment-to-dayjs.json`:

```json
{
  "id": "1731530000000-moment-to-dayjs",
  "trigger": "moment",
  "wrong": "moment",
  "correct": "dayjs",
  "why": "no, use dayjs instead — moment is in maintenance mode",
  "confidence": 2,
  "created_at": "2026-05-13T10:33:20Z",
  "source": "stop-capture"
}
```

Original tool_input:

```json
{"command": "npm install moment --save"}
```

Rendered explanation:

```
TeamAgent blocked this tool call.

Rule:        1731530000000-moment-to-dayjs
Trigger:     moment   (matched "moment" inside the tool input)
Was about:   moment
Should be:   dayjs
Reason:      no, use dayjs instead — moment is in maintenance mode
Confidence:  2

Suggested fix:
  $ npm install dayjs --save

To override once: re-run the command and confirm in the next prompt.
To retire this rule: teamagent reject 1731530000000-moment-to-dayjs
```

## Failure modes

- Rule card missing -> still print the block reason and a note `(rule file missing,
  hook reason verbatim above)`. Never invent.
- Reason string malformed -> dump it verbatim and exit; do not hallucinate fields.
- The original tool_input was not Bash/Edit/Write -> omit the suggested-fix section.
