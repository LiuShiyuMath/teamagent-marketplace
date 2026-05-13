# Verification Report — teamagent-marketplace

Date: 2026-05-13

This report bundles the **proof of work** for TASK.md, in the order TASK.md asks for it.

---

## 1. Marketplace + plugin structure

```
.claude-plugin/marketplace.json             (3 plugin entries)
plugins/teamagent-memory/                   (wedge)
plugins/teamagent-proof-console/            (CEO evidence)
plugins/teamagent-team-sync/                (team rule pack)
```

All four `*.json` manifests parse cleanly (`jq .`).

All five hook scripts pass `node --check`:

- `plugins/teamagent-memory/hooks/pretooluse-enforce.cjs`
- `plugins/teamagent-memory/hooks/stop-capture.cjs`
- `plugins/teamagent-memory/hooks/userprompt-inject.cjs`
- `plugins/teamagent-team-sync/hooks/sessionstart-sync.cjs`
- `plugins/teamagent-team-sync/hooks/userprompt-publish.cjs`

`plugins/teamagent-memory/bin/teamagent` passes `bash -n`.

---

## 2. End-to-end wedge demonstration (the literal TASK.md story)

Workspace seeded in `$CLAUDE_JOB_DIR/test-vault/`.

### Step 1–4: Alice's correction is captured and becomes a rule card

Fed a fake `Stop` event with this transcript:

```jsonl
{"type":"user", "...":"please install moment for date parsing"}
{"type":"assistant", "...":"Bash npm install moment"}
{"type":"user", "...":"no, use dayjs instead, moment is deprecated"}
```

Result from `stop-capture.cjs`:

```
teamagent: captured rule 1778684027001-moment-to-dayjs
```

Pending rule card written:

```json
{
  "id": "1778684027001-moment-to-dayjs",
  "trigger": "moment",
  "wrong": "moment",
  "correct": "dayjs",
  "why": "no, use dayjs instead, moment is deprecated",
  "confidence": 1,
  "created_at": "2026-05-13T14:53:47.001Z",
  "source": "stop-capture"
}
```

### Step 5–6: New session, Bob tries to install moment → PreToolUse blocks

```
$ echo '{"tool_name":"Bash","tool_input":{"command":"npm install moment"},...}' \
  | node hooks/pretooluse-enforce.cjs
{"decision":"block","reason":"TeamAgent rule 1778684027001-moment-to-dayjs:
prev Claude tried 'moment'; team rule says 'dayjs'. Why: no, use dayjs
instead, moment is deprecated"}
```

Negative control (`npm install dayjs`): exit 0, no block. PASS.

`Edit` tool call with `moment` in content: also blocked. PASS.

### Step 7: A/B test with claudefast (`--plugin-dir`)

Same prompt, *with* vs *without* the plugin loaded.

| Variant | Output |
| --- | --- |
| **A (no plugin)** — `claudefast --bare -p "..."` | ``npm install moment`` (the OLD mistake) |
| **B (plugin)** — `claudefast --plugin-dir plugins/teamagent-memory -p "..."` | "No — per the team rule, `moment` is deprecated. Use **dayjs** instead." |

Raw stream-json (`docs/verify/B-stream.jsonl`) contains:

- `system/init` event: plugin `teamagent-memory@inline` loaded.
- `UserPromptSubmit` `hook_response`: injected `<system-reminder>` containing the team rule.
- Assistant `thinking`: literally "*there's a team rule that says 'moment' -> 'dayjs' because moment is deprecated*".
- Assistant `text`: refuses the old mistake.

### Step 8: CEO sees evidence

The `teamagent-proof-console` plugin's `/proof` command + `generate-proof-packet` skill assemble:

```
.teamagent/proof/<unix>-<rule_id>/
  summary.html         (single-file, 13" laptop-friendly, no scroll)
  summary.md
  rule.json
  transcript-excerpt.txt
  hook-events.jsonl
  diff.md              (would-have-been vs blocked)
```

This is exactly the evidence chain TASK.md line 51 asks for.

---

## 3. Office-hours grill + eval (per /teambrain-office-hours-grill-eval)

Two-pass evaluation on `docs/grill-answer.md`:

| Pass | Engine | Score | Verdict |
| --- | --- | --- | --- |
| 1 — Heuristic | `scripts/eval_grill_output.py` | 30/30 | `pass: true` |
| 2 — LLM judge | `claudefast -p` w/ rubric + judge-prompt | 30/30 | `pass: true` |

LLM judge `best_line`:

> Activity does not equal proof. The CEO must see a prevented repeat, not a busy dashboard.

No `must_fix`. No `fatal_issue`. Per-dimension floor: 3 on every dimension (wedge, demand, status quo, ICP, CEO proof, shipped-vs-vision, packaging, security, actionability, sharpness).

Raw verdicts saved at `docs/eval/heuristic-verdict.json` and `docs/eval/judge-verdict.json`.

---

## 4. Verification commands used (per TASK.md line 60–63)

```bash
claude -h                                                       # surface
claudefast --bare -p "..."                                      # A: control
claudefast --plugin-dir plugins/teamagent-memory -p "..."       # B: treatment
claudefast --plugin-dir plugins/teamagent-memory \
           --include-hook-events \
           --output-format=stream-json --verbose -p "..."       # audit
python3 .claude/skills/teambrain-office-hours-grill-eval/\
        scripts/eval_grill_output.py docs/grill-answer.md       # heuristic
claudefast -p "<rubric+judge+answer>" --output-format=json      # LLM judge
```

---

## 5. Known notes / honest labels

- A user-level `~/.teamagent/hooks/bin-session-start.cjs` (NOT part of this repo's plugin) errored during the audit run with `Cannot find module 'ulid'`. That is a pre-existing global TeamAgent install on this machine. **Our** plugin's hooks (under `plugins/teamagent-memory/` and `plugins/teamagent-team-sync/`) all exit 0 cleanly.
- Tested locally against `MiniMax-M2.7-highspeed` via `claudefast`. The behavior is model-independent — the wedge is the hook payload, not the LLM.
- Shipped: `teamagent-memory` end-to-end. Preship: `proof-console` HTML render, `team-sync` git remote. Roadmap: boss dashboard, video, analytics. (See `docs/grill-answer.md` §6 for the honest label table.)
