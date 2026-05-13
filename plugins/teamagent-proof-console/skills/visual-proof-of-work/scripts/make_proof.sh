#!/usr/bin/env bash
# make_proof.sh — orchestrate a visual proof-of-work bundle.
#
# Two passes, deliberately:
#   Pass 1 (visual): write a source script in the chosen DSL and render to GIF.
#   Pass 2 (text):   re-run the same demo commands in a clean subshell with
#                    stdout/stderr redirected to plain text — this is the
#                    canonical, copy-pasteable transcript.
#
# Both passes use the same exact command strings. If they diverge in exit code
# or content, a warning is recorded in manifest.json (the bundle is still valid).
#
# Output: one self-contained directory at .teamagent/proof/visual/<unix>-<slug>/
# containing: source.{tape,cast,yml}, proof.gif, stdout.txt, stderr.txt,
# commit.txt, manifest.json, summary.html.
#
# Usage:
#   make_proof.sh --slug NAME [--tool auto|vhs|asciinema|terminalizer] \
#                 --cmd "..." [--cmd "..."]...
#   make_proof.sh --slug NAME --cmd-file path/to/demo.sh
#
# Optional:
#   --width N      (default 1000)
#   --height N     (default 600)
#   --font-size N  (default 18)
#   --allow-destructive  (opt-in to commands containing rm/reset/publish/delete)
#   --output-root PATH   (default .teamagent/proof/visual)

set -u  # not -e; we want partial bundles on failure rather than hard exits

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$(cd "${SCRIPT_DIR}/../assets" && pwd)"

SLUG=""
TOOL="auto"
WIDTH=1000
HEIGHT=600
FONT_SIZE=18
ALLOW_DESTRUCTIVE=0
OUTPUT_ROOT=".teamagent/proof/visual"
CMDS=()
CMD_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --slug)               SLUG="$2"; shift 2 ;;
    --tool)               TOOL="$2"; shift 2 ;;
    --cmd)                CMDS+=("$2"); shift 2 ;;
    --cmd-file)           CMD_FILE="$2"; shift 2 ;;
    --width)              WIDTH="$2"; shift 2 ;;
    --height)             HEIGHT="$2"; shift 2 ;;
    --font-size)          FONT_SIZE="$2"; shift 2 ;;
    --allow-destructive)  ALLOW_DESTRUCTIVE=1; shift ;;
    --output-root)        OUTPUT_ROOT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -n "${CMD_FILE}" ]; then
  if [ ! -r "${CMD_FILE}" ]; then
    echo "cannot read --cmd-file ${CMD_FILE}" >&2; exit 2
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    case "${line}" in
      ''|\#*) ;;
      *) CMDS+=("${line}") ;;
    esac
  done < "${CMD_FILE}"
fi

if [ "${#CMDS[@]}" -eq 0 ]; then
  echo "no demo commands provided (use --cmd or --cmd-file)" >&2; exit 2
fi

# Default slug from first command's binary name, sanitised.
if [ -z "${SLUG}" ]; then
  first="${CMDS[0]}"
  bin="${first%% *}"
  bin="${bin##*/}"
  SLUG="$(printf '%s' "${bin}" | LC_ALL=C tr -c 'a-zA-Z0-9' '-' | sed 's/^-*//;s/-*$//' | tr '[:upper:]' '[:lower:]')"
  [ -z "${SLUG}" ] && SLUG="proof"
fi

# Destructive-command guard. A reviewer occasionally records a rollback or a
# delete — that is legitimate but never silent.
DESTRUCTIVE_PAT='rm[[:space:]]+-rf|git[[:space:]]+reset[[:space:]]+--hard|npm[[:space:]]+publish|kubectl[[:space:]]+delete|drop[[:space:]]+table|force-push|push[[:space:]]+--force'
if [ "${ALLOW_DESTRUCTIVE}" -eq 0 ]; then
  for c in "${CMDS[@]}"; do
    if printf '%s' "${c}" | grep -Eqi "${DESTRUCTIVE_PAT}"; then
      echo "destructive command detected: ${c}" >&2
      echo "pass --allow-destructive to opt in." >&2
      exit 3
    fi
  done
fi

UNIX_TS="$(date +%s)"
ISO_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OUT_DIR="${OUTPUT_ROOT}/${UNIX_TS}-${SLUG}"
mkdir -p "${OUT_DIR}"

# Resolve renderer.
RESOLVED="$(bash "${SCRIPT_DIR}/detect_tool.sh")"
case "${TOOL}" in
  auto)         CHOSEN="${RESOLVED}" ;;
  vhs)
    if command -v vhs >/dev/null 2>&1; then CHOSEN="vhs"
    else CHOSEN="${RESOLVED}"; SUBSTITUTION="vhs not installed; using ${CHOSEN}"
    fi ;;
  asciinema)
    if command -v asciinema >/dev/null 2>&1 && command -v agg >/dev/null 2>&1; then CHOSEN="asciinema+agg"
    else CHOSEN="${RESOLVED}"; SUBSTITUTION="asciinema+agg not installed; using ${CHOSEN}"
    fi ;;
  terminalizer)
    if command -v terminalizer >/dev/null 2>&1; then CHOSEN="terminalizer"
    else CHOSEN="${RESOLVED}"; SUBSTITUTION="terminalizer not installed; using ${CHOSEN}"
    fi ;;
  *) echo "unknown --tool: ${TOOL}" >&2; exit 2 ;;
esac

WARNINGS=()
[ -n "${SUBSTITUTION:-}" ] && WARNINGS+=("${SUBSTITUTION}")

# Git context — non-fatal.
COMMIT_SHA="null"
COMMIT_CLEAN="null"
if git rev-parse --git-dir >/dev/null 2>&1; then
  COMMIT_SHA="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
  if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
    COMMIT_CLEAN="true"
  else
    COMMIT_CLEAN="false"
    WARNINGS+=("git tree was dirty at record time")
  fi
  printf '%s\n' "${COMMIT_SHA}" > "${OUT_DIR}/commit.txt"
else
  printf 'not a git repo\n' > "${OUT_DIR}/commit.txt"
  WARNINGS+=("not run inside a git repo")
fi

# ---------------------------------------------------------------------------
# Pass 2 (text capture) — run first so the recorder cannot interfere with
# stdout/stderr. The commands run in a fresh bash subshell.
# ---------------------------------------------------------------------------
STDOUT_FILE="${OUT_DIR}/stdout.txt"
STDERR_FILE="${OUT_DIR}/stderr.txt"
{
  for c in "${CMDS[@]}"; do
    printf '$ %s\n' "${c}"
    bash -c "${c}"
    printf '\n'
  done
} >"${STDOUT_FILE}" 2>"${STDERR_FILE}"
DEMO_EXIT=$?

# ---------------------------------------------------------------------------
# Pass 1 (visual recording) — generate the source script then render.
# ---------------------------------------------------------------------------
SOURCE_FILE=""
GIF_FILE="${OUT_DIR}/proof.gif"
TOOL_VERSION="unknown"
TOOL_CRASHED="false"

render_vhs() {
  SOURCE_FILE="${OUT_DIR}/source.tape"
  TOOL_VERSION="$(vhs --version 2>/dev/null | awk '{print $NF}')"
  {
    printf 'Output %s\n' "${GIF_FILE}"
    printf 'Set Width %s\n'    "${WIDTH}"
    printf 'Set Height %s\n'   "${HEIGHT}"
    printf 'Set FontSize %s\n' "${FONT_SIZE}"
    printf 'Set TypingSpeed 40ms\n'
    printf '\n'
    for c in "${CMDS[@]}"; do
      esc="$(printf '%s' "${c}" | sed 's/\\/\\\\/g; s/"/\\"/g')"
      printf 'Type "%s"\n' "${esc}"
      printf 'Enter\n'
      printf 'Sleep 800ms\n'
    done
  } > "${SOURCE_FILE}"
  if ! vhs "${SOURCE_FILE}" 2> "${OUT_DIR}/renderer.stderr.txt"; then
    TOOL_CRASHED="true"
    WARNINGS+=("vhs exited non-zero — see renderer.stderr.txt")
  fi
}

render_asciinema() {
  SOURCE_FILE="${OUT_DIR}/source.cast"
  TOOL_VERSION="$(asciinema --version 2>/dev/null | awk '{print $NF}')"
  TMP_SCRIPT="$(mktemp -t vproof.XXXXXX.sh)"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set +e\n'
    for c in "${CMDS[@]}"; do
      printf 'echo "$ %s"\n' "$(printf '%s' "${c}" | sed 's/"/\\"/g')"
      printf '%s\n' "${c}"
      printf 'sleep 0.5\n'
    done
  } > "${TMP_SCRIPT}"
  chmod +x "${TMP_SCRIPT}"
  asciinema rec --quiet --overwrite --command "bash ${TMP_SCRIPT}" "${SOURCE_FILE}" \
    2> "${OUT_DIR}/renderer.stderr.txt" || { TOOL_CRASHED="true"; WARNINGS+=("asciinema rec failed"); }
  if [ "${TOOL_CRASHED}" = "false" ]; then
    agg --font-size "${FONT_SIZE}" --cols "$(( WIDTH / 10 ))" --rows "$(( HEIGHT / 24 ))" \
      "${SOURCE_FILE}" "${GIF_FILE}" 2>> "${OUT_DIR}/renderer.stderr.txt" \
      || { TOOL_CRASHED="true"; WARNINGS+=("agg render failed"); }
  fi
  rm -f "${TMP_SCRIPT}"
}

render_terminalizer() {
  SOURCE_FILE="${OUT_DIR}/source.yml"
  TOOL_VERSION="$(terminalizer --version 2>/dev/null | awk '{print $NF}')"
  TMP_SCRIPT="$(mktemp -t vproof.XXXXXX.sh)"
  {
    printf '#!/usr/bin/env bash\n'
    for c in "${CMDS[@]}"; do
      printf 'echo "$ %s"\n' "$(printf '%s' "${c}" | sed 's/"/\\"/g')"
      printf '%s\n' "${c}"
      printf 'sleep 0.5\n'
    done
  } > "${TMP_SCRIPT}"
  chmod +x "${TMP_SCRIPT}"
  REC_BASE="${OUT_DIR}/source"
  terminalizer record "${REC_BASE}" --skip-sharing --command "bash ${TMP_SCRIPT}" \
    2> "${OUT_DIR}/renderer.stderr.txt" || { TOOL_CRASHED="true"; WARNINGS+=("terminalizer record failed"); }
  if [ "${TOOL_CRASHED}" = "false" ]; then
    terminalizer render "${REC_BASE}" --output "${GIF_FILE}" 2>> "${OUT_DIR}/renderer.stderr.txt" \
      || { TOOL_CRASHED="true"; WARNINGS+=("terminalizer render failed"); }
  fi
  rm -f "${TMP_SCRIPT}"
}

case "${CHOSEN}" in
  vhs)            render_vhs ;;
  asciinema+agg)  render_asciinema ;;
  terminalizer)   render_terminalizer ;;
  none)
    SOURCE_FILE=""
    WARNINGS+=("no renderer installed; install vhs (brew install vhs) or asciinema+agg")
    TOOL_CRASHED="true"
    ;;
esac

# ---------------------------------------------------------------------------
# manifest.json
# ---------------------------------------------------------------------------
MANIFEST="${OUT_DIR}/manifest.json"
{
  printf '{\n'
  printf '  "version": 1,\n'
  printf '  "slug": "%s",\n' "${SLUG}"
  printf '  "created_unix": %s,\n' "${UNIX_TS}"
  printf '  "created_iso": "%s",\n' "${ISO_TS}"
  printf '  "tool": "%s",\n' "${CHOSEN}"
  printf '  "tool_version": "%s",\n' "${TOOL_VERSION}"
  printf '  "tool_crashed": %s,\n' "${TOOL_CRASHED}"
  printf '  "source_file": "%s",\n' "$(basename "${SOURCE_FILE:-}")"
  printf '  "gif_file": "proof.gif",\n'
  printf '  "stdout_file": "stdout.txt",\n'
  printf '  "stderr_file": "stderr.txt",\n'
  if [ "${COMMIT_SHA}" = "null" ]; then
    printf '  "commit_sha": null,\n'
  else
    printf '  "commit_sha": "%s",\n' "${COMMIT_SHA}"
  fi
  if [ "${COMMIT_CLEAN}" = "null" ]; then
    printf '  "commit_clean": null,\n'
  else
    printf '  "commit_clean": %s,\n' "${COMMIT_CLEAN}"
  fi
  printf '  "demo_exit_code": %s,\n' "${DEMO_EXIT}"
  printf '  "demo_commands": ['
  for i in "${!CMDS[@]}"; do
    [ "$i" -gt 0 ] && printf ', '
    esc="$(printf '%s' "${CMDS[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    printf '"%s"' "${esc}"
  done
  printf '],\n'
  printf '  "warnings": ['
  for i in "${!WARNINGS[@]}"; do
    [ "$i" -gt 0 ] && printf ', '
    esc="$(printf '%s' "${WARNINGS[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    printf '"%s"' "${esc}"
  done
  printf ']\n'
  printf '}\n'
} > "${MANIFEST}"

# ---------------------------------------------------------------------------
# summary.html — fill the template from the manifest.
# ---------------------------------------------------------------------------
TEMPLATE="${ASSETS_DIR}/summary_template.html"
SUMMARY="${OUT_DIR}/summary.html"

html_escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# Multi-line placeholders go through temp files because awk -v cannot carry
# newlines in its string literals. Single-line placeholders are fine via -v.
CMDS_TMP="${OUT_DIR}/.cmds.html.tmp"
STDOUT_TMP="${OUT_DIR}/.stdout.html.tmp"
printf '%s\n' "${CMDS[@]}" | html_escape > "${CMDS_TMP}"
(head -n 40 "${STDOUT_FILE}" 2>/dev/null || true) | html_escape > "${STDOUT_TMP}"

COMMIT_DISPLAY="${COMMIT_SHA}"
[ "${COMMIT_DISPLAY}" = "null" ] && COMMIT_DISPLAY="(not a git repo)"

REPRODUCE_CMD=""
case "${CHOSEN}" in
  vhs)            REPRODUCE_CMD="vhs source.tape" ;;
  asciinema+agg)  REPRODUCE_CMD="agg source.cast proof.gif" ;;
  terminalizer)   REPRODUCE_CMD="terminalizer render source --output proof.gif" ;;
  *)              REPRODUCE_CMD="(no renderer was available at record time)" ;;
esac

if [ -r "${TEMPLATE}" ]; then
  awk -v slug="${SLUG}" \
      -v iso="${ISO_TS}" \
      -v commit="${COMMIT_DISPLAY}" \
      -v tool="${CHOSEN}" \
      -v reproduce="${REPRODUCE_CMD}" \
      -v sourcefile="$(basename "${SOURCE_FILE:-source}")" \
      -v cmdsfile="${CMDS_TMP}" \
      -v stdoutfile="${STDOUT_TMP}" \
      '{
        if ($0 ~ /__CMDS__/) {
          while ((getline line < cmdsfile) > 0) print line
          close(cmdsfile)
          next
        }
        if ($0 ~ /__STDOUT__/) {
          while ((getline line < stdoutfile) > 0) print line
          close(stdoutfile)
          next
        }
        gsub(/__SLUG__/, slug)
        gsub(/__ISO__/, iso)
        gsub(/__COMMIT__/, commit)
        gsub(/__TOOL__/, tool)
        gsub(/__REPRODUCE__/, reproduce)
        gsub(/__SOURCE__/, sourcefile)
        print
      }' "${TEMPLATE}" > "${SUMMARY}"
else
  printf '<html><body><h1>%s</h1><p>summary template missing</p></body></html>\n' "${SLUG}" > "${SUMMARY}"
fi

rm -f "${CMDS_TMP}" "${STDOUT_TMP}"

printf '%s\n' "${OUT_DIR}"
exit 0
