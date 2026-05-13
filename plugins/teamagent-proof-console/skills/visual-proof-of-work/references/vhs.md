# VHS reference

VHS (charmbracelet/vhs) scripts terminal interactions in a `.tape` file and renders them to GIF / MP4 / WebM deterministically. It is the only one of the three renderers that genuinely *scripts* the terminal — asciinema and Terminalizer record a session, VHS authors one.

Install: `brew install vhs` (macOS) or see https://github.com/charmbracelet/vhs.

## The minimum useful tape

```tape
Output proof.gif
Set Width 1000
Set Height 600
Set FontSize 18
Set TypingSpeed 40ms

Type "git rev-parse --short HEAD"
Enter
Sleep 500ms

Type "npm test"
Enter
Wait /passed|success|ok/
```

Run with `vhs proof.tape`.

## DSL essentials

| Statement | What it does | When to use |
|---|---|---|
| `Output FILE.gif` | Choose render target. Also supports `.mp4`, `.webm`. | First line of every tape. |
| `Set Width N` / `Set Height N` | Frame size in px. | `1000×600` reads well inline on GitHub PRs. |
| `Set FontSize N` | Glyph size. | `18` for mobile-readable; `16` for denser content. |
| `Set TypingSpeed Xms` | Per-keystroke delay. | `40ms` looks natural; below `20ms` looks fake; above `80ms` is boring. |
| `Set Theme "NAME"` | Built-in theme. | `"Dracula"`, `"Monokai"`, `"Tokyo Night"` are reliable. |
| `Type "TEXT"` | Type a string. | The bread-and-butter statement. Escape `"` and `\`. |
| `Enter` | Press Return. | After every `Type` that should execute. |
| `Sleep DURATION` | Wait `500ms` / `2s`. | Cosmetic pauses, transitions. |
| `Wait /REGEX/` | Block until the terminal output matches the regex. | The honest way to wait for a command to finish. |
| `Screenshot FILE.png` | Save a still frame at this point. | Useful for adding stills to docs. |
| `Hide` / `Show` | Toggle whether subsequent commands are recorded. | Hide setup like `cd` or `clear`. |

## `Wait` vs `Sleep` — the integrity choice

`Sleep 5s` is what you write when you do not actually know how long the command takes; if the command takes 10s, the GIF cuts mid-output. `Wait /passed/` blocks until the marker appears, with no upper bound. Always prefer `Wait` when the output has a clear success token. Use `Sleep` only for cosmetic pacing between commands.

## Hide setup, show only the work

```tape
Hide
Type "cd /tmp/demo-project && rm -rf node_modules"
Enter
Show
# from here on the recording shows a clean prompt
```

`Hide` ... `Show` runs the commands but excludes them from the recording. Useful for reproducible setup that the reviewer does not need to see.

## Determinism caveats

VHS is much more deterministic than asciinema or Terminalizer but the rendered GIF is still byte-affected by:

- Font availability (if `Set Font "..."` is missing, falls back to the default).
- Terminal version and ANSI handling.
- Timing-dependent command output (e.g. `date`, `$RANDOM`).

If you need a byte-identical GIF across machines, freeze the font and avoid timestamp-printing commands.

## Common gotchas

- `Type "..."` does not auto-press Enter. Forgetting `Enter` is the #1 mistake.
- Inside `Type "..."`, you must escape both `"` and `\`. The orchestrator's escape pass handles this for you.
- VHS spawns its own ttyd-backed terminal — environment variables from your shell *are not inherited*. If the demo needs `$PATH` or `$NVM_DIR`, set them inside the tape via `Type "export PATH=...:$PATH"` before the demo command.

## CI usage

The .tape file is checkable into git; CI can regenerate the GIF on every push. A typical CI step:

```bash
vhs --no-window proof.tape
git diff --exit-code proof.gif || echo "GIF drifted from .tape"
```
