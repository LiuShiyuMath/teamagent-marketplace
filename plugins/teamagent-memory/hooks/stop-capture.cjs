#!/usr/bin/env node
// PRIVACY: this hook reads the local Claude Code transcript file (path given by
// Claude Code itself), scans only the last ~30 messages for explicit user
// corrections, and writes ONE small JSON rule card under
// `.teamagent/rules/pending/`. It never writes content elsewhere, never opens
// network sockets, and never copies transcript text outside the local project.
// On any error it exits 0 silently so the Stop hook never blocks the session.

'use strict';

const fs = require('fs');
const path = require('path');

function readStdinSync() {
  try { return fs.readFileSync(0, 'utf8'); } catch (_) { return ''; }
}
function safeJsonParse(s, fallback) {
  try { return JSON.parse(s); } catch (_) { return fallback; }
}

function readTranscriptTail(transcriptPath, maxLines) {
  try {
    const raw = fs.readFileSync(transcriptPath, 'utf8');
    const lines = raw.split('\n').filter(Boolean);
    return lines.slice(-maxLines).map(l => safeJsonParse(l, null)).filter(Boolean);
  } catch (_) { return []; }
}

function extractText(content) {
  if (typeof content === 'string') return content;
  if (!Array.isArray(content)) return '';
  const parts = [];
  for (const c of content) {
    if (!c) continue;
    if (typeof c === 'string') { parts.push(c); continue; }
    if (c.type === 'text' && c.text) parts.push(c.text);
  }
  return parts.join('\n');
}

function extractToolUseTerms(content) {
  if (!Array.isArray(content)) return [];
  const terms = [];
  for (const c of content) {
    if (c && c.type === 'tool_use' && c.input) {
      if (c.input.command) terms.push(String(c.input.command));
      if (c.input.file_path) terms.push(String(c.input.file_path));
      if (c.input.content) terms.push(String(c.input.content).slice(0, 400));
      if (c.input.new_string) terms.push(String(c.input.new_string).slice(0, 400));
    }
  }
  return terms;
}

const CORRECTION_PATTERNS = [
  /\buse\s+([A-Za-z0-9_\-./@]+)\s+instead\b/i,
  /\bdon'?t\s+use\s+([A-Za-z0-9_\-./@]+)/i,
  /\bstop\s+using\s+([A-Za-z0-9_\-./@]+)/i,
  /\bshould\s+be\s+([A-Za-z0-9_\-./@]+)/i,
  /\buse\s+([A-Za-z0-9_\-./@]+)\s+not\s+([A-Za-z0-9_\-./@]+)/i,
];
const NEGATION = /\b(no|nope|don'?t|stop)\b[,.! ]/i;

function findWrongFromTools(toolTerms) {
  for (const t of toolTerms) {
    const m = t.match(/\b([a-z][a-z0-9_\-]{1,40})\b/gi);
    if (m && m.length) {
      const stop = new Set(['npm','install','add','i','yarn','pnpm','run','the','use','to','from','with','for','and','sudo','bash','sh']);
      for (const tok of m) {
        const low = tok.toLowerCase();
        if (!stop.has(low) && low.length > 1) return low;
      }
    }
  }
  return null;
}

function slug(s) {
  return String(s).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40);
}

function ensureDir(p) {
  try { fs.mkdirSync(p, { recursive: true }); } catch (_) {}
}

function listRules(dir) {
  try { return fs.readdirSync(dir).filter(f => f.endsWith('.json')); } catch (_) { return []; }
}

function alreadyExists(rulesRoot, wrong, correct) {
  for (const sub of ['pending', 'active']) {
    const dir = path.join(rulesRoot, sub);
    for (const f of listRules(dir)) {
      try {
        const r = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
        if (r && String(r.wrong).toLowerCase() === wrong && String(r.correct).toLowerCase() === correct) {
          return path.join(dir, f);
        }
      } catch (_) {}
    }
  }
  return null;
}

function bumpConfidence(filePath) {
  try {
    const r = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    r.confidence = (typeof r.confidence === 'number' ? r.confidence : 1) + 1;
    fs.writeFileSync(filePath, JSON.stringify(r, null, 2));
  } catch (_) {}
}

function main() {
  const payload = safeJsonParse(readStdinSync(), {});
  const transcriptPath = payload.transcript_path || payload.transcriptPath;
  if (!transcriptPath) process.exit(0);

  const events = readTranscriptTail(transcriptPath, 30);
  if (!events.length) process.exit(0);

  const rulesRoot = path.join(process.cwd(), '.teamagent', 'rules');
  ensureDir(path.join(rulesRoot, 'pending'));
  ensureDir(path.join(rulesRoot, 'active'));

  for (let i = 0; i < events.length; i++) {
    const ev = events[i];
    const role = ev.role || (ev.message && ev.message.role);
    if (role !== 'user') continue;
    const content = ev.content || (ev.message && ev.message.content);
    const text = extractText(content);
    if (!text) continue;
    if (!NEGATION.test(text) && !/use\s+\S+\s+(instead|not)/i.test(text) && !/should be/i.test(text)) continue;

    let correct = null;
    for (const re of CORRECTION_PATTERNS) {
      const m = text.match(re);
      if (m && m[1]) { correct = m[1]; break; }
    }
    if (!correct) continue;

    let wrong = null;
    for (let j = i - 1; j >= 0 && j >= i - 4; j--) {
      const prev = events[j];
      const prevRole = prev.role || (prev.message && prev.message.role);
      if (prevRole !== 'assistant') continue;
      const prevContent = prev.content || (prev.message && prev.message.content);
      const terms = extractToolUseTerms(prevContent);
      wrong = findWrongFromTools(terms);
      if (wrong) break;
    }
    if (!wrong) continue;
    if (wrong.toLowerCase() === correct.toLowerCase()) continue;

    const wrongLow = wrong.toLowerCase();
    const correctLow = correct.toLowerCase();
    const existing = alreadyExists(rulesRoot, wrongLow, correctLow);
    if (existing) { bumpConfidence(existing); continue; }

    const id = `${Date.now()}-${slug(wrong)}-to-${slug(correct)}`;
    const card = {
      id,
      trigger: wrongLow,
      wrong: wrongLow,
      correct: correctLow,
      why: text.trim().slice(0, 200),
      confidence: 1,
      created_at: new Date().toISOString(),
      source: 'stop-capture',
    };
    try {
      const out = path.join(rulesRoot, 'pending', `${id}.json`);
      fs.writeFileSync(out, JSON.stringify(card, null, 2));
      process.stderr.write(`teamagent: captured rule ${id}\n`);
    } catch (_) {}
  }
  process.exit(0);
}

try { main(); } catch (_) { process.exit(0); }
