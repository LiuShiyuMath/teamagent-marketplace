# Archived demo recordings

Older versions of the A/B demo, kept for provenance. **Not** the canonical demo — see `../demo.gif`, `../demo.cast`, `../demo.sh` for the current version.

| Version | Date | What it shows | Tool |
| --- | --- | --- | --- |
| `demo-v1.*` | 2026-05-13 | Single-pane bash demo of the A/B run with hand-rolled typing effect | `asciinema rec` of `bash demo.sh` (no tmux) |
| `demo-v2.*` *(current → `../demo.*`)* | 2026-05-14 | Real `tmux` two-pane interactive run: left pane scroll-focuses through the rule card + hook source code; right pane runs `claudefast` A/B live | `asciinema rec` of `tmux attach …` driven by `tmux send-keys` |
