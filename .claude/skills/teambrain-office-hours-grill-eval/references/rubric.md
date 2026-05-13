# Rubric: TeamBrain Office-Hours Grill

Score each dimension from 0 to 3.

## 1. Wedge clarity

0 = No wedge; just summarizes features.
1 = Mentions a wedge but keeps many equal priorities.
2 = Picks a main wedge and demotes weaker features.
3 = Picks a painfully narrow wedge and explains why everything else must serve it.

Strong signal:
- "Old Claude mistake should not repeat in a new Claude session."
- "Auto-captured team rule enforced before tool use."
- "Marketplace should start with memory/enforcement, not full platform."

Weak signal:
- "TeamBrain helps teams collaborate with AI."
- "Build dashboard, video, marketplace, analytics, plugins all together."

## 2. Demand reality

0 = No customer pain.
1 = Generic pain.
2 = Specific pain with plausible user behavior.
3 = Ties pain to measurable time, money, review burden, adoption, or willingness to install/pay.

Strong signal:
- "How many repeated AI mistakes happened this week?"
- "Would an eng lead install this in a real repo today?"
- "What workaround are they already using?"

## 3. Status quo

0 = No alternatives.
1 = Mentions competitors vaguely.
2 = Names current workaround.
3 = Explains why current workaround fails and what switching event triggers adoption.

Expected status quo:
- CLAUDE.md
- team docs
- review checklists
- senior engineer corrections
- Slack/Notion conventions
- copy-pasted prompts
- human memory

## 4. ICP specificity

0 = Everyone.
1 = Developers or teams broadly.
2 = Specific team type.
3 = Specific buyer/user with role, context, trigger, blocker.

Strong ICP:
- "Eng lead at 10–50 person AI-heavy startup using Claude Code daily."
- "Pain: repeated agent mistakes enter PR review."
- "Trigger: onboarding new engineers/agents or repeated convention violations."

## 5. CEO proof-of-work

0 = No proof loop.
1 = Mentions demos generally.
2 = Defines before/after evidence.
3 = Defines complete observable loop: mistake, correction, rule, enforcement, prevented repeat, evidence artifact.

Strong proof loop:
- Transcript before
- Correction event
- Rule card
- Next-session repeat attempt
- PreToolUse block
- CEO summary
- saved-time estimate

## 6. Shipped vs vision honesty

0 = Overclaims.
1 = Minor caveats.
2 = Labels uncertainty.
3 = Clearly separates shipped, preship, prototype, roadmap, and unknown.

Strong signal:
- "Do not sell realtime boss dashboard as shipped unless it is."
- "Video upload is proof artifact, not core product, unless validated."

## 7. Marketplace / skill packaging

0 = No packaging.
1 = Generic package mention.
2 = Gives plausible plugin/skill split.
3 = Gives narrow first plugin and explains why.

Strong signal:
- `teamagent-memory`
- `SKILL.md`
- `scripts/`
- `references/`
- `assets/`
- hooks / commands only when needed
- first package proves one core loop

## 8. Security / trust

0 = No trust discussion.
1 = Generic security line.
2 = Mentions install, hooks, local data, uploads, permissions.
3 = Turns trust into adoption requirement and proof artifact.

Strong signal:
- "What files are read?"
- "What leaves the machine?"
- "How to disable/uninstall?"
- "Boss visibility creates privacy risk."

## 9. Actionability

0 = No next steps.
1 = Generic advice.
2 = Concrete tasks.
3 = Concrete tasks with acceptance criteria.

Strong signal:
- "Run 5 user installs without explanation."
- "Collect 10 repeated mistake ledger entries."
- "Build demo/01-before.md through demo/06-ceo-summary.md."

## 10. Sharpness

0 = Bland.
1 = Mild critique.
2 = Makes clear judgments.
3 = Forces strategic tradeoffs.

Strong signal:
- "Kill / keep / demote."
- "This is not a feature problem; it is a proof problem."
- "Do not pitch three products."
