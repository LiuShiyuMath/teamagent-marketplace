---
name: publish-team-rule
description: Publish (promote) a personal Claude-Code rule card from .teamagent/rules/active/ into the team pack at .teamagent/team/<team-id>/rules/active/, append to the promotions ledger, and git push if a remote is configured. Use when the user says "publish this rule", "promote to team", "share this with the team", "make this team-wide", or "/team publish". The flow is: validate -> deduplicate -> copy into team pack -> append promotions.jsonl -> git commit and push if remote configured -> summarize.
---

# publish-team-rule

## When to use

Invoke this skill when an engineer wants to share a personal correction (captured
earlier by the sibling `teamagent-memory` plugin) with the whole team. Triggers:

- "publish this rule"
- "promote to team"
- "share this with the team"
- "make this team-wide"
- "team rule this"
- `/team publish`

The UserPromptSubmit hook in this plugin will inject a routing nudge for these
phrases. You may also be invoked directly by the user.

## Inputs

You operate on the files already on disk. Specifically:

- Source (personal active rules): `.teamagent/rules/active/*.json`
- Team config: `.teamagent/team/config.json` with shape:

```json
{
  "team_id": "renlab-core",
  "remote": "git@github.com:libz-renlab-ai/teamagent-rules.git",
  "default_branch": "main"
}
```

- Target team pack dir: `.teamagent/team/<team-id>/rules/active/`
- Audit ledger: `.teamagent/team/<team-id>/promotions.jsonl` (append-only JSON Lines)
- Manifest: `.teamagent/team/<team-id>/manifest.json` (list of active rule ids + last-updated)

If `config.json` is missing, ask the user to create it first. If `remote` is absent,
publish only locally to the shared filesystem path; do not attempt git.

## Workflow

1. **Pick the source rule.**
   - If the user named a specific rule id or trigger, pick that one from
     `.teamagent/rules/active/`.
   - Otherwise default to the newest file in that directory (largest mtime).
   - If the directory is empty, stop and tell the user there is nothing to publish.

2. **Validate.** The rule card must have non-empty `trigger`, `wrong`, `correct`,
   and `why` fields and a numeric `confidence`. Reject and explain if malformed.

3. **Deduplicate against the team pack.** Read every JSON in
   `.teamagent/team/<team-id>/rules/active/`. If a rule with the same `trigger`
   already exists AND the same `correct` value, skip publish and report
   "already published". If the trigger matches but `correct` differs, STOP and
   instruct the user to run `resolve-rule-conflict` first.

4. **Copy.** Write the validated rule to
   `.teamagent/team/<team-id>/rules/active/<rule-id>.json`. Preserve the
   original rule id (a stable hash from teamagent-memory) so promotions are
   idempotent.

5. **Append to ledger.** Append a JSON line to
   `.teamagent/team/<team-id>/promotions.jsonl` with shape:

   ```json
   {"ts":"2026-05-13T10:22:00Z","rule_id":"...","promoter":"alice@renlab.ai","trigger":"npm install moment","correct":"npm install dayjs","source":"personal-active"}
   ```

6. **Refresh manifest.** Rewrite `manifest.json` to list every rule id under
   `rules/active/` and set `updated_at` to the current ISO timestamp.

7. **Git push (only if `remote` configured).** Inside the team dir:

   ```
   git add rules/active/<rule-id>.json promotions.jsonl manifest.json
   git commit -m "promote(rule): <trigger short> -> <correct short>"
   git push origin <default_branch>
   ```

   On push failure (auth, non-fast-forward, network), surface the error and tell
   the user the rule is staged locally and they can retry. Never silently lose
   the commit.

8. **Summarize.** Report rule id, team id, whether git push happened, and the
   ledger line that was appended.

## Worked example (the moment->dayjs wedge)

Suppose `teamagent-memory` previously captured this personal active rule at
`.teamagent/rules/active/rule_2026_05_12_a1b2c3.json`:

```json
{
  "id": "rule_2026_05_12_a1b2c3",
  "trigger": "npm install moment",
  "wrong": "moment",
  "correct": "dayjs",
  "why": "moment is in maintenance mode; team standardized on dayjs for tree-shaking and bundle size.",
  "confidence": 3,
  "captured_at": "2026-05-12T18:01:55Z",
  "captured_by": "alice@renlab.ai"
}
```

User says "publish this rule". Steps:

1. Newest file -> `rule_2026_05_12_a1b2c3.json`. Pick it.
2. Validate -> all fields present.
3. Dedup -> no rule with trigger `npm install moment` in team pack yet.
4. Copy to `.teamagent/team/renlab-core/rules/active/rule_2026_05_12_a1b2c3.json`.
5. Append to ledger:

   ```
   {"ts":"2026-05-13T10:22:00Z","rule_id":"rule_2026_05_12_a1b2c3","promoter":"alice@renlab.ai","trigger":"npm install moment","correct":"dayjs","source":"personal-active"}
   ```

6. Refresh manifest -> `{ "team_id": "renlab-core", "rule_ids": ["rule_2026_05_12_a1b2c3"], "updated_at": "2026-05-13T10:22:00Z" }`.
7. Git: commit `promote(rule): npm install moment -> dayjs`, push to `origin/main`.
8. Tell user: "Promoted rule_2026_05_12_a1b2c3 to renlab-core. 1 active team rule
   now. Pushed to origin/main."

## Outputs

A short summary to the user containing:

- Rule id and short trigger
- Team id
- Whether dedup matched (and skipped) or copied fresh
- Whether git push succeeded, failed, or was skipped (no remote)
- The exact ledger line appended

## What this skill must NOT do

- Do not modify the personal `.teamagent/rules/active/` source files. The
  personal rule stays where it is; publishing is a copy-up operation.
- Do not auto-resolve conflicts. If trigger matches with a different `correct`,
  hand off to `resolve-rule-conflict`.
- Do not run `git push --force`. Ever.
- Do not write outside `.teamagent/team/<team-id>/` and the ledger.
