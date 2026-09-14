"""Tests for the floor app. They pass BEFORE you start - and stay passing.

These tests are the oracle your agent rules will point at: when your agent
changes code in Step 6, running them is how you check its work without
reading every line. A rules file that never mentions them is not done.
"""

from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_home_ok():
    r = client.get("/")
    assert r.status_code == 200


def test_me_has_name_and_id():
    r = client.get("/api/me")
    assert r.status_code == 200
    d = r.json()
    assert d["name"]
    assert d["student_id"]
