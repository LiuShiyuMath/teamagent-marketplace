#!/usr/bin/env node
// SAFETY: read-only injector. Reads the user prompt from stdin, scans active
// rule cards under .teamagent/rules/active/ (project) and ~/.teamagent/rules/active/
// (user fallback), and if any rule's trigger appears in the prompt, emits a
// hookSpecificOutput with additionalContext telling Claude about the team rule.
// Never writes files, never opens sockets.

'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

function readStdinSync() {
  try { return fs.readFileSync(0, 'utf8'); } catch (_) { return ''; }
}
function safeJsonParse(s, fallback) {
  try { return JSON.parse(s); } catch (_) { return fallback; }
}

function loadRules() {
  const dirs = [
    path.join(process.cwd(), '.teamagent', 'rules', 'active'),
    path.join(os.homedir(), '.teamagent', 'rules', 'active'),
  ];
  const out = [];
  for (const dir of dirs) {
    let entries = [];
    try { entries = fs.readdirSync(dir); } catch (_) { continue; }
    for (const f of entries) {
      if (!f.endsWith('.json')) continue;
      try {
        const r = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
        if (r && typeof r.trigger === 'string') out.push(r);
      } catch (_) {}
    }
  }
  return out;
}

function main() {
  const payload = safeJsonParse(readStdinSync(), {});
  const prompt = String(payload.prompt || payload.user_prompt || '').toLowerCase();
  if (!prompt) process.exit(0);

  const hits = [];
  for (const r of loadRules()) {
    const trig = String(r.trigger).toLowerCase();
    if (trig && prompt.indexOf(trig) !== -1) hits.push(r);
  }
  if (!hits.length) process.exit(0);

  const lines = hits.map(r =>
    `Heads-up: team rule ${r.id} says '${r.wrong}' -> '${r.correct}'. Reason: ${r.why}.`
  );
  const additionalContext = `<system-reminder>\n${lines.join('\n')}\n</system-reminder>`;

  const out = {
    hookSpecificOutput: {
      hookEventName: 'UserPromptSubmit',
      additionalContext,
    },
  };
  process.stdout.write(JSON.stringify(out) + '\n');
  process.exit(0);
}

try { main(); } catch (_) { process.exit(0); }
