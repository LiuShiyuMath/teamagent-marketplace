# teamagent-marketplace

A Claude Code marketplace for **TeamBrain / TeamAgent** — turns one Claude Code's mistake-then-correction into a rule that a new Claude Code is blocked from repeating, with CEO-readable proof artifacts.

**One-line pitch:** *"Previous Claude Code made this mistake. New Claude Code tried to repeat it. TeamAgent blocked it."*

## Install

```bash
claude plugin marketplace add https://github.com/libz-renlab-ai/TeamBrain
claude plugin install teamagent-memory@teamagent-marketplace
claude plugin install teamagent-proof-console@teamagent-marketplace
claude plugin install teamagent-team-sync@teamagent-marketplace
```

## Plugins

| Plugin | What it does | Surface |
| --- | --- | --- |
| [`teamagent-memory`](./plugins/teamagent-memory) | Capture user-correction at `Stop`, write rule card, block repeat at `PreToolUse` | hooks + 3 skills + `teamagent` CLI |
| [`teamagent-proof-console`](./plugins/teamagent-proof-console) | Render proof packet a non-coder CEO can read | `/proof` command + 3 skills |
| [`teamagent-team-sync`](./plugins/teamagent-team-sync) | Publish personal rule to team pack, sync on `SessionStart`, resolve conflicts | hooks + 3 skills |

## The narrow wedge

This marketplace is built around **one** loop, not a "team AI platform":

1. Alice asks Claude Code to install `moment`.
2. User corrects: *"no, use `dayjs`"*.
3. `teamagent-memory` Stop hook captures the correction.
4. A rule card is written (`trigger=moment`, `wrong=npm install moment`, `correct=use dayjs`, `why`, `confidence`).
5. New session: Bob asks Claude Code to install `moment`.
6. `teamagent-memory` PreToolUse hook **blocks** the install before it runs.
7. `teamagent-proof-console` renders the proof packet for the CEO.
8. `teamagent-team-sync` promotes Alice's rule into the team rule pack so other engineers' Claude Codes also block it.

## Verification

```bash
# Marketplace + plugin discovery
claude -h
claude plugin --help

# A/B: same prompt, with vs without the plugins
claudefast --plugin-dir ./plugins/teamagent-memory -p "install moment for date parsing"
claudefast -p "install moment for date parsing"   # control

# Audit-level stream
claudefast --plugin-dir ./plugins/teamagent-memory --output-format=stream-json -p "install moment"

# Eval the grill answer against the local rubric
python .claude/skills/teambrain-office-hours-grill-eval/scripts/eval_grill_output.py docs/grill-answer.md
```

## Structure

See `TASK.md` for the original mandate. The directory follows
[`anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) and
[`obra/superpowers`](https://github.com/obra/superpowers) layout conventions.
