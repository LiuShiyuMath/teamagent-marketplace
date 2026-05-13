# Terminalizer reference

Terminalizer records a terminal session into a YAML file and renders it to GIF. It is the slowest and lowest-fidelity of the three options bundled with this skill — it lives here as a *fallback*, not a recommendation. Use only when neither VHS nor asciinema+agg is installable on the host.

Install: `npm install -g terminalizer`.

## End-to-end pipeline

```bash
terminalizer record source --skip-sharing --command "bash demo.sh"
terminalizer render source --output proof.gif
```

`terminalizer record source` writes `source.yml`; `terminalizer render source ...` reads that YAML and emits the GIF.

The orchestrator does this; the breakdown below is for debugging.

## The YAML format

The YAML config has two parts. The top half is metadata + config:

```yaml
config:
  command: bash demo.sh
  cwd: null
  env:
    recording: true
  cols: 100
  rows: 25
  repeat: 0
  quality: 100
  frameDelay: auto
  maxIdleTime: 2000
  theme:
    background: "transparent"
    foreground: "#eee"
```

The bottom half is the frames — an array of `{ delay, content }` tuples. You can hand-edit the frames after recording: tweak `delay` to speed up boring stretches, or strip a frame entirely. This is Terminalizer's one strong point — post-recording edit is easier than with VHS or asciinema.

## Known fidelity issues

- **Slow rendering.** A 30s recording can take 2–5 minutes to render. Budget accordingly.
- **Color drift.** Some 256-color escape sequences render with off-by-one palette indices.
- **Large output files.** GIFs are typically 3–5× the size of an `agg`-rendered GIF of the same session.
- **Cursor blinking is faked.** If your demo relies on cursor animations (e.g. progress spinners), they may look choppy.

## When you would actually use this

| Situation | Action |
|---|---|
| Host has Node but cannot install Go (VHS) or Rust (agg). | Terminalizer. |
| Recording needs frame-level post-edit (delete one frame, change one delay). | Terminalizer. |
| Everything else. | Use VHS or asciinema+agg instead. |
