#!/usr/bin/env node
// SAFETY: this hook is strictly READ-ONLY. It loads rule cards from disk,
// inspects the proposed tool_input, and emits a JSON decision on stdout.
// It never writes files, never spawns processes, never makes network calls.
// Any unexpected error path exits 0 with empty stdout so Claude Code proceeds.

'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

function readStdinSync() {
  try {
    return fs.readFileSync(0, 'utf8');
  } catch (_) {
    return '';
  }
}

function safeJsonParse(s, fallback) {
  try { return JSON.parse(s); } catch (_) { return fallback; }
}

function listRuleFiles() {
  const candidates = [];
  const projectDir = path.join(process.cwd(), '.teamagent', 'rules', 'active');
  const homeDir = path.join(os.homedir(), '.teamagent', 'rules', 'active');
  for (const dir of [projectDir, homeDir]) {
    try {
      const entries = fs.readdirSync(dir);
      for (const f of entries) {
        if (f.endsWith('.json')) candidates.push(path.join(dir, f));
      }
    } catch (_) { /* dir missing is fine */ }
  }
  return candidates;
}

function loadRules() {
  const out = [];
  for (const p of listRuleFiles()) {
    try {
      const raw = fs.readFileSync(p, 'utf8');
      const rule = JSON.parse(raw);
      if (rule && typeof rule.trigger === 'string' && rule.trigger.length > 0) {
        out.push(rule);
      }
    } catch (_) { /* skip malformed */ }
  }
  return out;
}

function haystackForToolInput(toolName, input) {
  if (!input || typeof input !== 'object') return '';
  if (toolName === 'Bash') return String(input.command || '');
  if (toolName === 'Edit' || toolName === 'Write' || toolName === 'MultiEdit') {
    const parts = [];
    if (input.file_path) parts.push(String(input.file_path));
    if (input.content) parts.push(String(input.content));
    if (input.new_string) parts.push(String(input.new_string));
    if (input.old_string) parts.push(String(input.old_string));
    if (Array.isArray(input.edits)) {
      for (const e of input.edits) {
        if (e && e.new_string) parts.push(String(e.new_string));
        if (e && e.old_string) parts.push(String(e.old_string));
      }
    }
    return parts.join('\n');
  }
  return '';
}

function main() {
  const payload = safeJsonParse(readStdinSync(), {});
  const toolName = payload.tool_name || (payload.tool && payload.tool.name) || '';
  const toolInput = payload.tool_input || (payload.tool && payload.tool.input) || {};
  const haystack = haystackForToolInput(toolName, toolInput).toLowerCase();
  if (!haystack) { process.exit(0); }

  const rules = loadRules();
  for (const r of rules) {
    const needle = String(r.trigger).toLowerCase();
    if (needle && haystack.indexOf(needle) !== -1) {
      const reason = `TeamAgent rule ${r.id}: prev Claude tried '${r.wrong}'; team rule says '${r.correct}'. Why: ${r.why}`;
      process.stdout.write(JSON.stringify({ decision: 'block', reason }) + '\n');
      process.exit(0);
    }
  }
  process.exit(0);
}

try { main(); } catch (_) { process.exit(0); }
