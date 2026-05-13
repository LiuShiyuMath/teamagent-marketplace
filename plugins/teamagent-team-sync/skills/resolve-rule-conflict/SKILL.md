---
name: resolve-rule-conflict
description: Detect and resolve conflicts where two or more teammates corrected the SAME trigger with DIVERGENT corrections inside the team pack (for example, Alice says moment->dayjs and Bob says moment->date-fns). Use when the user says "resolve conflict", "fix conflicting rules", "two rules disagree", "team rules diverge", "merge divergent correction", or right after publish-team-rule reports a trigger collision. The flow is: scan -> group by trigger -> flag divergent groups -> present resolution options (latest-wins, highest-confidence-wins, manual, multi-suggest) -> write winner + archive losers.
---

# resolve-rule-conflict

## When to use

Invoke this skill when there is evidence that two team rules target the same
`trigger` but disagree on `correct`. Common entry points:

- User says "resolve conflict" / "two rules disagree" / "merge divergent rules"
- `publish-team-rule` halted because it detected a trigger collision
- A teammate complains "PreToolUse is warning me about both dayjs and date-fns"

## Inputs

- Team config: `.teamagent/team/config.json` (read `team_id`)
- Active team rules: `.teamagent/team/<team-id>/rules/active/*.json`
- Archive destination: `.teamagent/team/<team-id>/rules/archived/`
- Promotions ledger: `.teamagent/team/<team-id>/promotions.jsonl` (for audit context only)

## Detection algorithm

1. Read every JSON in `rules/active/`.
2. Group them by exact `trigger` (case-insensitive, leading/trailing whitespace
   trimmed). A "conflict group" is any group of size > 1 whose members have
   more than one distinct value for `correct`.
3. If no conflict groups exist, report "no conflicts" and stop.
4. If conflict groups exist, present each group to the user with: trigger,
   list of competing corrections, each rule's captured_by, captured_at,
   confidence.

## Resolution options

Offer the user FOUR resolution policies. Default suggestion:
`highest-confidence-wins`, with `latest-wins` as a tie-breaker.

1. **latest-wins** — keep the rule with the most recent `captured_at`; archive
   the rest.
2. **highest-confidence-wins** — keep the rule with the highest `confidence`
   field; on tie, fall back to latest-wins.
3. **manual** — ask the user to point at the winning rule by id.
4. **multi-suggest** — keep ALL competing rules but rewrite each one's `correct`
   into a single comma-separated suggestion string (e.g. `dayjs OR date-fns`)
   so the PreToolUse hook in `teamagent-memory` warns "team is split between
   dayjs and date-fns; please pick one". Archive nothing. Use this when the
   team genuinely has two acceptable answers and wants a soft nudge rather
   than a hard block.

## Workflow

1. **Scan** -> build conflict groups.
2. **Surface** -> for each group, print a small table:

   ```
   trigger: npm install moment
     - rule_2026_05_12_a1b2c3  correct=dayjs       conf=3 by=alice@... at=2026-05-12T18:01Z
     - rule_2026_05_13_f4e5d6  correct=date-fns    conf=2 by=bob@...   at=2026-05-13T09:14Z
   ```

3. **Ask** which resolution policy to apply (default
   `highest-confidence-wins`). If the user is silent and the operating mode is
   automatic, apply the default.
4. **Compute winner(s) and losers**, per the chosen policy.
5. **Write winner** -> keep the winning JSON in
   `.teamagent/team/<team-id>/rules/active/` unchanged. If policy is
   `multi-suggest`, rewrite every rule in the group with the merged `correct`
   field (e.g. `"dayjs OR date-fns"`) and an added field
   `"merged_from": ["rule_id_a","rule_id_b"]`.
6. **Archive losers** -> move every loser file into
   `.teamagent/team/<team-id>/rules/archived/`. Preserve original filenames.
   Add a sidecar `<rule-id>.archive.json` next to it that records:

   ```json
   {
     "archived_at": "2026-05-13T10:42:00Z",
     "policy": "highest-confidence-wins",
     "winner_rule_id": "rule_2026_05_12_a1b2c3",
     "reason": "conflict-resolution"
   }
   ```

7. **Refresh manifest** -> regenerate `manifest.json` from whatever is left in
   `rules/active/`.
8. **Append to ledger** -> add a JSON line to `promotions.jsonl`:

   ```json
   {"ts":"2026-05-13T10:42:00Z","event":"conflict-resolved","trigger":"npm install moment","policy":"highest-confidence-wins","winner":"rule_2026_05_12_a1b2c3","losers":["rule_2026_05_13_f4e5d6"]}
   ```

9. **(Optional) Git** -> if `.teamagent/team/<team-id>/` has a git remote
   configured, stage the changes (active + archived + manifest + ledger),
   commit with `resolve(conflict): <trigger short>`, and push.
10. **Summarize** -> list trigger, policy chosen, winner id, archived ids,
    whether git push occurred.

## Default policy rationale

`highest-confidence-wins` is the default because `confidence` in a rule card
reflects how many times that pattern was re-affirmed during capture by the
sibling `teamagent-memory` plugin — a real signal that the team relies on the
winning correction more often. `latest-wins` is the tie-breaker because newer
corrections tend to reflect updated dependency landscapes (e.g. a library was
deprecated last week).

`multi-suggest` exists for cases where the team's answer is "both are fine".
Hard-archiving one would suppress legitimate flexibility.

## What this skill must NOT do

- Do not delete any rule file. Always archive.
- Do not modify rules outside the active conflict group.
- Do not edit the personal `.teamagent/rules/active/` (those are owned by
  `teamagent-memory`).
- Do not `git push --force`.
