#!/usr/bin/env bash
# focus.sh — print a file with a moving focus highlight.
# Usage: focus.sh <file> <focus-start> <focus-end> [--window N] [--title "..."]
#
# Dims context lines, brightens focus range, shows line numbers, draws a
# top+bottom rule with optional title. Pure bash + ANSI.

set -u

file=""
start=0
end=0
window=14
title=""

# positional
if [ $# -lt 3 ]; then
  echo "usage: $0 <file> <start> <end> [--window N] [--title \"...\"]" >&2
  exit 2
fi
file="$1"; start="$2"; end="$3"; shift 3 || true

while [ $# -gt 0 ]; do
  case "$1" in
    --window) window="$2"; shift 2 ;;
    --title)  title="$2";  shift 2 ;;
    *) shift ;;
  esac
done

[ -r "$file" ] || { echo "focus.sh: cannot read $file" >&2; exit 1; }

total=$(wc -l < "$file" | tr -d ' ')
[ "$total" -lt 1 ] && total=1

# clamp focus
[ "$start" -lt 1 ] && start=1
[ "$end"   -lt "$start" ] && end="$start"
[ "$end"   -gt "$total" ] && end="$total"

# window around focus
span=$(( end - start + 1 ))
pad=$(( (window - span) / 2 ))
[ "$pad" -lt 0 ] && pad=0
view_start=$(( start - pad ))
view_end=$(( end + pad ))
[ "$view_start" -lt 1 ] && view_start=1
[ "$view_end"   -gt "$total" ] && view_end="$total"

# colors
DIM=$'\033[2;37m'
BOLD=$'\033[1;33m'
ACCENT=$'\033[1;36m'
RESET=$'\033[0m'
GUTTER=$'\033[38;5;240m'

# width
cols=$(tput cols 2>/dev/null || echo 120)
[ -z "$cols" ] && cols=120
rule_char="─"
rule=""
i=0
while [ $i -lt $((cols - 2)) ]; do rule="${rule}${rule_char}"; i=$((i+1)); done

# header
if [ -n "$title" ]; then
  label="┄┄ ${title} ┄┄"
  printf "%s%s%s\n" "$ACCENT" "$label" "$RESET"
else
  printf "%s%s%s\n" "$GUTTER" "$rule" "$RESET"
fi
printf "%s%s  (lines %d–%d of %d, focus %d–%d)%s\n" \
  "$GUTTER" "$(basename "$file")" "$view_start" "$view_end" "$total" "$start" "$end" "$RESET"
printf "%s%s%s\n" "$GUTTER" "$rule" "$RESET"

# body
lineno=0
while IFS= read -r line || [ -n "$line" ]; do
  lineno=$(( lineno + 1 ))
  if [ "$lineno" -lt "$view_start" ]; then continue; fi
  if [ "$lineno" -gt "$view_end"   ]; then break;    fi
  num=$(printf "%4d" "$lineno")
  if [ "$lineno" -ge "$start" ] && [ "$lineno" -le "$end" ]; then
    printf "%s%s │%s %s%s%s\n" "$ACCENT" "$num" "$RESET" "$BOLD" "$line" "$RESET"
  else
    printf "%s%s │ %s%s\n" "$GUTTER" "$num" "$line" "$RESET"
  fi
done < "$file"

printf "%s%s%s\n" "$GUTTER" "$rule" "$RESET"
