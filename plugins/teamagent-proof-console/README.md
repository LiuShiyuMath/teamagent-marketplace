# teamagent-proof-console

CEO-readable proof packets for TeamAgent. Renders the exact moment a NEW Claude Code session was about to repeat an OLD mistake, and TeamAgent BLOCKED it.

The headline a non-coder CEO must be able to read in roughly 30 seconds:

> Previous Claude Code made this mistake. New Claude Code tried to repeat it. TeamAgent blocked it.

## What this plugin proves

For every blocked tool call recorded by the sibling `teamagent-memory` plugin, this plugin can assemble a single self-contained directory that bundles:

- the rule card (what was learned, when, why),
- the hook event log entry (what was blocked, in which session),
- a transcript excerpt (the conversation context around the block),
- a before/after diff (the would-have-been command vs the actual blocked result),
- a single-paragraph CEO summary that opens with the headline sentence.

A CEO opens `summary.html`, reads one sentence, sees three numbers, closes the tab. That is the contract.

## How it consumes data from `teamagent-memory` (read-only)

The `teamagent-memory` plugin writes:

- rule cards under `.teamagent/rules/{pending,active}/<rule_id>.json`
- block events under `.teamagent/events/<unix>-block-<id>.json`

`teamagent-proof-console` reads both directories and writes nothing back to them. There is no shared mutable state; the proof console is strictly downstream of the memory plugin.

## Where artifacts land

Single-event packets:

```
.teamagent/proof/<unix>-<rule_id>/
  summary.html
  summary.md
  rule.json
  transcript-excerpt.txt
  hook-events.jsonl
  diff.md
```

Windowed audits:

```
.teamagent/proof/<unix>-<rule_id>-audit/
  audit.md
  audit.json
```

CEO paragraphs:

```
.teamagent/proof/<unix>-<rule_id>-ceo.md
```

Directories are time-stamped and never reused; each `/proof` invocation creates a fresh one.

## How a CEO reads the HTML summary

`summary.html` is a single self-contained file: inline CSS, no JS, no images, no external assets. Open it in any browser. Structure:

1. The headline sentence as an `<h1>`.
2. A three-stat strip (rule id, block count, first-learned date).
3. A red-bordered "What almost happened" box with the would-have-been command.
4. A green-bordered "What happened instead" box with the block reason and the suggested alternative.
5. A "Why we know this is a repeat" quote from the original user correction.
6. A footer with relative links to the sibling artifacts for anyone who wants to dig deeper.

Print-friendly, screenshot-friendly, fits on a 13" laptop without scrolling.

## Components

- `commands/proof.md` — the `/proof` slash command, the single entry point.
- `skills/generate-proof-packet/` — assembles one packet for one rule.
- `skills/audit-feature-evidence/` — counts blocks, sessions, users across a time window.
- `skills/ceo-proof-summary/` — writes the one-paragraph CEO headline.

## How to verify with claudefast

From the project root:

```sh
# Sanity check the plugin manifest loads.
claudefast -p "list skills from plugin teamagent-proof-console"

# Generate a proof packet for the latest block event.
claudefast -p "/proof"

# Audit the last 7 days across all rules.
claudefast -p "/proof --since=7d"

# A/B test with and without this plugin loaded.
claudefast --plugin-dir plugins/teamagent-proof-console -p "/proof"
```

For an audit-level trace, run with `claudefast streamjson` and pipe to a file for review.
