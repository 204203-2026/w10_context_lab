"""Known-good floor app.

Your job in this lab is NOT to change this code. Your job is the agent
rules around it: AGENTS.md, permission profiles, symlinks, HANDOFF.md.
The app must stay green so the rules have something stable to describe.
"""

from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def home():
    return "Context Lab API"


@app.get("/api/me")
def me():
    return {
        "name": "Alice",
        "student_id": "640123456",
    }
