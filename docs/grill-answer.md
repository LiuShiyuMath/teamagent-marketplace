# Office-Hours Grill: TeamBrain / TeamAgent

Style: Garry Tan office-hours. No headings of praise. No "great project". Sharp judgments,
kill/keep/demote calls, with a concrete CEO proof loop and acceptance criteria.

---

## 0. The one sentence

You do not have a memory-and-collaboration platform. You have **one** loop worth shipping:
*"Previous Claude Code made this mistake. New Claude Code tried to repeat it. TeamAgent
blocked it."* Everything that does not directly serve that sentence is **demote** or **kill**.

---

## 1. The wedge (kill / keep / demote)

**Keep** — the narrowest believable first product is `teamagent-memory`: a Stop hook that
captures a user correction, writes a rule card, and a PreToolUse hook that blocks a new
Claude Code session from repeating it. That is the wedge. One core loop. One plugin. The
marketplace is justified by exactly this loop, not by being a marketplace.

**Demote**:
- Realtime "boss dashboard" — not a wedge. Adoption blocker; see security.
- Video upload as a feature — a proof artifact, not the product. Do not pitch it as a
  feature.
- Team analytics ("we caught N mistakes this quarter") — only after the first 10
  rule-cards exist. Right now there is no denominator.
- A general "AI memory" pitch — not specific. The status quo memory wins on price.

**Kill**:
- Selling a "platform for AI collaboration". You have **no** validated demand for a
  platform. You have at best a believable demand for one Claude Code rule that does
  not repeat itself across sessions.
- The "three-equal-pillars" framing. There is one wedge, two service plugins.
- Any plan that ships the marketplace before the first plugin actually prevents a repeat
  mistake on someone else's machine.

**Headline rule:** the marketplace must start with memory/enforcement, not a full
platform. Old Claude mistake should not repeat in a new Claude session. An
auto-captured team rule must be enforced before tool use. Anything else is a roadmap
item, not a v0.

---

## 2. Demand reality (the brutal questions)

You must answer, in writing, before the next demo:

1. **How many repeated AI mistakes happened this week** in your own repo? In a friend's
   repo? Show me the ledger. Without a counter, you cannot price this; without pricing,
   you cannot defend trust.
2. **Would an eng lead install this in a real repo today** without you on the call? If
   no, that is the gap, not the marketplace.
3. **What workaround are they already using** (see status quo below). Your install
   adoption curve is dominated by switching cost from that workaround — not from "no
   solution exists".
4. **Willingness to pay** for blocked repeats: behavior to look for is people manually
   typing the same correction into CLAUDE.md the second or third time. That moment is
   the wedge of demand.

Anti-pattern to avoid: do not assume the entire ecosystem of engineering organizations
needs this. They do not. The buyer is specific. See ICP.

---

## 3. Status quo (the real competition)

You are not competing with other AI memory startups. You are competing with the
workarounds an engineer already uses today, all of which are free and already trusted:

- **CLAUDE.md** — the file every Claude Code user already maintains. Lossy, copy-paste,
  not enforced at tool time, but **owned and visible**.
- **Team docs** in Notion / Confluence / a `docs/` folder.
- **PR review checklists** — senior engineer pastes the same comment 4 times until it
  sticks.
- **Senior engineer corrections in Slack / Notion conventions** — the human memory of
  the team lead. Slow but trusted.
- **Copy-pasted prompts and ad-hoc human memory** that gets re-learned every onboarding.

Why they fail (the only reason your wedge matters):
- CLAUDE.md is not enforced before a tool call runs, so a fresh agent still runs
  `npm install moment` before reading the warning.
- The corrections sit in human memory and Slack threads; they do not propagate to a
  new Claude Code session on a teammate's laptop.

**Switching event** that triggers adoption: the third time the same Claude Code session
makes the same mistake an engineer has already corrected in CLAUDE.md.

---

## 4. ICP specificity (no broad "every-engineer" pitch)

The narrow buyer profile:

- **Role**: eng lead or senior IC who already runs Claude Code daily.
- **Team type**: 10–50 person AI-heavy startup, mixed seniority, ships fast, reviews
  PRs in GitHub.
- **Trigger**: onboarding a new engineer or a new agent, or the third time the same
  convention violation lands in a PR.
- **Adoption blocker**: hook install touches `.claude/`, the eng lead must trust the
  plugin enough to leave hooks on for their team. Privacy + uninstall path matters more
  than features here.
- **Buyer vs user**: same person in early adoption — the eng lead both installs and
  reviews the rules. Do not pretend a non-coder CEO is the buyer; the CEO is the
  audience for proof, not the buyer.

---

## 5. CEO proof-of-work loop (this is non-negotiable)

A CEO who does not code must read **one HTML/page artifact** in 30 seconds and conclude
"this saved me from a repeat mistake". Define the loop completely:

1. **Transcript before** — Alice asks Claude Code to install `moment`.
2. **Correction event** — User: "no, use dayjs". Captured by Stop hook from the
   transcript.
3. **Rule card** — `{ trigger: "moment", wrong: "npm install moment",
   correct: "use dayjs", why: "...", confidence: 1 }` written to `.teamagent/rules/`.
4. **Next session, repeat attempt** — Bob, on his laptop, the next day, asks Claude
   Code to install `moment`.
5. **PreToolUse block** — hook event fires before bash runs. Tool call decision =
   `block`. Reason cites rule id.
6. **Before/after diff** — would-have-been action (`npm install moment`) vs actual
   blocked result. The CEO sees both columns.
7. **CEO summary** — one paragraph, no jargon. Three concrete numbers: blocks this
   week, distinct sessions saved, hook events logged.
8. **Saved-time estimate** — minutes per blocked repeat × N repeats. Conservative.

Each step is an evidence artifact stored under `.teamagent/proof/<run>/`. Activity does
NOT equal proof. A dashboard with lots of activity but no prevented-repeat is failure.

---

## 6. Shipped vs vision honesty (the most important section)

Right now, the honest labels are:

- **Shipped** (validated end-to-end): nothing yet. Today there are three plugin
  scaffolds and a marketplace manifest in this repo. Treat them as preship.
- **Preship** (built but not battle-tested on a real teammate's machine):
  `teamagent-memory` Stop capture, PreToolUse block, rule card writer. Local-only.
- **Prototype** (skeleton only, not validated): `teamagent-team-sync` git-remote sync;
  `teamagent-proof-console` HTML CEO summary.
- **Roadmap** (do not promise): boss dashboard, video recording UI, team analytics,
  pricing tiers, browser extension, IDE integration.
- **Unknown** (do not claim until measured): adoption rate, retention, willingness to
  pay, conflict-frequency between teammates.

Do not overclaim. Do not sell the realtime boss dashboard as shipped unless it is. Do
not sell the video as proof unless a CEO actually watched one and gave a verdict. The
fastest way to lose this market is to put the dashboard at the top of the landing page.

---

## 7. Marketplace / skill packaging (narrow, narrow, narrow)

The right v0 package is exactly one plugin: `teamagent-memory`. Folder shape, following
the official marketplace convention:

```
plugins/teamagent-memory/
  .claude-plugin/plugin.json
  skills/
    capture-correction/SKILL.md
    explain-rule-hit/SKILL.md
    review-new-rules/SKILL.md
  hooks/
    hooks.json
    pretooluse-enforce.cjs
    stop-capture.cjs
    userprompt-inject.cjs
  bin/teamagent
  README.md
```

Use `SKILL.md` with frontmatter, `scripts/` for executables, `references/` for context,
`assets/` for templates. `hooks/` and `commands/` only when needed. Do not package every
feature into a single mega-plugin. The first package must prove one core loop end to
end. The `teamagent-memory` plugin is the v0 package by itself.

The other two plugins (`teamagent-proof-console`, `teamagent-team-sync`) ship in the
same marketplace as **siblings**, not as a unified "TeamBrain Platform". They are
useful, but the marketplace's reason-to-exist is the memory/enforcement wedge. Without
the wedge the other two are decoration.

---

## 8. Security / trust (this is the adoption blocker, not a footnote)

You cannot hand a stranger a `curl | bash` and expect a 10-person startup to install
hooks into their devs' Claude Code. Treat trust as a feature with proof artifacts.

Specifically, the README must answer:

- **What files does the hook read?** Just the transcript path Claude Code gives it,
  plus `.teamagent/rules/active/*.json`. Nothing else.
- **What data leaves the machine?** Default: nothing. Team sync is opt-in via an
  explicit `remote` setting; without it everything stays local.
- **What hook permissions?** PreToolUse (can block), Stop (read-only over transcript),
  UserPromptSubmit (inject context only). No PostToolUse upload.
- **How do I disable / uninstall?** `claude plugin disable teamagent-memory`; remove
  the hooks block. Acceptance criteria: a one-line uninstall that restores prior
  behavior in <5 seconds.
- **Boss visibility creates privacy risk.** A "dashboard for the boss" creates a
  surveillance dynamic that kills adoption. Make boss visibility opt-in, scoped to a
  single repo, and visible to the engineer.
- **Video proof of work** is for the CEO viewing the demo, not for surveillance of
  engineers. Do not ship a video uploader that runs on engineer machines.

Without these answers, install rate goes to zero among the people you actually need.

---

## 9. Actionability (next 48 hours and 2 weeks, with acceptance criteria)

**Next 48 hours — deliverables**:

1. **Run 5 user installs without explanation.** Watch them try to use it cold. Do not
   prompt. Acceptance criteria: 3 of 5 reach the first PreToolUse block within 10 min,
   or you have a UX bug to fix tonight.
2. **Collect 10 repeated-mistake ledger entries** from your own logs and two friends'
   repos. Acceptance criteria: 10 distinct triggers, real diffs, dates. This is your
   demand evidence.
3. **Build `demo/01-before.md` through `demo/06-ceo-summary.md`** — 6 files, one per
   step of the proof loop. Acceptance criteria: a non-coder can read all six in 5
   minutes and explain the loop back to you.

**Next 2 weeks — must do, must not do**:

- **Must** ship `teamagent-memory` as the first plugin with PreToolUse block working
  on `moment->dayjs` end to end.
- **Must** write an explicit uninstall command and verify it on a clean machine.
- **Must** label every roadmap item as such on the landing page.
- **Do not** build the boss dashboard. Do not build the video uploader. Do not pitch
  three plugins to your first 10 users.
- **Must** measure: blocks per week, distinct sessions, distinct triggers, false
  positives.

---

## 10. Sharpness (the punchlines, restated)

- **Kill** the platform pitch.
- **Demote** the dashboard, the video, the analytics.
- **Keep** memory/enforcement as the wedge.
- **Promote** trust artifacts (uninstall, privacy, hook scope) to the same prominence
  as the demo.
- **Red flag:** if your first 10 installs include zero PreToolUse blocks of a real
  repeat mistake, the wedge is wrong or the rule capture is too noisy. Cut features
  until the block fires.
- **Biggest problem right now:** this is not a feature problem; it is a proof problem.
  You do not lack capabilities. You lack a 6-step CEO-readable artifact that proves
  the loop saved time.
- **Do not** pitch three products. Pitch one prevented mistake.

---

## Best line you should keep

> "Activity does not equal proof. The CEO must see a prevented repeat, not a busy
> dashboard."

That is the one sentence to put above the install button.
