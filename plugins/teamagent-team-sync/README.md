# teamagent-team-sync

Promote a PERSONAL Claude-Code rule card into a TEAM-wide pack, sync the
pack on SessionStart, and resolve conflicts when two engineers corrected the
same mistake differently.

This is the team-distribution layer on top of the sibling wedge plugin
`teamagent-memory`. Alice corrects Claude once. `teamagent-memory` captures
it for Alice. Alice runs `publish-team-rule` from this plugin. On next
SessionStart, Bob and Charlie pull the rule automatically and their Claude
Code is also blocked from repeating the mistake.

## What this plugin does

1. Reads personal active rule cards written by `teamagent-memory` at
   `.teamagent/rules/active/*.json`.
2. Provides skills to promote those rules into a team pack at
   `.teamagent/team/<team-id>/rules/active/`.
3. Maintains an append-only audit log at
   `.teamagent/team/<team-id>/promotions.jsonl`.
4. On SessionStart, optionally `git pull` the team pack from a configured
   remote so every teammate's session starts with the latest rules.
5. Detects and resolves conflicts where two team members corrected the same
   trigger with different `correct` values.
6. Decides whether a rule is global-to-the-team or scoped to one repo.

## Personal vs Team rule layout

```
.teamagent/
  rules/
    pending/         # owned by teamagent-memory (drafts before review)
    active/          # owned by teamagent-memory (this engineer's personal rules)
  team/
    config.json      # team_id + optional git remote
    <team-id>/
      manifest.json
      promotions.jsonl
      rules/
        active/
          global/                # apply to every repo
          projects/<repo-name>/  # apply only to this repo
        archived/                # losers from resolve-rule-conflict
```

The personal `rules/` tree is read-only from this plugin's point of view.
We only copy UP from personal to team. We never edit personal cards.

## Configuring a team

Create `.teamagent/team/config.json`:

```json
{
  "team_id": "renlab-core",
  "remote": "git@github.com:libz-renlab-ai/teamagent-rules.git",
  "default_branch": "main"
}
```

- `team_id` is required. It namespaces the pack directory.
- `remote` is optional. If set, the team pack directory is treated as a git
  checkout and the SessionStart hook will `git pull --ff-only` it.
- `default_branch` defaults to `main`.

If `remote` is omitted, the plugin still works — it just stays local. You
can put `.teamagent/team/<team-id>/` on a shared filesystem mount instead of
a git remote.

## How SessionStart sync works

On every SessionStart, `hooks/sessionstart-sync.cjs` runs:

1. Reads `.teamagent/team/config.json` in cwd. If missing, silently exits.
2. If `remote` is set:
   - If the team dir is not yet a git checkout, best-effort clones it.
   - Otherwise runs `git fetch --quiet && git pull --ff-only --quiet`.
3. Counts active team rules and injects an `additionalContext` blob:

   ```
   [teamagent-team-sync] team_id=renlab-core active_team_rules=7 sync=fast-forwarded
   ```

The hook NEVER blocks the session. Network failures, missing config, dirty
working trees — all are swallowed and the session still starts.

The `userprompt-publish.cjs` hook watches for publish-intent phrases and
nudges Claude to invoke the `publish-team-rule` skill. It does not publish
autonomously.

## Conflict resolution semantics

`resolve-rule-conflict` is the gate that handles divergent corrections.
Default policy is `highest-confidence-wins`, with `latest-wins` as the
tie-breaker. Other policies:

- `manual` — user names the winner.
- `multi-suggest` — keep all competitors and rewrite their `correct` field
  into a comma-separated suggestion so PreToolUse warns instead of blocking.

Losers are MOVED (not deleted) to
`.teamagent/team/<team-id>/rules/archived/` with a sidecar
`<rule-id>.archive.json` recording why and when.

## Verifying with claudefast

The local convention here is to run the plugin under `claudefast` for
audit-style verification.

```bash
# Smoke-check that Claude Code sees the plugin manifest:
claudefast --plugin-dir plugins/teamagent-team-sync -p "list plugins"

# Drive a publish flow (assumes a personal rule already exists under
# .teamagent/rules/active/):
claudefast --plugin-dir plugins/teamagent-team-sync streamjson -p "publish this rule to the team"

# Drive conflict resolution after two divergent rules have landed:
claudefast --plugin-dir plugins/teamagent-team-sync streamjson -p "resolve the conflict on npm install moment"
```

Read the streamjson output to verify the skill fired and that the
appropriate files under `.teamagent/team/<team-id>/` were touched.
