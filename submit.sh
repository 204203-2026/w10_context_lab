#!/usr/bin/env bash
# Checks, commits, and pushes a student submission.

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT" || exit 1

JSON="results/report.json"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=============================================="
echo "  w10_context_lab — Submit"
echo "=============================================="

if [ ! -f "$JSON" ]; then
  echo -e "${RED}❌ $JSON missing. Run: bash check.sh${NC}"
  exit 1
fi

SCORE=$(grep -o '"score":[[:space:]]*[0-9]\+' "$JSON" | grep -o '[0-9]\+')
TOTAL=$(grep -o '"total":[[:space:]]*[0-9]\+' "$JSON" | grep -o '[0-9]\+')
FAILS=$(grep -o '"status":[[:space:]]*"fail"' "$JSON" | grep -c '' || true)

echo "report.json reports: ${SCORE:-0} / ${TOTAL:-?} passing"
if [ "${FAILS:-0}" -gt 0 ]; then
  echo -e "${YELLOW}⚠️  $FAILS required check(s) still fail.${NC}"
  read -r -p "Submit anyway? (y/N): " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }
fi

echo "📦 Preparing submission..."
# Stage each path on its own. A single `git add a b c` aborts and stages
# NOTHING if any one pathspec is missing -- with 2>/dev/null hiding the error,
# a student who deleted one file would silently submit an empty commit and be
# told "No changes -- already current".
for submit_path in AGENTS.md CLAUDE.md GEMINI.md rules/ HANDOFF.md token_report.md \
  codex-config.toml student.json results/ fastapi/ docker-compose.yml .env.example \
  .gitignore .github/; do
  [ -e "$submit_path" ] && git add "$submit_path" 2>/dev/null
done
true

if git diff --cached --quiet; then
  echo -e "${YELLOW}ℹ️  No changes — already current.${NC}"
else
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  if git commit -m "w10_context_lab submission — Score: ${SCORE}/${TOTAL} — ${timestamp}"; then
    echo -e "${GREEN}✅ Committed.${NC}"
  else
    echo -e "${RED}❌ git commit failed — nothing was submitted.${NC}"
    echo "If it says 'Author identity unknown', run:"
    echo "  git config --global user.name \"Your Name\""
    echo "  git config --global user.email you@example.com"
    echo "then rerun bash submit.sh."
    exit 1
  fi
fi

echo "⬆️  Pushing to GitHub..."
branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" != "main" ]; then
  echo -e "${YELLOW}⚠️  You are on '$branch' — the CI grader runs on main only."
  echo -e "   Merge to main (or switch: git switch main) and submit from there.${NC}"
fi
push_log=$(mktemp)
if git push -u origin "$branch" > "$push_log" 2>&1; then
  cat "$push_log"
  rm -f "$push_log"
  echo -e "${GREEN}🎉 Submitted! Score: ${SCORE} / ${TOTAL}${NC}"
  echo "Check the Actions tab in GitHub."
else
  cat "$push_log"
  echo -e "${RED}❌ Push failed — nothing was submitted.${NC}"
  if grep -qE 'fetch first|non-fast-forward|rejected' "$push_log"; then
    echo "The remote is ahead of you — CI commits your graded results back to"
    echo "your repo, so this is normal. Pull those commits, then submit again:"
    echo "  git pull --rebase origin $branch && bash submit.sh"
  elif grep -qi 'workflow' "$push_log"; then
    echo "Run: gh auth refresh -h github.com -s workflow"
  fi
  rm -f "$push_log"
  exit 1
fi
