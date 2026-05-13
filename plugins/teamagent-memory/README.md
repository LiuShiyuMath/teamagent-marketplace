# teamagent-memory

> Previous Claude Code made this mistake. New Claude Code tried to repeat it.
> TeamAgent blocked it.

## The loop

1. Alice asks Claude Code to install a library, picks `moment`.
2. User corrects: "no, use `dayjs` instead — moment is in maintenance mode".
3. The `Stop` hook (`stop-capture.cjs`) scans the transcript tail.
4. It writes a rule card to `.teamagent/rules/pending/<id>.json`
   (`trigger / wrong / correct / why / confidence`).
5. The user runs `teamagent approve <id>`, promoting it to `.teamagent/rules/active/`.
6. New session, Bob asks Claude Code to "install moment".
7. `UserPromptSubmit` (`userprompt-inject.cjs`) prepends a system-reminder warning.
8. `PreToolUse` (`pretooluse-enforce.cjs`) sees `moment` in the proposed Bash
   command and emits `{"decision":"block","reason":"TeamAgent rule ..."}`.

Dashboard outcome: `saved one repeat mistake; rule confidence +1`.

## Install

```bash
# in a Claude Code session, after this repo is configured as a marketplace
/plugin install teamagent-memory@teamagent-marketplace
```

Or for local development against this repo, set
`CLAUDE_PLUGIN_ROOT=$(pwd)/plugins/teamagent-memory` and run claudefast.

## Files & how they wire together

```
plugins/teamagent-memory/
  .claude-plugin/plugin.json        # manifest (name, version, author)
  hooks/hooks.json                  # wires three lifecycle events
  hooks/pretooluse-enforce.cjs      # blocks Bash/Edit/Write that match a rule
  hooks/stop-capture.cjs            # writes rule cards from user corrections
  hooks/userprompt-inject.cjs       # warns Claude in-prompt before the tool call
  skills/capture-correction/SKILL.md
  skills/explain-rule-hit/SKILL.md
  skills/review-new-rules/SKILL.md
  bin/teamagent                     # list/approve/reject/show/doctor CLI

ascii data flow:

  user types prompt
        |
        v
  +----------------------+   trigger match?   +----------------------+
  | UserPromptSubmit     |------------------->| inject <system-      |
  | userprompt-inject.cjs|                    | reminder>            |
  +----------------------+                    +----------------------+
        |
        v
  Claude proposes tool call
        |
        v
  +----------------------+   rule match?      +----------------------+
  | PreToolUse           |------------------->| decision: block      |
  | pretooluse-enforce.cjs                    | with rule citation   |
  +----------------------+                    +----------------------+
        |
        v (no match)
  tool runs; user may correct
        |
        v
  +----------------------+   correction?      +----------------------+
  | Stop                 |------------------->| write rule card to   |
  | stop-capture.cjs     |                    | .teamagent/rules/    |
  +----------------------+                    | pending/<id>.json    |
                                              +----------------------+
```

## Privacy & security guarantees

- Hooks are pure Node stdlib. No npm dependencies; no `require` outside `fs / path / os`.
- `pretooluse-enforce.cjs` is strictly read-only: it loads rule JSON, inspects the
  proposed `tool_input`, and emits a one-shot decision. No fs writes. No spawn.
  No sockets.
- `stop-capture.cjs` reads only the transcript path supplied by Claude Code and
  writes ONE small JSON file per captured correction under `.teamagent/rules/
  pending/`. No network. No external copies. The transcript is never moved or
  uploaded.
- `userprompt-inject.cjs` reads only the prompt payload and emits an
  `additionalContext` string. No fs writes. No network.
- Every hook exits 0 on any unexpected error so Claude Code is never wedged.
- Rule cards never store secrets — by construction they hold short library/CLI
  tokens plus a 200-char `why` excerpt.

## Configuration (optional)

Drop a `.teamagent/config.json` at the project root:

```json
{
  "auto_promote_at_confidence": 2,
  "allow_triggers": ["moment", "lodash"],
  "deny_triggers":  ["secret", "token"]
}
```

The plugin's CLI and skills honor these. The hooks themselves treat the file as
informational today and will read it in a follow-up release.

## Verify locally with claudefast

```bash
# 1. Sanity-check the plugin loads.
claudefast --plugin-dir ./plugins/teamagent-memory -p 'who are you?'

# 2. Simulate the Stop hook capturing a correction.
echo '{"transcript_path":"/tmp/fake-transcript.jsonl"}' \
  | node plugins/teamagent-memory/hooks/stop-capture.cjs

# 3. Drop a rule card by hand and exercise PreToolUse.
mkdir -p .teamagent/rules/active
cat > .teamagent/rules/active/demo-moment-to-dayjs.json <<'JSON'
{"id":"demo-moment-to-dayjs","trigger":"moment","wrong":"moment","correct":"dayjs","why":"use dayjs instead","confidence":1}
JSON
echo '{"tool_name":"Bash","tool_input":{"command":"npm install moment"}}' \
  | node plugins/teamagent-memory/hooks/pretooluse-enforce.cjs

# 4. Audit via stream-json (the README header for the marketplace doc).
claudefast --plugin-dir ./plugins/teamagent-memory --output-format stream-json -p 'install moment'

# 5. CLI doctor.
./plugins/teamagent-memory/bin/teamagent doctor
./plugins/teamagent-memory/bin/teamagent list
```

A successful PreToolUse step prints
`{"decision":"block","reason":"TeamAgent rule demo-moment-to-dayjs: ..."}` to stdout.
