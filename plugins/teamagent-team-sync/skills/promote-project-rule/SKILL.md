---
name: promote-project-rule
description: Decide whether a rule that originated inside ONE repo should be promoted as project-local in the team pack (only this repo) or as a global team rule (every repo your team owns). Use when the user says "promote this rule", "scope this team-wide", "make this global", "project-local rule", "is this repo-only or org-wide", or right after publish-team-rule when the rule looks repo-specific. The flow is: read the candidate rule -> classify scope -> place under rules/active/global or rules/active/projects/<repo>/ -> refresh manifest -> ledger entry.
---

# promote-project-rule

## When to use

Not every personal correction generalizes. A rule like "don't `cargo run` inside
`apps/web` -- use `pnpm dev`" makes sense only in one repo. A rule like
"don't `npm install moment` -- use dayjs" applies everywhere your team writes
JS. This skill is the gate that decides where a rule lives inside the team
pack.

Trigger phrases:

- "promote this rule"
- "scope this team-wide" / "make this global"
- "project-local rule"
- "is this repo-only or org-wide"
- Called from `publish-team-rule` when the candidate rule's `trigger` references
  a path that is clearly repo-relative (e.g. begins with `./apps/`,
  `packages/`, or a repo-specific binary name).

## Inputs

- Candidate rule JSON, either:
  - the newest under `.teamagent/rules/active/`, or
  - a rule already copied to `.teamagent/team/<team-id>/rules/active/` that we
    want to re-scope.
- Team config: `.teamagent/team/config.json`
- Optional: current repo name (best-effort: `basename $(git rev-parse --show-toplevel)`).

## Scope layout

Inside the team pack, rules live in one of two places:

```
.teamagent/team/<team-id>/rules/active/global/<rule-id>.json
.teamagent/team/<team-id>/rules/active/projects/<repo-name>/<rule-id>.json
```

`global/` rules are loaded by every Claude Code session that has this team
configured. `projects/<repo-name>/` rules are only loaded when the current
working directory's repo name matches.

## Classification heuristics

Treat a rule as **project-local** if ANY of:

- `trigger` contains a relative path starting with `./` or matches a known
  monorepo path token (`apps/`, `packages/`, `services/`).
- `trigger` references a binary or script that exists in this repo's
  `package.json scripts` or `Makefile` but is not a globally installed tool.
- `why` explicitly says "in this repo" / "for THIS service" / mentions the
  repo name.
- The user, when asked, says "just this repo".

Treat as **global** if:

- `trigger` is an ecosystem-level command (e.g. `npm install <pkg>`,
  `pip install <pkg>`, `cargo add <pkg>`, `gh pr create --base master`).
- `why` mentions an org-wide convention or a deprecated library.
- The user says "team-wide".

When in doubt, ASK the user which scope. Do not silently global-ize a
repo-specific rule (it would spam every other repo's PreToolUse).

## Workflow

1. **Load candidate.** Find the candidate rule JSON.
2. **Classify.** Apply the heuristics above. Produce a recommendation (`global`
   or `projects/<repo-name>`) plus a 1-sentence rationale.
3. **Confirm.** Present the recommendation to the user. Accept overrides.
4. **Place.** Move (or copy if originating from personal active) the rule
   into the chosen subdirectory of `.teamagent/team/<team-id>/rules/active/`.
   For project-local rules, the `<repo-name>` segment is the result of
   `basename $(git rev-parse --show-toplevel)` of the current cwd. Sanitize
   to `[a-z0-9._-]`.
5. **Refresh manifest.** `manifest.json` should include two arrays:
   `global_rule_ids` and `project_rule_ids` (the latter keyed by repo name).
6. **Append to ledger.** One JSON line in `promotions.jsonl`:

   ```json
   {"ts":"...","event":"scope-decided","rule_id":"...","scope":"global"}
   ```

   or

   ```json
   {"ts":"...","event":"scope-decided","rule_id":"...","scope":"projects/<repo>"}
   ```

7. **Git** (if remote configured) — stage, commit with
   `scope(rule): <rule-id> -> <scope>`, push.
8. **Summarize** the decision.

## Worked example A (global)

Candidate: `npm install moment` -> `dayjs`. Heuristic match: `npm install` is
an ecosystem-level command and `why` cites a team-wide deprecation. Scope =
`global`. Place at
`.teamagent/team/renlab-core/rules/active/global/rule_..._a1b2c3.json`.

## Worked example B (project-local)

Candidate: `cargo run --bin worker` inside repo `metrixMarkets`. Heuristic
match: `worker` only exists in this repo. Scope =
`projects/metrixmarkets`. Place at
`.teamagent/team/renlab-core/rules/active/projects/metrixmarkets/rule_..._99ab.json`.

## What this skill must NOT do

- Do not place a rule in BOTH `global/` and `projects/<repo>/`. Pick one.
- Do not modify the rule body (`trigger`, `wrong`, `correct`, `why`).
- Do not silently change the scope of an existing rule without a ledger entry.
