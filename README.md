# w10_context_lab

**This is the graded lab (Fri 18 Sep).** Not a lecture demo — everything here is
what `check.sh` and CI grade. It ships a working FastAPI floor app; your job is
the agent rules around it: AGENTS.md, permission profiles, symlinks, HANDOFF.md.

## Start here

1. **Use this template** → owner `204203-2026`, name `w10_context_lab-STUDENTID`, **Private**.
2. Pick where you work — **Track A** a local machine (lab machine or your own
   Ubuntu/Mac) or **Track B** your own VM over SSH. `TASKS.md` Step 0 sets up
   either; grading is identical. Install the **Prerequisites** listed at the
   top of `TASKS.md` first (on the VM, for Track B).
3. Clone your copy there, then:
   ```bash
   bash init.sh       # checks git, uv, codex, npx, VS Code, docker; creates .env from .env.example
   ```
4. Open `TASKS.md` and follow it top to bottom. It is the lab sheet.
TASKS.md is the only file you follow; this README is just how to get in the door.
