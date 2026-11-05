"""Server tests. Firebase and Claude are mocked; run with:  python -m pytest -q"""
from __future__ import annotations

import json
import os
import sys
from unittest import mock

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import ai  # noqa: E402
import discover  # noqa: E402
import fetch  # noqa: E402
import orgs  # noqa: E402


# ── Billing maths ────────────────────────────────────────────────────

def test_bill_caps_seat_days_per_member():
    days = [{"seats": {"a": True, "b": True}, "inputTokens": 1_000_000, "outputTokens": 100_000, "requests": 5}]
    days += [{"seats": {"a": True}} for _ in range(29)]  # a is active 30 days, b once
    bill = orgs.bill_for(days)
    assert bill["activeMembers"] == 2
    assert bill["seatDays"] == 31
    # a: 30 * 0.40 = 12.00 capped at 8.00; b: 0.40
    assert bill["seatCostUsd"] == pytest.approx(8.40)
    # 1M input * $4 + 0.1M output * $20 = 4 + 2
    assert bill["aiCostUsd"] == pytest.approx(6.00)
    assert bill["totalUsd"] == pytest.approx(14.40)


def test_empty_month_costs_nothing():
    assert orgs.bill_for([])["totalUsd"] == 0


# ── SSRF guard ───────────────────────────────────────────────────────

@pytest.mark.parametrize("url", [
    "http://127.0.0.1/a.pdf", "http://localhost/a.pdf", "http://10.0.0.5/a.pdf",
    "http://169.254.169.254/latest/meta-data", "file:///etc/passwd", "ftp://example.com/a.pdf",
])
def test_fetch_blocks_private_and_odd_urls(url):
    with pytest.raises(fetch.UnsafeUrl):
        fetch.fetch_pdf(url)


def test_fetch_rejects_non_pdf_and_oversize():
    class Resp:
        status_code = 200
        is_redirect = False
        def __init__(self, body, length=None):
            self.body = body
            self.headers = {"Content-Length": str(length if length is not None else len(body))}
        def iter_content(self, n):
            yield self.body
        def close(self):
            pass

    with mock.patch.object(fetch, "_check_host"), mock.patch.object(fetch.requests, "get", return_value=Resp(b"<html>")):
        with pytest.raises(ValueError, match="not a PDF"):
            fetch.fetch_pdf("https://example.com/x")
    with mock.patch.object(fetch, "_check_host"), mock.patch.object(fetch.requests, "get", return_value=Resp(b"%PDF", 10**9)):
        with pytest.raises(ValueError, match="too large"):
            fetch.fetch_pdf("https://example.com/x")
    with mock.patch.object(fetch, "_check_host"), mock.patch.object(fetch.requests, "get", return_value=Resp(b"%PDF-1.7 ok")):
        assert fetch.fetch_pdf("https://example.com/x").startswith(b"%PDF")


# ── Chat shaping ─────────────────────────────────────────────────────

def test_build_messages_alternates_and_attaches_context():
    ctx = [{"type": "text", "text": "<library/>"}]
    history = [
        {"role": "assistant", "text": "hello"},       # dropped: must start with user
        {"role": "user", "text": "a"},
        {"role": "user", "text": "b"},                # merged
        {"role": "assistant", "text": "c"},
        {"role": "user", "text": "d"},
        {"role": "system", "text": "ignore me"},      # unknown role dropped
    ]
    out = ai.build_messages(history, ctx)
    assert [m["role"] for m in out] == ["user", "assistant", "user"]
    assert out[0]["content"][0] == ctx[0]
    assert out[0]["content"][1]["text"] == "a\n\nb"


def test_build_messages_requires_trailing_user_turn():
    assert ai.build_messages([{"role": "user", "text": "q"}, {"role": "assistant", "text": "a"}], []) == []


def test_system_prompt_adapts_to_edition_and_voice():
    s = ai.system_prompt("concise", "students", voice=True)
    assert "student" in s and "read aloud" in s and "concise" in s


# ── arXiv parsing ────────────────────────────────────────────────────

@pytest.mark.parametrize("text,expected", [
    ("https://arxiv.org/abs/1706.03762v7", "1706.03762v7"),
    ("arXiv: 2401.01234", "2401.01234"),
    ("https://arxiv.org/pdf/2310.06825.pdf", "2310.06825"),
    ("hep-th/9901001", "hep-th/9901001"),
    ("not a paper", None),
])
def test_parse_arxiv_id(text, expected):
    assert discover.parse_arxiv_id(text) == expected


def test_s2_reference_for_saved_items():
    assert discover.s2_key_for("arxiv", "1706.03762v7") == "arXiv:1706.03762"
    assert discover.s2_key_for("semantic_scholar", "abc") == "abc"
    assert discover.s2_key_for("openalex", "W1") is None


# ── Routes (auth, AI and Firestore mocked) ───────────────────────────

@pytest.fixture()
def client():
    with mock.patch("app.init_firebase"):
        import app as app_module
        flask_app = app_module.create_app()
    flask_app.testing = True
    with mock.patch("security.verify_token", return_value={"uid": "u1"}), \
         mock.patch.object(orgs, "user_profile", return_value={"edition": "students"}), \
         mock.patch.object(orgs, "check_allowance", return_value=None), \
         mock.patch.object(orgs, "record_usage") as rec:
        c = flask_app.test_client()
        c.recorded = rec
        yield c


AUTH = {"Authorization": "Bearer t"}


def test_health_and_pricing(client):
    assert client.get("/health").get_json()["status"] == "ok"
    p = client.get("/pricing").get_json()["pricing"]
    assert p["students"]["price"] == 0 and p["researchers"]["price"] == 0
    assert p["enterprise"]["seatDayUsd"] > 0


def test_ai_routes_require_sign_in(client):
    with mock.patch("security.verify_token", return_value=None):
        assert client.post("/pinda", json={}, headers=AUTH).status_code == 401
    assert client.post("/reports/draft", json={}).status_code == 401


def test_pinda_streams_and_meters_usage(client):
    def fake_stream(**kw):
        kw["usage"].update(input=120, output=30)
        assert "student" in kw["system"]
        yield ai.sse({"type": "delta", "text": "Hi"})
        yield ai.sse({"type": "done"})

    with mock.patch.object(ai, "build_context", return_value=[]), mock.patch.object(ai, "stream_text", side_effect=fake_stream):
        r = client.post("/pinda", headers=AUTH, json={"context": {"scope": "general"}, "messages": [{"role": "user", "text": "hey"}]})
        body = r.get_data(as_text=True)
    assert r.mimetype == "text/event-stream"
    events = [json.loads(line[5:]) for line in body.splitlines() if line.startswith("data:")]
    assert events == [{"type": "delta", "text": "Hi"}, {"type": "done"}]
    client.recorded.assert_called_once_with("u1", "pinda", 120, 30)


def test_pinda_rejects_unknown_scope(client):
    r = client.post("/pinda", headers=AUTH, json={"context": {"scope": "everyone"}, "messages": [{"role": "user", "text": "q"}]})
    assert r.status_code == 400


def test_allowance_exhausted_returns_429(client):
    with mock.patch.object(orgs, "check_allowance", return_value="limit"):
        r = client.post("/pinda", headers=AUTH, json={"messages": [{"role": "user", "text": "q"}]})
    assert r.status_code == 429


def test_report_needs_sources(client):
    assert client.post("/reports/draft", headers=AUTH, json={"kind": "summary"}).status_code == 400


def test_report_streams_from_selected_sources(client):
    seen = {}

    def ctx(uid, scope, ctx_id, ids):
        seen.update(uid=uid, scope=scope, ids=ids)
        return [{"type": "text", "text": "<library/>"}]

    def fake_stream(**kw):
        kw["usage"].update(input=1, output=1)
        yield ai.sse({"type": "done"})

    with mock.patch.object(ai, "build_context", side_effect=ctx), mock.patch.object(ai, "stream_text", side_effect=fake_stream):
        r = client.post("/reports/draft", headers=AUTH, json={"kind": "literature_review", "itemIds": ["a", "b"]})
        r.get_data()
    assert seen == {"uid": "u1", "scope": "selection", "ids": ["a", "b"]}


def test_arxiv_route(client):
    with mock.patch("app.arxiv_by_id", return_value={"id": "1706.03762", "title": "Attention"}), \
         mock.patch("app.cached", side_effect=lambda key, fn: fn()):
        r = client.get("/arxiv?ref=https://arxiv.org/abs/1706.03762")
    assert r.get_json()["paper"]["title"] == "Attention"
    assert client.get("/arxiv?ref=hello").status_code == 400


def test_pdf_import_blocks_internal_urls(client):
    r = client.post("/pdf/import", headers=AUTH, json={"url": "http://169.254.169.254/x.pdf", "itemId": "abc123"})
    assert r.status_code == 400


def test_org_errors_map_to_status(client):
    with mock.patch.object(orgs, "get_org", side_effect=orgs.OrgError("You're not in an organisation.", 404)):
        r = client.get("/orgs/me", headers=AUTH)
    assert r.status_code == 404 and "organisation" in r.get_json()["error"]


def test_rating_validation(client):
    with mock.patch.object(orgs, "rate_paper", side_effect=orgs.OrgError("Rate from 1 to 5 stars.")):
        assert client.post("/ratings", headers=AUTH, json={"key": "arxiv:1", "stars": 9}).status_code == 400
    assert client.post("/ratings", headers=AUTH, json={"key": "arxiv:1", "stars": "x"}).status_code == 400


def test_room_join_validates_code(client):
    assert client.post("/rooms/join", headers=AUTH, json={"code": "abc"}).status_code == 400


# ── Admin dashboard and developer API ────────────────────────────────

import hashlib as _hashlib  # noqa: E402
import time as _time  # noqa: E402

import devapi  # noqa: E402
import flags  # noqa: E402
import staff as staff_mod  # noqa: E402

ADMIN_ENV = {
    "ADMIN_USERNAME": "founder-anthony",
    "ADMIN_PASSWORD_HASH": staff_mod.hash_password("Correct-Horse-9!"),
    "ADMIN_KEY": "k" * 24,
    "SESSION_SECRET": "s" * 40,
    "DEV_API_SECRET": "d" * 40,
}


@pytest.fixture()
def admin_client():
    with mock.patch.dict(os.environ, ADMIN_ENV), mock.patch("app.init_firebase"), \
         mock.patch.object(staff_mod.Staff, "_read_lock", return_value={}), \
         mock.patch.object(staff_mod.Staff, "_write_lock"):
        import app as app_module
        flask_app = app_module.create_app()
        flask_app.testing = True
        yield flask_app.test_client()


def _login(c):
    r = c.post("/admin/api/login", json={"username": "founder-anthony", "password": "Correct-Horse-9!"})
    assert r.status_code == 200
    return r.get_json()["token"]


def test_admin_page_is_served_with_strict_headers(admin_client):
    r = admin_client.get("/admin")
    assert r.status_code == 200 and b"DSCVR Admin" in r.data
    assert "frame-ancestors 'none'" in r.headers["Content-Security-Policy"]
    assert r.headers["Cache-Control"] == "no-store"


def test_admin_login_rejects_wrong_password(admin_client):
    r = admin_client.post("/admin/api/login", json={"username": "founder-anthony", "password": "nope"})
    assert r.status_code == 401 and r.get_json()["error"] == "bad_credentials"
    r = admin_client.post("/admin/api/login", json={"username": "someone-else", "password": "Correct-Horse-9!"})
    assert r.status_code == 401


def test_admin_api_needs_session_and_key(admin_client):
    assert admin_client.get("/admin/api/overview").status_code == 401
    token = _login(admin_client)
    auth = {"Authorization": "Bearer " + token}
    r = admin_client.get("/admin/api/ping", headers={**auth, "X-Admin-Key": "wrong"})
    assert r.status_code == 401 and r.get_json()["error"] == "bad_admin_key"
    r = admin_client.get("/admin/api/ping", headers={**auth, "X-Admin-Key": "k" * 24})
    assert r.status_code == 200 and r.get_json()["username"] == "founder-anthony"
    assert admin_client.get("/admin/api/ping", headers={"Authorization": "Bearer forged", "X-Admin-Key": "k" * 24}).status_code == 401


def test_admin_flags_validate_limit(admin_client):
    h = {"Authorization": "Bearer " + _login(admin_client), "X-Admin-Key": "k" * 24}
    assert admin_client.post("/admin/api/flags", json={"freeDailyAi": 5000}, headers=h).status_code == 400
    with mock.patch.object(flags, "update", return_value={"freeDailyAi": 10, "shared": True}) as up:
        r = admin_client.post("/admin/api/flags", json={"freeDailyAi": 10}, headers=h)
    assert r.status_code == 200 and up.call_args[0][0] == {"freeDailyAi": 10}


def _signed(c, method, path, body=None, secret="d" * 40, ts=None, nonce=None):
    raw = json.dumps(body).encode() if body is not None else b""
    ts = ts or str(int(_time.time()))
    nonce = nonce or os.urandom(12).hex()
    sig = devapi.sign(secret, method, path, ts, nonce, raw)
    headers = {"X-Dev-Time": ts, "X-Dev-Nonce": nonce, "X-Dev-Sig": sig, "Content-Type": "application/json"}
    return c.open(path, method=method, data=raw if body is not None else None, headers=headers)


def test_dev_api_refuses_unsigned_bad_and_replayed(admin_client):
    assert admin_client.get("/internal/dev/diag").status_code == 401
    assert _signed(admin_client, "GET", "/internal/dev/diag", secret="x" * 40).status_code == 401
    old = str(int(_time.time()) - 600)
    assert _signed(admin_client, "GET", "/internal/dev/diag", ts=old).status_code == 401
    nonce = os.urandom(12).hex()
    assert _signed(admin_client, "GET", "/internal/dev/diag", nonce=nonce).status_code == 200
    assert _signed(admin_client, "GET", "/internal/dev/diag", nonce=nonce).status_code == 401


def test_dev_api_diag_reports_config_without_secrets(admin_client):
    d = _signed(admin_client, "GET", "/internal/dev/diag").get_json()
    assert d["checks"]["adminKeyStrong"] and d["checks"]["sessionSecretStrong"]
    assert "metrics" in d and "requests" in d["metrics"]
    text = json.dumps(d)
    assert "k" * 24 not in text and "d" * 40 not in text


def test_dev_api_is_off_without_a_secret():
    env = {**ADMIN_ENV, "DEV_API_SECRET": ""}
    with mock.patch.dict(os.environ, env), mock.patch("app.init_firebase"):
        import app as app_module
        c = app_module.create_app().test_client()
        assert c.get("/internal/dev/diag").status_code == 404


def test_maintenance_blocks_ai_and_writes(client):
    with mock.patch.object(flags, "get", return_value={**flags.DEFAULTS, "maintenance": {"on": True, "scope": "all", "message": "Back soon"}}):
        r = client.post("/pinda", json={"messages": [{"role": "user", "text": "hi"}]}, headers=AUTH)
        assert r.status_code == 503 and r.get_json()["error"] == "Back soon"
        assert client.post("/ratings", json={"key": "arxiv:1", "stars": 5}, headers=AUTH).status_code == 503
        assert client.get("/health").status_code == 200


def test_ai_pause_blocks_only_ai(client):
    with mock.patch.object(flags, "get", return_value={**flags.DEFAULTS, "aiPaused": True}):
        assert client.post("/pinda", json={}, headers=AUTH).status_code == 503
        assert client.post("/ratings", json={"key": "x", "stars": 9}, headers=AUTH).status_code == 400


def test_free_limit_override():
    with mock.patch.object(flags, "get", return_value={**flags.DEFAULTS, "freeDailyAi": 5}):
        assert flags.free_daily_ai(40) == 5
    with mock.patch.object(flags, "get", return_value=dict(flags.DEFAULTS)):
        assert flags.free_daily_ai(40) == 40
