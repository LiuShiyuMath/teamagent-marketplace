#!/usr/bin/env bash
# Detect which terminal-recording renderer is installed.
# Prints exactly one line: vhs | asciinema+agg | terminalizer | none
#
# Order of preference is deliberate:
#   1. vhs           - deterministic .tape DSL, the only one that genuinely
#                      scripts the terminal rather than recording a human at it.
#   2. asciinema+agg - text-faithful .cast (JSON), high honesty, good fidelity.
#                      Requires BOTH binaries; either alone is insufficient.
#   3. terminalizer  - YAML record + render, last-resort fallback.
#
# Exit code is always 0 — callers interpret the printed name.

set -u

has() { command -v "$1" >/dev/null 2>&1; }

if has vhs; then
  echo "vhs"
elif has asciinema && has agg; then
  echo "asciinema+agg"
elif has terminalizer; then
  echo "terminalizer"
else
  echo "none"
fi
