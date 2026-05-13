# asciinema + agg reference

asciinema records a real terminal session into a `.cast` file — a small JSON-Lines document of timestamped writes to the terminal. The `.cast` is text-faithful: the recording IS the actual character stream the terminal saw. `agg` (asciinema gif generator) renders any `.cast` into an animated GIF.

Use this path when:

- VHS is not installed.
- You want the recording to be the *actual* session a human ran, not a scripted re-enactment.
- The reviewer wants to copy text out of the recording later (asciinema.org's web player allows this; agg's GIF does not, but the underlying `.cast` is plain JSON).

Install: `brew install asciinema agg` (macOS) or `cargo install --git https://github.com/asciinema/agg`.

## End-to-end pipeline

```bash
asciinema rec --quiet --overwrite --command "bash demo.sh" source.cast
agg --font-size 18 --cols 100 --rows 25 source.cast proof.gif
```

The orchestrator does this for you; the breakdown below is for debugging.

## `asciinema rec` flags worth knowing

| Flag | Purpose |
|---|---|
| `--command "..."` | Record this exact command, not an interactive shell. Use this for proof-of-work — interactive recording invites mistakes. |
| `--quiet` | Suppress asciinema's "asciicast recording finished" prompt. |
| `--overwrite` | Replace existing cast file instead of erroring. |
| `--idle-time-limit N` | Compress idle stretches longer than N seconds — speeds up boring waits. |
| `--cols N --rows N` | Force a terminal geometry instead of inheriting yours. Match these to your `agg` flags. |

## `agg` rendering options

```bash
agg \
  --font-size 18 \
  --cols 100 \
  --rows 25 \
  --theme monokai \
  --speed 1.0 \
  source.cast proof.gif
```

| Flag | Notes |
|---|---|
| `--font-size N` | Glyph height. 18 for PR-inline, 14 for dense terminals. |
| `--cols N --rows N` | MUST match (or exceed) the geometry used during `asciinema rec` or the GIF clips. |
| `--theme NAME` | `asciinema`, `monokai`, `solarized-dark`, `solarized-light`, `tango`, `dracula`, `nord`. |
| `--speed F` | Playback multiplier. `2.0` halves the GIF duration; useful if the underlying command had long unavoidable waits. |
| `--no-loop` | Render once instead of looping. |

## Why the `.cast` is the source of truth

The `.cast` is a small JSON-Lines file. The header line is metadata; subsequent lines are `[seconds_offset, "o", "<characters>"]` tuples. This means:

- It diffs cleanly in PR review.
- You can re-render the same GIF later with different `agg` flags.
- You can `grep` it for the literal strings that appeared on the screen.
- It is roughly 100× smaller than the rendered GIF.

Bundle the `.cast` alongside the GIF; it is the visual proof's audit log.

## Caveats

- asciinema records what *your* terminal emits, including width-dependent line wrapping. If your terminal is 240 cols wide at record time but you render at `--cols 100`, the GIF will look very different from the live session.
- ANSI escape sequences that depend on cursor querying (e.g. some progress bars) may render imperfectly — `agg` is good but not perfect.
- Audio is never captured (asciinema is text-only).

## When to prefer asciinema over VHS

| Situation | Prefer |
|---|---|
| You want determinism, scripted timing, and the source IS the proof. | VHS |
| You want to record an actual human session and prove it happened verbatim. | asciinema |
| You need the recording to be `grep`-able later. | asciinema (`.cast` is JSON) |
| You want to share an interactive web player with copy-paste-able output. | asciinema (asciinema.org) |
