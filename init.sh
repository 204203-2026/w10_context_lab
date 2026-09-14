#!/usr/bin/env bash
# Week 10 lab (w10_context_lab) - one-shot workspace setup. Ubuntu and macOS.
# Deterministic: no rand(), no network beyond the optional uv install.

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT" || exit 1

echo "=============================================="
echo "  w10_context_lab - Initialize"
echo "=============================================="

missing=0

# git
if command -v git >/dev/null 2>&1; then
  echo "OK git: $(git --version)"
else
  echo "MISSING git - install Git, then rerun: bash init.sh"
  missing=$((missing + 1))
fi

# uv (install if missing)
uv_just_installed=false
if ! command -v uv >/dev/null 2>&1; then
  echo "SETUP uv missing - installing from astral.sh..."
  if command -v curl >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    PATH="$HOME/.local/bin:$PATH"
    uv_just_installed=true
  fi
fi
if command -v uv >/dev/null 2>&1; then
  echo "OK uv: $(uv --version)"
else
  echo "uv missing - run: curl -LsSf https://astral.sh/uv/install.sh | sh"
  missing=$((missing + 1))
fi

# codex CLI
if command -v codex >/dev/null 2>&1; then
  codex --version
else
  echo "MISSING codex - macOS: npm install -g @openai/codex / Ubuntu: sudo npm install -g @openai/codex (see TASKS.md Prerequisites)"
  missing=$((missing + 1))
fi

# npx (Step 3 needs it for the caveman skill; ships with npm/Node from cs111env)
if command -v npx >/dev/null 2>&1; then
  echo "OK npx: $(npx --version)"
else
  echo "MISSING npx - macOS: brew install node@24 / Ubuntu: sudo apt install -y nodejs npm (see TASKS.md Prerequisites)"
  missing=$((missing + 1))
fi

# VS Code (Track B: you edit from your laptop over Remote-SSH, so the VM needs none)
if command -v code >/dev/null 2>&1; then
  echo "OK code: installed"
elif [ -n "${SSH_CONNECTION:-}" ]; then
  echo "INFO code: not on this machine - fine over SSH (Track B): use VS Code Remote-SSH from your laptop"
else
  echo "MISSING code - macOS: brew install --cask visual-studio-code"
  echo "          Ubuntu: sudo snap install code --classic"
  missing=$((missing + 1))
fi

# docker (Steps 3-6 + check 7 all need it)
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    echo "OK docker: $(docker --version)"
  else
    echo "MISSING docker daemon not running - start Docker Desktop (macOS) or sudo systemctl start docker (Linux), then rerun: bash init.sh"
    missing=$((missing + 1))
  fi
else
  echo "MISSING docker - macOS: Docker Desktop / Ubuntu: sudo apt install docker.io docker-compose-v2"
  missing=$((missing + 1))
fi

# .env (the file the agent must NEVER read in Step 1)
if [ ! -f .env ]; then
  cp .env.example .env
  echo "OK .env created from .env.example"
else
  echo "OK .env already present (left as-is)"
fi

# rtk + caveman are installed in Step 3, not here — but print the right line
# for this OS so nobody has to hunt for it (codex audit M8).
echo ""
echo "INFO rtk + caveman install in Step 3. The right line for this OS:"
if [ "$(uname -s)" = "Darwin" ]; then
  echo "  brew install rtk"
else
  echo "  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"
fi
echo "  rtk init -g --codex"
echo "  npx skills add JuliusBrussee/caveman --skill '*' -a codex -g --yes"

echo ""
if [ "$missing" -eq 0 ]; then
  echo "OK Tools ready. Open TASKS.md and begin Step 0."
  exit 0
fi
echo "FAILED $missing tool check(s). Fix them before Step 0."
exit 1
