#!/usr/bin/env bash
# A/B live demo of the teamagent-memory wedge.
# Recorded with asciinema, rendered with agg.
# Verbose so the gif viewer can follow without prior context.

set -u
PLUGIN_DIR="${PLUGIN_DIR:-$(cd "$(dirname "$0")/../.." && pwd)/plugins/teamagent-memory}"
DEMO="${DEMO:-${TMPDIR:-/tmp}/teamagent-demo-$$}"
rm -rf "$DEMO"; mkdir -p "$DEMO/.teamagent/rules/active"

# colors
BOLD=$'\033[1m'; DIM=$'\033[2m'; RST=$'\033[0m'
RED=$'\033[31m'; GREEN=$'\033[32m'; YEL=$'\033[33m'; CYA=$'\033[36m'; MAG=$'\033[35m'

type_out() {
  local s="$1"
  for ((i=0;i<${#s};i++)); do printf '%s' "${s:$i:1}"; sleep 0.020; done; echo
}
banner() {
  printf '%s' "$YEL"
  cat <<'EOF'
+==============================================================+
|                                                              |
|   teamagent-marketplace  -  live wedge demo                  |
|   "Previous Claude made the mistake.                         |
|    New Claude tried to repeat it.                            |
|    TeamAgent blocked it."                                    |
|                                                              |
+==============================================================+
EOF
  printf '%s' "$RST"
}
section() { printf '\n%s---  %s  %s\n%s' "$CYA$BOLD" "$1" "${RST}" ""; sleep 0.4; }

clear
banner
sleep 1.2

# --- 1. seed a team rule ---
section "1. Seed an existing team rule (Alice corrected this last week)"
cat > "$DEMO/.teamagent/rules/active/moment-dayjs.json" <<'EOF'
{
  "id":         "moment-dayjs",
  "trigger":    "moment",
  "wrong":      "moment",
  "correct":    "dayjs",
  "why":        "moment is deprecated; team uses dayjs",
  "confidence": 3
}
EOF
type_out "\$ cat .teamagent/rules/active/moment-dayjs.json"
sleep 0.2
sed 's/^/  /' "$DEMO/.teamagent/rules/active/moment-dayjs.json"
sleep 1.5

# --- 2. control run ---
section "2. A · CONTROL ($DIM no plugin loaded$RST$CYA$BOLD)"
type_out "\$ claudefast --bare -p \"should I install moment for date parsing?\""
echo "${DIM}(running...)${RST}"
A_OUT=$( ( cd "$DEMO" && claudefast --bare \
            --append-system-prompt "Reply in one short sentence with the npm install command you would run." \
            -p "should I install moment for date parsing?" --output-format=json 2>/dev/null ) | jq -r '.result' )
printf '%s>>> %s%s\n' "$RED" "$A_OUT" "$RST"
sleep 2.5

# --- 3. treatment run ---
section "3. B · TREATMENT ($DIM --plugin-dir teamagent-memory$RST$CYA$BOLD)"
type_out "\$ claudefast --plugin-dir teamagent-memory -p \"should I install moment for date parsing?\""
echo "${DIM}(running... PreToolUse/UserPromptSubmit hooks armed)${RST}"
B_OUT=$( ( cd "$DEMO" && claudefast --plugin-dir "$PLUGIN_DIR" \
            --append-system-prompt "Reply in one short sentence with the npm install command you would run." \
            -p "should I install moment for date parsing?" --output-format=json 2>/dev/null ) | jq -r '.result' )
printf '%s>>> %s%s\n' "$GREEN" "$B_OUT" "$RST"
sleep 2.5

# --- 4. the verdict ---
section "4. Verdict"
printf '%s  A (no plugin)   ->%s %s%s\n' "$BOLD" "$RST" "$RED" "$A_OUT$RST"
printf '%s  B (plugin on)   ->%s %s%s\n' "$BOLD" "$RST" "$GREEN" "$B_OUT$RST"
echo
printf '%sPrevious Claude made the mistake. New Claude tried to repeat it. TeamAgent blocked it.%s\n' "$YEL$BOLD" "$RST"
sleep 3
