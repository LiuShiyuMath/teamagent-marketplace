#!/usr/bin/env node
// sessionstart-sync.cjs
//
// Fired on SessionStart. Reads .teamagent/team/config.json from the current
// working directory. If a git remote is configured for the team pack,
// runs `git fetch && git pull --ff-only` inside the team pack directory so
// that the session starts with the latest team rules already on disk.
//
// Then counts active team rules and emits an additionalContext blob telling
// Claude how many team rules are active and which team-id is in effect.
//
// Hard rules:
//   - Never crash the session. All errors are swallowed.
//   - Never block. We always exit 0.
//   - Pure Node stdlib. No external deps.

'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

function safeReadJson(p) {
  try {
    const raw = fs.readFileSync(p, 'utf8');
    return JSON.parse(raw);
  } catch (_e) {
    return null;
  }
}

function listActiveRules(teamDir) {
  const rulesDir = path.join(teamDir, 'rules', 'active');
  try {
    const entries = fs.readdirSync(rulesDir);
    return entries.filter((f) => f.endsWith('.json'));
  } catch (_e) {
    return [];
  }
}

function gitSyncIfPossible(teamDir, remote, branch) {
  if (!remote) return { synced: false, reason: 'no-remote-configured' };

  // The team dir should already be a checkout of `remote`. If not, we
  // do a best-effort clone. If clone fails, swallow.
  const gitDir = path.join(teamDir, '.git');
  try {
    if (!fs.existsSync(gitDir)) {
      // Best-effort initial clone into teamDir. teamDir may or may not exist.
      fs.mkdirSync(teamDir, { recursive: true });
      execSync(`git clone --quiet --branch ${branch} ${JSON.stringify(remote)} ${JSON.stringify(teamDir)}`, {
        stdio: 'ignore',
        timeout: 12000,
      });
      return { synced: true, reason: 'cloned' };
    }
    execSync('git fetch --quiet', { cwd: teamDir, stdio: 'ignore', timeout: 8000 });
    execSync('git pull --ff-only --quiet', { cwd: teamDir, stdio: 'ignore', timeout: 8000 });
    return { synced: true, reason: 'fast-forwarded' };
  } catch (_e) {
    return { synced: false, reason: 'git-error-swallowed' };
  }
}

function main() {
  const cwd = process.cwd();
  const cfgPath = path.join(cwd, '.teamagent', 'team', 'config.json');
  const cfg = safeReadJson(cfgPath);

  if (!cfg || !cfg.team_id) {
    // No team configured for this repo. Stay silent.
    process.stdout.write('');
    process.exit(0);
  }

  const teamDir = path.join(cwd, '.teamagent', 'team', String(cfg.team_id));
  const branch = cfg.default_branch || 'main';
  const syncResult = gitSyncIfPossible(teamDir, cfg.remote, branch);
  const rules = listActiveRules(teamDir);

  const lines = [
    `[teamagent-team-sync] team_id=${cfg.team_id} active_team_rules=${rules.length} sync=${syncResult.reason}`,
  ];
  if (rules.length > 0) {
    lines.push(`Active team rules currently on disk under .teamagent/team/${cfg.team_id}/rules/active/.`);
    lines.push('Treat these as authoritative team conventions; PreToolUse hooks in teamagent-memory enforce them.');
  } else {
    lines.push('No active team rules yet. Personal rules from teamagent-memory can be promoted via the publish-team-rule skill.');
  }

  const payload = {
    hookSpecificOutput: {
      hookEventName: 'SessionStart',
      additionalContext: lines.join('\n'),
    },
  };
  process.stdout.write(JSON.stringify(payload));
  process.exit(0);
}

try {
  main();
} catch (_e) {
  // Absolute last-resort: never let a hook crash a session.
  process.exit(0);
}
