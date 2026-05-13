#!/usr/bin/env node
// userprompt-publish.cjs
//
// Fired on UserPromptSubmit. When the user expresses intent to publish a
// personal rule to the team pack ("publish this rule", "promote to team",
// "make this team-wide", "/team publish", etc.) we INJECT a suggestion via
// additionalContext that tells Claude to invoke the publish-team-rule skill
// on the most recently captured rule card.
//
// We DO NOT autonomously publish. The skill is what does the work. This
// hook is purely a routing nudge so the right skill fires without a
// permission prompt loop.

'use strict';

const PUBLISH_PATTERNS = [
  /\bpublish (this|that|the) rule\b/i,
  /\bpromote (this|that|the)?\s*rule\s*to\s*(the\s*)?team\b/i,
  /\bpromote to team\b/i,
  /\bshare (this|that|it) with the team\b/i,
  /\bmake (this|that|it) team[-\s]?wide\b/i,
  /\bteam[-\s]?rule this\b/i,
  /^\s*\/team[-\s]?publish\b/i,
  /\bpush (this|that|the) rule to the team\b/i,
];

function readInput() {
  try {
    const raw = require('fs').readFileSync(0, 'utf8');
    if (!raw) return {};
    return JSON.parse(raw);
  } catch (_e) {
    return {};
  }
}

function main() {
  const input = readInput();
  const prompt = String(input.prompt || input.user_prompt || '');
  if (!prompt) {
    process.exit(0);
  }

  const matched = PUBLISH_PATTERNS.some((re) => re.test(prompt));
  if (!matched) {
    process.exit(0);
  }

  const guidance = [
    '[teamagent-team-sync] User expressed intent to publish a personal rule to the team pack.',
    'Invoke the `publish-team-rule` skill from this plugin on the most recent rule card in',
    '.teamagent/rules/active/ (the personal active dir written by teamagent-memory).',
    'The skill will validate, deduplicate, copy into the team pack, append to promotions.jsonl,',
    'and git-commit+push if a remote is configured. Do not bypass the skill.',
  ].join('\n');

  const payload = {
    hookSpecificOutput: {
      hookEventName: 'UserPromptSubmit',
      additionalContext: guidance,
    },
  };
  process.stdout.write(JSON.stringify(payload));
  process.exit(0);
}

try {
  main();
} catch (_e) {
  process.exit(0);
}
