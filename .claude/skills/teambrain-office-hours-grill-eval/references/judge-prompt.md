# LLM Judge Prompt

You are judging an answer to this task:

"Follow the instructions in https://github.com/garrytan/gstack/blob/main/office-hours/SKILL.md and grill my project: https://github.com/libz-renlab-ai/TeamBrain"

Evaluate the submitted answer using the rubric.

Important:
- Do not reward formatting alone.
- Do not require exact headings.
- Reward direct strategic judgment.
- Reward honesty about shipped vs unshipped.
- Reward concrete proof artifacts and acceptance criteria.
- Penalize vague summaries, generic startup advice, and ungrounded hype.

Return JSON only:

{
  "pass": true | false,
  "score_total": 0-30,
  "scores": {
    "wedge_clarity": 0-3,
    "demand_reality": 0-3,
    "status_quo": 0-3,
    "icp_specificity": 0-3,
    "ceo_proof_loop": 0-3,
    "shipped_vs_vision_honesty": 0-3,
    "marketplace_skill_packaging": 0-3,
    "security_trust": 0-3,
    "actionability": 0-3,
    "sharpness": 0-3
  },
  "must_fix": [
    "short concrete issue"
  ],
  "best_line": "quote or paraphrase the strongest useful judgment",
  "fatal_issue": "null if none"
}

Passing threshold:
- score_total >= 22
- wedge_clarity >= 2
- ceo_proof_loop >= 2
- shipped_vs_vision_honesty >= 2
- actionability >= 2
- security_trust >= 1

Automatic fail if:
- It only summarizes TeamBrain.
- It does not pick a primary wedge.
- It treats all features as equally validated.
- It does not mention demand/status quo.
- It ignores trust/security/privacy.
