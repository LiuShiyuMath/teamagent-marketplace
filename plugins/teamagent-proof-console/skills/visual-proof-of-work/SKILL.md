---
name: visual-proof-of-work
description: Generate a convincing, reproducible VISUAL PROOF-OF-WORK artifact for any terminal session — a scripted source file (.tape preferred, .cast or .yml as fallback), the rendered GIF, the canonical stdout/stderr text capture, the current git commit SHA, a manifest.json, and a one-page summary.html — so a reviewer (PR reviewer, CEO, auditor) can open ONE file and trust the terminal work actually happened. Use this skill whenever the user says "make a proof gif", "record this terminal session as proof", "visual proof of work", "demo gif", "/visual-proof", "record this command for the PR", "show that this works as a gif", "prove the CLI works", or otherwise wants a reproducible visual record of a terminal flow. Auto-detects the installed renderer (prefers VHS > asciinema+agg > Terminalizer) and degrades gracefully when only one is installed. Read-only over the demo target — only writes under .teamagent/proof/visual/.
---

# visual-proof-of-work

This skill builds one self-contained, reproducible **visual** proof-of-work bundle for a terminal flow. The audience is a reviewer who wants to *see* the work happen, not just read claims.

The mental model: a `.tape` file is to a terminal GIF what a Playwright spec is to a browser flow — a deterministic, version-controllable, CI-runnable script. The rendered GIF is the artifact; the source script is the proof that the artifact is reproducible.

## When to use

Invoke when the user says any of:

- "make a proof gif"
- "record this terminal session as proof"
- "visual proof of work"
- "demo gif"
- "/visual-proof"
- "I need a gif of this command for the PR"
- "show that this works as a gif"
- "prove the CLI works"

Do NOT use for:

- Static screenshots — just redirect to a file.
- Browser flows — use `/qa` or `/browse`.
- Pure text logs — just run the command and capture stdout.

## Inputs

Ask the user only for what you cannot infer:

1. **Demo commands** — the exact shell command sequence to record. Required.
2. **Slug** (optional) — kebab-case label for this proof. Default: derive from the first command's binary name.
3. **Tool preference** (optional) — `vhs` | `asciinema` | `terminalizer` | `auto` (default `auto`).

A path to a script file is acceptable shorthand for the demo commands.

## Step 1 — detect which renderer is available

Run the helper:

```bash
bash scripts/detect_tool.sh
```

It prints exactly one line, one of: `vhs`, `asciinema+agg`, `terminalizer`, or `none`.

Order of preference and why:

- **VHS** — official `.tape` DSL, deterministic output, the only one that genuinely scripts the terminal rather than recording a human at it. This is the path you want whenever it is available.
- **asciinema+agg** — `asciinema rec` produces a text-faithful `.cast` (JSON) of the *actual* terminal session; `agg` renders that cast to GIF. Less deterministic than VHS but extremely honest — what you see is what happened.
- **Terminalizer** — YAML-based, slower, fidelity is lower than the other two, but it works on machines where VHS's ttyd dep won't install. Last resort.
- **none** — refuse to produce a GIF. Tell the user what to install. Never fabricate a visual.

If the user explicitly asked for a tool that is not installed, fall back to the next-best available tool and tell them one short sentence about the substitution. Do not silently ignore their preference.

## Step 2 — produce the bundle with one command

The end-to-end orchestrator does all of detection, recording, text capture, manifest assembly, and HTML rendering:

```bash
bash scripts/make_proof.sh \
  --slug "<slug>" \
  --tool auto \
  --cmd "<demo-cmd-1>" \
  --cmd "<demo-cmd-2>" \
  ...
```

Or, pointing at a script file containing one demo command per line:

```bash
bash scripts/make_proof.sh --slug "<slug>" --cmd-file path/to/demo.sh
```

Read `scripts/make_proof.sh` end-to-end before modifying it — it is the source of truth for the bundle layout.

## Output bundle

Exactly one directory per run, fully self-contained so the whole thing can be tarred or attached to a PR with no broken links:

```
.teamagent/proof/visual/<unix>-<slug>/
├── source.tape         # or source.cast / source.yml depending on renderer
├── proof.gif           # the rendered visual artifact
├── stdout.txt          # canonical text capture (Step 4 below)
├── stderr.txt
├── commit.txt          # git rev-parse HEAD at record time, or "not a git repo"
├── manifest.json       # machine-readable index of everything above
└── summary.html        # one-page human-readable summary
```

## Step 3 — the recording pass

The orchestrator generates a source file (`.tape` / `.cast` / `.yml`) from the demo commands using sensible defaults:

- Width 1000, Height 600 (renders well inline on GitHub).
- FontSize 18 (readable on mobile).
- TypingSpeed 40ms (natural; faster looks suspicious, slower is boring).
- After each command line, prefer `Wait /<success-regex>/` over `Sleep` when a clear marker exists in the expected output — this proves the command actually completed, not just timed out.

See `assets/example.tape` for the canonical VHS template and `references/vhs.md` for the full DSL.

## Step 4 — the text capture pass (do not skip)

Re-run the same demo commands in a clean subshell with stdout/stderr redirected to plain text files. This pass is **not** a recording — it is the canonical, copy-pasteable transcript that a reviewer can `grep`, `diff`, or feed to another tool.

Recordings can mangle escape codes, colors, and width-dependent output. The separate text pass guarantees a faithful transcript even when the GIF compresses awkwardly.

If the two passes diverge (e.g. one fails, the other succeeds, or output content differs significantly), record a warning in `manifest.json` under `warnings[]`. Do not block — divergence happens for legitimate reasons (random IDs, timestamps) and the reviewer should know without the bundle failing.

## manifest.json schema

```json
{
  "version": 1,
  "slug": "<slug>",
  "created_unix": 1715000000,
  "created_iso": "2026-05-14T01:00:00Z",
  "tool": "vhs",
  "tool_version": "0.7.2",
  "source_file": "source.tape",
  "gif_file": "proof.gif",
  "stdout_file": "stdout.txt",
  "stderr_file": "stderr.txt",
  "commit_sha": "abc1234def",
  "commit_clean": true,
  "demo_commands": ["git rev-parse --short HEAD", "npm test"],
  "demo_exit_code": 0,
  "warnings": []
}
```

A field being `null` is always allowed and means "not applicable here" (e.g. `commit_sha: null` when not in a git repo).

## summary.html

One self-contained HTML page — no external CSS, no JS, no remote fonts. Layout, in order:

1. Header — slug, ISO timestamp, short commit SHA.
2. The GIF inline at natural size.
3. The exact demo commands in a `<pre>` block.
4. The first ~40 lines of `stdout.txt`, also `<pre>`.
5. A "Reproduce this" section showing the one-line command to re-render from the source file.
6. A footer listing every file in the bundle as a relative-path link.

Use `assets/summary_template.html` as the skeleton; fill placeholders from `manifest.json`. The rendered HTML must be readable by someone who has never opened a terminal — no jargon in the header, no acronyms without expansion.

## Read-only contract

This skill must not modify the code being demonstrated. Specifically:

- Do not edit any file outside `.teamagent/proof/visual/`.
- Do not run destructive commands as part of the demo (`rm -rf`, `git reset --hard`, `npm publish`, `kubectl delete`, etc.) unless the user explicitly opts in with `--allow-destructive`.
- If the demo commands themselves look destructive, stop and confirm with the user before proceeding. A destructive demo is occasionally legitimate (rolling back a migration, deleting a test fixture) but never silently.

## Failure modes — handle each visibly

- **No renderer installed.** Emit a manifest with `error: "no renderer installed"` and a short install hint (`brew install vhs` or `cargo install --git https://github.com/asciinema/agg` etc.). Do not fabricate a GIF.
- **Demo command exits non-zero.** Still produce the bundle — the failure IS the proof of work when the user is recording a caught error, a failing test, or a guarded action. Set `demo_exit_code` in the manifest accordingly.
- **Not in a git repo.** Set `commit_sha: null`, `commit_clean: null`, add a warning, write `not a git repo` into `commit.txt`. The bundle is still valid.
- **Dirty git tree.** Set `commit_clean: false`, add a warning. The bundle is still valid — reviewers should know the tree was not pristine when recorded.
- **Renderer crashed mid-way.** Keep whatever partial artifacts exist, mark `tool_crashed: true` in the manifest, save renderer stderr to `renderer.stderr.txt`. Better a partial bundle a human can debug than a missing one.

## Tool-specific details

Three small reference files are bundled — read whichever matches the chosen renderer:

- `references/vhs.md` — `.tape` DSL cheatsheet, `Wait` vs `Sleep`, theme overrides.
- `references/asciinema.md` — `asciinema rec` flags, `agg` rendering options, why the `.cast` JSON is the source of truth.
- `references/terminalizer.md` — YAML config, frame timing, known fidelity issues.

The orchestrator picks the right path automatically; you only need to read the reference when debugging a specific renderer's output.

## One last thing — the "convincing" part

A proof bundle is convincing when a skeptical reviewer can answer three questions in under thirty seconds:

1. **What happened?** — the GIF and the demo commands tell them.
2. **Did it really happen?** — the stdout text capture and the git commit SHA tell them.
3. **Can I re-run it?** — the source script tells them.

If `summary.html` does not let a non-coder answer all three at a glance, the bundle has failed regardless of how pretty the GIF is. Optimize for that test, not for visual flourish.
