#!/usr/bin/env bash
# Week 10 lab (w10_context_lab) - self-check. Required results and bonuses stay separate.
# No `set -e`: every failure becomes a useful report entry.
# Deterministic: no rand(), no timestamps in grading. All checks but app_tests
# are fully offline; app_tests builds its Docker image on its first run.
#
# The graded artifacts are the AGENT RULES the student builds in Steps 2-6:
# AGENTS.md + rules/ TOC + CLAUDE.md/GEMINI.md symlinks + HANDOFF.md + commits.

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT" || exit 0

RESULTS="results"
JSON="$RESULTS/report.json"
CHALLENGE_JSON="$RESULTS/challenge_report.json"

PASS=0
FAIL=0
TOTAL=0
BONUS=0
BONUS_DONE=0
REQ_ITEMS=""
BONUS_ITEMS=""

mkdir -p "$RESULTS"

record() {
  name=$1
  status=$2
  msg=$3
  TOTAL=$((TOTAL + 1))
  if [ "$status" = "PASS" ]; then
    PASS=$((PASS + 1))
    REQ_ITEMS="$REQ_ITEMS{\"name\": \"$name\", \"status\": \"pass\"},"
    echo "PASS $name - $msg"
  else
    FAIL=$((FAIL + 1))
    REQ_ITEMS="$REQ_ITEMS{\"name\": \"$name\", \"status\": \"fail\"},"
    echo "FAIL $name - $msg"
  fi
}

record_bonus() {
  name=$1
  status=$2
  msg=$3
  BONUS=$((BONUS + 1))
  if [ "$status" = "DONE" ]; then
    BONUS_DONE=$((BONUS_DONE + 1))
    BONUS_ITEMS="$BONUS_ITEMS{\"name\": \"$name\", \"status\": \"bonus\"},"
    echo "BONUS $name - $msg"
  else
    BONUS_ITEMS="$BONUS_ITEMS{\"name\": \"$name\", \"status\": \"todo\"},"
    echo "TODO $name (optional) - $msg"
  fi
}

section() { echo ""; echo "-- $1 --"; }

run_python() {
  if command -v python3 >/dev/null 2>&1; then
    python3 "$@"
  else
    uv run --no-project python "$@"
  fi
}

echo "=============================================="
echo "  w10_context_lab - Self Check"
echo "=============================================="

section "Required"

# ---- 1. student.json valid ------------------------------------------
if [ -f student.json ] && run_python - <<'PY'
import json, sys
try:
    d = json.load(open("student.json"))
    ok = isinstance(d, dict) and isinstance(d.get("name"), str) and d.get("name","").strip() != "" \
         and isinstance(d.get("student_id"), str) and d.get("student_id","").strip() != ""
except Exception:
    sys.exit(1)
sys.exit(0 if ok else 1)
PY
then
  record "student_json" "PASS" "student.json has non-empty name + student_id"
else
  record "student_json" "FAIL" "create student.json with name + student_id fields (Step 0)"
fi

# ---- 2. AGENTS.md: exists, cap, goldenrule, test command ------------
agents_ok=false
if [ -f AGENTS.md ]; then
  bytes=$(wc -c < AGENTS.md)
  echo "info: AGENTS.md = $bytes bytes (cap 32768) / $(wc -l < AGENTS.md | tr -d ' ') lines"
  if [ "$bytes" -le 32768 ] && grep -qF "<goldenrule>" AGENTS.md && grep -q "pytest" AGENTS.md; then
    agents_ok=true
  fi
fi
if $agents_ok; then
  record "agents_md" "PASS" "AGENTS.md <= 32768 bytes, has <goldenrule> block + a pytest command"
else
  record "agents_md" "FAIL" "AGENTS.md missing/oversized; needs <goldenrule> block + a test command (see Step 4)"
fi

# ---- 3. one file, many agents: symlinks ----------------------------
links_ok=true
for f in CLAUDE.md GEMINI.md; do
  if [ ! -L "$f" ]; then
    links_ok=false
  fi
done
if $links_ok; then
  cl=$(readlink CLAUDE.md)
  ge=$(readlink GEMINI.md)
  if [ "$cl" = "AGENTS.md" ] && [ "$ge" = "AGENTS.md" ]; then
    record "symlinks" "PASS" "CLAUDE.md and GEMINI.md both link to AGENTS.md"
  else
    links_ok=false
  fi
fi
if ! $links_ok; then
  record "symlinks" "FAIL" "ln -s AGENTS.md CLAUDE.md ; ln -s AGENTS.md GEMINI.md"
fi

# ---- 4. rules TOC: every named file exists --------------------------
rules_ok=false
missing_rules=""
if [ -f AGENTS.md ]; then
  toc=$(grep -oE 'rules/[A-Za-z0-9_.-]+\.md' AGENTS.md | sort -u)
  if [ -n "$toc" ]; then
    rules_ok=true
    for r in $toc; do
      if [ ! -f "$r" ]; then
        rules_ok=false
        missing_rules="$missing_rules $r"
      fi
    done
  fi
fi
if $rules_ok; then
  record "rules_toc" "PASS" "every rules/*.md named in the AGENTS.md TOC exists"
else
  record "rules_toc" "FAIL" "AGENTS.md missing, or TOC names files that do not exist:$missing_rules"
fi

# ---- 5. HANDOFF.md sections -----------------------------------------
if [ -f HANDOFF.md ] \
  && grep -qi "what i did" HANDOFF.md \
  && grep -qi "what.s next" HANDOFF.md \
  && grep -qi "context" HANDOFF.md; then
  record "handoff" "PASS" "HANDOFF.md has What I did / What's next / Context"
else
  record "handoff" "FAIL" "HANDOFF.md missing or missing a section: What I did / What's next / Context"
fi

# ---- 6. >= 3 student commits ----------------------------------------
root_sha=$(git rev-list --max-parents=0 HEAD 2>/dev/null | tail -1)
student_commits=0
if [ -n "$root_sha" ]; then
  while read -r entry; do
    case "$entry" in
      *github-actions*|*41898282*) ;;
      *) student_commits=$((student_commits + 1)) ;;
    esac
  done < <(git log --format='%H %an %ae' "${root_sha}..HEAD" 2>/dev/null)
fi
if [ "$student_commits" -ge 3 ]; then
  record "student_commits" "PASS" "$student_commits non-bot commits after the template root"
else
  record "student_commits" "FAIL" "need >= 3 of your own commits (have $student_commits)"
fi

# ---- 7. the floor app still passes its own tests --------------------
# Thesis check: the lab grades agent RULES, but a rules file that lets the
# agent break the app must not earn points. Run the shipped suite; docker is
# the course runtime, so a missing docker FAILs rather than TODOs.
app_ok=false
app_msg="floor app tests fail (see results/app_tests.log) - fix the app or the agent's change"
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    if docker compose run --rm fastapi uv run pytest -q > "$RESULTS/app_tests.log" 2>&1; then
      app_ok=true
    fi
    tail -3 "$RESULTS/app_tests.log"
  else
    app_msg="Docker daemon is not running - start Docker Desktop (macOS) or sudo systemctl start docker (Linux), then rerun check.sh"
  fi
else
  app_msg="docker missing. Start Docker Desktop / install Docker, then rerun."
fi
if $app_ok; then
  record "app_tests" "PASS" "floor app passes its own pytest suite (docker compose run)"
else
  record "app_tests" "FAIL" "$app_msg"
fi

section "Bonus"

# ---- b1. AGENTS.md <= 200 lines -------------------------------------
if [ -f AGENTS.md ] && [ "$(wc -l < AGENTS.md | tr -d ' ')" -le 200 ]; then
  record_bonus "agents_lines" "DONE" "AGENTS.md within 200 lines (density bonus)"
else
  record_bonus "agents_lines" "TODO" "keep AGENTS.md within 200 lines - move detail into rules/*.md"
fi

# ---- b2. token_report.md with rtk before/after numbers --------------
if [ -f token_report.md ] && [ -s token_report.md ] && [ "$(grep -oE '[0-9]+' token_report.md | wc -l | tr -d ' ')" -ge 2 ]; then
  record_bonus "token_report" "DONE" "token_report.md holds rtk before/after numbers"
else
  record_bonus "token_report" "TODO" "record rtk before/after output sizes in token_report.md (Step 3)"
fi

# ---- b3. permission profile committed as codex-config.toml ---------
if [ -f codex-config.toml ] && grep -q 'extends = ":workspace"' codex-config.toml && grep -q "deny" codex-config.toml; then
  record_bonus "codex_config" "DONE" "permission profile snippet committed (codex-config.toml)"
else
  record_bonus "codex_config" "TODO" "commit your permission profile as codex-config.toml (Step 1)"
fi

# ---- report assembly --------------------------------------------------
{
  echo "{"
  echo "  \"score\": $PASS,"
  echo "  \"total\": $TOTAL,"
  echo "  \"results\": [$REQ_ITEMS]"
  echo "}"
} > "$JSON"
{
  echo "{"
  echo "  \"bonus\": $BONUS_DONE,"
  echo "  \"bonus_total\": $BONUS,"
  echo "  \"results\": [$BONUS_ITEMS]"
  echo "}"
} > "$CHALLENGE_JSON"
# the accumulators end in a trailing comma; JSON does not allow one
sed -i.bak 's/,]/]/' "$JSON" "$CHALLENGE_JSON" && rm -f "$JSON.bak" "$CHALLENGE_JSON.bak"

echo ""
echo "=============================================="
echo "  Score: $PASS / $TOTAL required   |   $FAIL failed"
echo "  Bonus: $BONUS_DONE / $BONUS challenges"
echo "=============================================="
echo "Reports: $JSON + $CHALLENGE_JSON"

if [ "$FAIL" -eq 0 ]; then
  echo "ALL PASS - run: bash submit.sh"
else
  echo "Fix required checks, then rerun bash check.sh."
fi
echo "Bonus challenges never cause a required failure."

exit 0
