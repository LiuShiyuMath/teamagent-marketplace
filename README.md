<!--
  Landing page for the teamagent-marketplace.
  Rendered on https://github.com/LiuShiyuMath/teamagent-marketplace
-->

<div align="center">

# teamagent-marketplace

### *"Previous Claude Code made this mistake. New Claude Code tried to repeat it. **TeamAgent blocked it.**"*

A three-plugin Claude Code marketplace that turns one user-correction into a rule that the **next** Claude session is blocked from repeating — with a CEO-readable proof artifact for every catch.

[**▶ Install**](#install) · [**▶ The Wedge**](#the-wedge) · [**▶ A/B Receipts**](#ab-receipts-real-runs) · [**▶ Plugins**](#the-three-plugins) · [**▶ Verify**](#verify-your-install)

</div>

---

<div align="center">

## ▷ Live demo (30 seconds)

<img src="docs/verify/demo.gif" alt="A/B demo: same prompt, with vs without teamagent-memory. A recommends moment (the deprecated lib). B refuses, citing the team rule, and recommends dayjs." width="820" />

<sub><i>Same prompt. <b>A:</b> no plugin → recommends the deprecated <code>moment</code>. <b>B:</b> <code>--plugin-dir teamagent-memory</code> → refuses and cites the team rule.</i></sub>

</div>

---

## The wedge

We do **one** thing. The whole marketplace is justified by one sentence:

> When *yesterday's* Claude session was corrected by a teammate — *"no, use dayjs, not moment"* — the correction is captured as a **rule card** and enforced at `PreToolUse` time. *Tomorrow's* Claude session, on a *different* engineer's laptop, never gets to run `npm install moment` in the first place.

That's it. Everything else — the proof console, the team-sync, the dashboards on the roadmap — is in service of that one loop.

```
   Alice's session                                Bob's session (next day, different laptop)
  ┌─────────────────────────┐                   ┌──────────────────────────────────────┐
  │ user: install moment    │                   │ user: install moment                 │
  │ claude: npm install ... │                   │ claude: (about to run npm install)   │
  │ user: no, use dayjs ✋   │  ──── rule card  ─▶│ ┌─ PreToolUse hook ─────────────┐    │
  └─────────────────────────┘  moment→dayjs    │ │ BLOCKED: team rule says use   │    │
                                                │ │ dayjs. Reason: Alice's note.  │    │
                                                │ └───────────────────────────────┘    │
                                                └──────────────────────────────────────┘
```

---

## Install

```bash
# 1. Add the marketplace
claude plugin marketplace add https://github.com/LiuShiyuMath/teamagent-marketplace

# 2. Install at least the wedge plugin (the other two are recommended siblings)
claude plugin install teamagent-memory@teamagent-marketplace
claude plugin install teamagent-proof-console@teamagent-marketplace
claude plugin install teamagent-team-sync@teamagent-marketplace
```

Local-only install (no marketplace registration, for testing):

```bash
git clone https://github.com/LiuShiyuMath/teamagent-marketplace
cd teamagent-marketplace
claude --plugin-dir plugins/teamagent-memory
```

---

## A/B receipts (real runs)

Both runs use the same model (`MiniMax-M2.7-highspeed`) and the same prompt:
> *"I need to format dates in JS, should I install moment?"*

<table>
<tr>
<td width="50%" valign="top">

### ❌ A · CONTROL — no plugin

```text
$ claudefast --bare -p "..."
```

```
`npm install moment` — 轻量替代:
`Intl.DateTimeFormat`（内置）或
`date-fns`（tree-shakable）.
```

Claude offers `npm install moment` as the **first** answer. That's the old mistake.

</td>
<td width="50%" valign="top">

### ✅ B · TREATMENT — teamagent-memory loaded

```text
$ claudefast \
    --plugin-dir plugins/teamagent-memory \
    -p "..."
```

```
No — per the team rule, `moment` is
deprecated. Use **dayjs** instead.
```

The `UserPromptSubmit` hook injected `<system-reminder>` citing the team rule. Claude obeys. Old mistake blocked.

</td>
</tr>
</table>

Raw evidence checked into the repo:

- `docs/verify/A-control.json` · `docs/verify/B-treatment.json` — raw `--output-format=json` from both runs
- `docs/verify/B-stream.jsonl` — full `stream-json` audit trail with **every hook event timestamped**
- `docs/verify/REPORT.md` — full verification report (read this if you're a CEO or buyer)
- `docs/verify/demo.cast` · `docs/verify/demo.gif` — the GIF above, rerunnable

Reproduce the demo yourself:

```bash
bash docs/verify/demo.sh
```

---

## The three plugins

| Plugin | One-line | What's inside |
| --- | --- | --- |
| **[teamagent-memory](plugins/teamagent-memory/)** *(the wedge)* | Capture user-correction → block repeat | 3 skills · 3 hooks (`PreToolUse` · `Stop` · `UserPromptSubmit`) · `teamagent` CLI |
| **[teamagent-proof-console](plugins/teamagent-proof-console/)** | Render a CEO-readable proof packet | 3 skills · `/proof` slash command · single-file HTML CEO summary |
| **[teamagent-team-sync](plugins/teamagent-team-sync/)** | Promote a personal rule to a team-wide rule | 3 skills · 2 hooks (`SessionStart` git pull · `UserPromptSubmit` publish-intent) |

> **Read first:** [`teamagent-memory`](plugins/teamagent-memory/README.md) is the only one that's strictly required. The other two are siblings. Install them together if you want the full proof loop.

---

## Plugin architecture

```
teamagent-marketplace/
├── .claude-plugin/
│   └── marketplace.json                         ← three plugins registered here
├── plugins/
│   ├── teamagent-memory/                        ← the wedge
│   │   ├── .claude-plugin/plugin.json
│   │   ├── skills/
│   │   │   ├── capture-correction/SKILL.md      ← extract rule card from Stop transcript
│   │   │   ├── explain-rule-hit/SKILL.md        ← human explanation of a PreToolUse block
│   │   │   └── review-new-rules/SKILL.md        ← gate pending → active promotion
│   │   ├── hooks/
│   │   │   ├── hooks.json
│   │   │   ├── stop-capture.cjs                 ← Stop hook  (writes rule cards)
│   │   │   ├── pretooluse-enforce.cjs           ← PreToolUse hook (blocks repeats)
│   │   │   └── userprompt-inject.cjs            ← UserPromptSubmit hook (early warn)
│   │   ├── bin/teamagent                        ← CLI: list / approve / reject / show / doctor
│   │   └── README.md
│   ├── teamagent-proof-console/
│   │   ├── skills/{generate-proof-packet,audit-feature-evidence,ceo-proof-summary}/
│   │   └── commands/proof.md                    ← /proof command
│   └── teamagent-team-sync/
│       ├── skills/{publish-team-rule,resolve-rule-conflict,promote-project-rule}/
│       └── hooks/{sessionstart-sync,userprompt-publish}.cjs
└── docs/
    ├── grill-answer.md                          ← office-hours grill (30/30 on both heuristic + LLM judge)
    ├── eval/                                    ← grill eval verdicts (raw JSON)
    └── verify/                                  ← A/B run JSON, stream-json audit, GIF, REPORT
```

---

## How a rule card looks

The minimum viable artifact. Written by `Stop` hook, read by `PreToolUse` hook.

```json
{
  "id":         "1778684027001-moment-to-dayjs",
  "trigger":    "moment",
  "wrong":      "moment",
  "correct":    "dayjs",
  "why":        "no, use dayjs instead, moment is deprecated",
  "confidence": 1,
  "created_at": "2026-05-13T14:53:47.001Z",
  "source":     "stop-capture"
}
```

`trigger` is what the new session is matched against. `correct` is what the rule wants instead. `why` is **always the human's words**, never the LLM's — this is the trust anchor.

---

## Verify your install

The four verification surfaces called out in TASK.md:

| Command | Tells you |
| --- | --- |
| `claude -h` | Built-in surface — confirms `claude plugin marketplace add` works. |
| `claudefast -p "..."` | Cheap run on a single prompt. Single-shot. |
| `claudefast --output-format=stream-json --include-hook-events -p "..."` | Audit-level: every hook fired, every `additionalContext`, every `decision: "block"`. |
| `claudefast --plugin-dir <path> -p "..."` | A/B test: same prompt, with vs without plugin. |

Validation utility scripts also shipped:

```bash
# Validate the office-hours grill answer (heuristic gate)
python3 .claude/skills/teambrain-office-hours-grill-eval/scripts/eval_grill_output.py docs/grill-answer.md
# → {"pass": true, "score_total": 30, ...}

# Smoke-test the three hook scripts and the CLI in one go
bash docs/verify/demo.sh
```

The CEO-readable verification report:

→ **[docs/verify/REPORT.md](docs/verify/REPORT.md)** — bundles the rule-card capture, the PreToolUse block proof, the A/B side-by-side, the stream-json audit excerpt, and the heuristic + LLM judge verdicts (both 30/30).

---

## FAQ

<details>
<summary><b>Isn't this just a fancier CLAUDE.md?</b></summary>

No. `CLAUDE.md` is read by the model as text. The model can skip it, forget it, or run the tool call before it gets that far. The wedge here is a **hook that fires before the tool call**. Two different layers of the runtime.
</details>

<details>
<summary><b>False positives? What if I actually want to install <code>moment</code>?</b></summary>

Three guardrails:
1. New rules land in `.teamagent/rules/pending/` and require an explicit `teamagent approve <id>` to enforce.
2. When a `PreToolUse` block fires, the reason is shown — the engineer can choose to override.
3. Low-confidence rules can be downgraded from *block* to *warn-only* (`multi-suggest` mode in `teamagent-team-sync`).
</details>

<details>
<summary><b>Does it phone home?</b></summary>

No. All artifacts live under `.teamagent/` in your project. Team-sync is **opt-in** via an explicit `remote` field in `.teamagent/team/config.json`, and even then it only pushes/pulls from a git repo you own.
</details>

<details>
<summary><b>How do I uninstall?</b></summary>

```bash
claude plugin disable teamagent-memory
rm -rf .teamagent
```
Behavior restores in < 5 seconds. This is a written commitment, not a slogan.
</details>

<details>
<summary><b>What's <i>not</i> in v0?</b></summary>

Boss/CEO live dashboard, video upload, team analytics. Those are roadmap. We deliberately do not ship them in v0 because they create surveillance dynamics that kill adoption (see <a href="docs/grill-answer.md">the grill</a> for the long version).
</details>

---

## Acknowledgements

Structure follows the conventions of [`anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) and [`obra/superpowers`](https://github.com/obra/superpowers).

Office-hours grill rubric adapted to the TeamAgent risk surface; the local eval skill lives in [`.claude/skills/teambrain-office-hours-grill-eval/`](.claude/skills/teambrain-office-hours-grill-eval/).

---

<div align="center">

*Activity does not equal proof.<br>The CEO must see a **prevented repeat**, not a busy dashboard.*

</div>
