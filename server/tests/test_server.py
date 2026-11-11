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
    client.recorded.assert_called_once_with("u1", "pinda", 120, 30, plans.FAST_MODEL)


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
    "ADMIN_TOTP_SECRET": "JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP",
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


TOTP = ADMIN_ENV["ADMIN_TOTP_SECRET"]


def _code(offset=0):
    from passwords import totp_at
    return totp_at(TOTP, int(_time.time() // 30) + offset)


def _login(c, offset=0):
    r = c.post("/admin/api/login", json={"username": "founder-anthony", "password": "Correct-Horse-9!"})
    assert r.status_code == 200 and r.get_json()["totpRequired"] is True
    r = c.post("/admin/api/totp", json={"token": r.get_json()["token"], "code": _code(offset)})
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


def test_admin_api_needs_a_full_session(admin_client):
    assert admin_client.get("/admin/api/overview").status_code == 401
    # a right password alone only reaches the code step, never the dashboard
    pw = admin_client.post("/admin/api/login", json={"username": "founder-anthony", "password": "Correct-Horse-9!"}).get_json()["token"]
    assert admin_client.get("/admin/api/ping", headers={"Authorization": "Bearer " + pw}).status_code == 401
    token = _login(admin_client)
    r = admin_client.get("/admin/api/ping", headers={"Authorization": "Bearer " + token})
    assert r.status_code == 200 and r.get_json()["username"] == "founder-anthony"
    assert admin_client.get("/admin/api/ping", headers={"Authorization": "Bearer forged"}).status_code == 401


def test_admin_code_step(admin_client):
    pw = admin_client.post("/admin/api/login", json={"username": "founder-anthony", "password": "Correct-Horse-9!"}).get_json()["token"]
    bad = admin_client.post("/admin/api/totp", json={"token": pw, "code": "000000"})
    assert bad.status_code == 401 and bad.get_json()["error"] == "bad_code"
    assert admin_client.post("/admin/api/totp", json={"token": pw, "code": "12345"}).status_code == 401
    assert admin_client.post("/admin/api/totp", json={"token": "forged", "code": _code()}).status_code == 401
    ok = admin_client.post("/admin/api/totp", json={"token": pw, "code": _code()})
    assert ok.status_code == 200
    # the same code cannot be used twice
    again = admin_client.post("/admin/api/totp", json={"token": pw, "code": _code()})
    assert again.status_code == 401 and again.get_json()["error"] == "bad_code"
    # and a full token is not accepted as the code-step pass
    assert admin_client.post("/admin/api/totp", json={"token": ok.get_json()["token"], "code": _code(1)}).status_code == 401


def test_totp_matches_rfc6238_vectors():
    from passwords import totp_at, totp_valid_secret, totp_verify
    rfc = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"  # "12345678901234567890"
    assert totp_at(rfc, 59 // 30) == "287082"
    assert totp_at(rfc, 1111111109 // 30) == "081804"
    assert totp_verify(rfc, "287082", now=59) == 1
    assert totp_verify(rfc, "287082", now=59 + 60) is None and totp_verify(rfc, "28708", now=59) is None
    assert totp_valid_secret(rfc) and not totp_valid_secret("short") and not totp_valid_secret("1" * 20)


def test_admin_is_off_without_totp_secret():
    env = {k: v for k, v in ADMIN_ENV.items() if k != "ADMIN_TOTP_SECRET"}
    with mock.patch.dict(os.environ, env, clear=False):
        os.environ.pop("ADMIN_TOTP_SECRET", None)
        s = staff_mod.Staff()
    assert not s.enabled and "ADMIN_TOTP_SECRET" in s.problem


def test_sessions_survive_without_session_secret():
    """Two workers with no SESSION_SECRET must agree, or the dashboard bounces you back to sign-in."""
    env = {**ADMIN_ENV, "SESSION_SECRET": ""}
    with mock.patch.dict(os.environ, env):
        a, b = staff_mod.Staff(), staff_mod.Staff()
        token, _ = a._token("full", 60)
        assert b.session(token) == "founder-anthony"
    with mock.patch.dict(os.environ, {**env, "ADMIN_PASSWORD_HASH": "", "ADMIN_PASSWORD": "Another-Pass-77!"}):
        a, b = staff_mod.Staff(), staff_mod.Staff()  # a plain password is salted per worker; sessions must not depend on that
        token, _ = a._token("full", 60)
        assert b.session(token) == "founder-anthony"


def test_admin_shows_what_failed_instead_of_a_blank_500(admin_client):
    h = {"Authorization": "Bearer " + _login(admin_client)}
    with mock.patch("admin._db", side_effect=RuntimeError("firestore says no")):
        r = admin_client.get("/admin/api/users", headers=h)
    assert r.status_code == 500 and r.get_json()["error"] == "server_error"
    assert "RuntimeError: firestore says no" in r.get_json()["message"]


def test_admin_flags_validate_limit(admin_client):
    h = {"Authorization": "Bearer " + _login(admin_client)}
    assert admin_client.post("/admin/api/flags", json={"freeDailyUsd": 50}, headers=h).status_code == 400
    with mock.patch.object(flags, "update", return_value={"freeDailyUsd": 0.2, "shared": True}) as up:
        r = admin_client.post("/admin/api/flags", json={"freeDailyUsd": 0.2}, headers=h)
    assert r.status_code == 200 and up.call_args[0][0] == {"freeDailyUsd": 0.2}


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
    with mock.patch.object(flags, "get", return_value={**flags.DEFAULTS, "freeDailyUsd": 0.25}):
        assert flags.free_daily_usd() == 0.25
    with mock.patch.object(flags, "get", return_value=dict(flags.DEFAULTS)):
        assert flags.free_daily_usd() is None



# ── Plans, usage meter and Paystack ──────────────────────────────────

import billing  # noqa: E402
import hashlib as _h  # noqa: E402
import hmac as _hm  # noqa: E402
import plans  # noqa: E402


def test_plan_of_handles_expiry_and_orgs():
    from datetime import datetime, timedelta, timezone
    now = datetime.now(timezone.utc)
    assert plans.plan_of({}) == "free"
    assert plans.plan_of({"orgId": "o1", "plan": "max"}) == "enterprise"
    assert plans.plan_of({"plan": "research_plus", "planStatus": "active"}) == "research_plus"
    assert plans.plan_of({"plan": "max", "planStatus": "cancelled", "planEndsAt": now + timedelta(days=3)}) == "max"
    assert plans.plan_of({"plan": "max", "planStatus": "cancelled", "planEndsAt": now - timedelta(minutes=1)}) == "free"
    assert plans.plan_of({"plan": "max", "planStatus": "past_due", "planEndsAt": now - timedelta(days=1)}) == "max"  # grace
    assert plans.plan_of({"plan": "made_up"}) == "free"


def test_models_and_costs_by_plan():
    assert plans.model_for("free", "chat") == plans.FAST_MODEL
    assert plans.model_for("research_plus", "chat") == plans.FAST_MODEL
    assert plans.model_for("research_plus", "heavy") == plans.BEST_MODEL
    assert plans.model_for("max", "chat") == plans.BEST_MODEL
    assert plans.model_for("enterprise", "chat") == plans.BEST_MODEL
    assert plans.cost_usd(plans.BEST_MODEL, 1_000_000, 0) > plans.cost_usd(plans.FAST_MODEL, 1_000_000, 0)
    for p in plans.PAID:  # AI budget stays under the price, so every plan has margin
        assert plans.PLANS[p]["monthlyUsd"] < plans.PLANS[p]["priceUsd"]


class _Doc:
    def __init__(self, data):
        self._d = data

    def get(self, **_):
        return mock.Mock(to_dict=lambda: self._d, exists=True)


def _fake_db(usage, profile=None):
    db = mock.Mock()
    db.document.side_effect = lambda path: _Doc(usage if path.endswith("meta/usage") else (profile or {}))
    return db


def test_allowance_blocks_when_budget_is_used():
    today = orgs._today()
    month = orgs._month()
    with mock.patch.object(orgs, "user_profile", return_value={}), mock.patch.object(flags, "get", return_value=dict(flags.DEFAULTS)), \
         mock.patch.object(orgs, "_db", return_value=_fake_db({"day": today, "month": month, "dayCost": 0.01, "monthCost": 0.2})):
        assert orgs.check_allowance("u1") is None
    with mock.patch.object(orgs, "user_profile", return_value={}), mock.patch.object(flags, "get", return_value=dict(flags.DEFAULTS)), \
         mock.patch.object(orgs, "_db", return_value=_fake_db({"day": today, "month": month, "dayCost": 0.5, "monthCost": 0.6})):
        err = orgs.check_allowance("u1")
        assert err["code"] == "usage_limit" and err["window"] == "day" and "Upgrade" in err["error"]
    with mock.patch.object(orgs, "user_profile", return_value={"plan": "max", "planStatus": "active"}), \
         mock.patch.object(flags, "get", return_value=dict(flags.DEFAULTS)), \
         mock.patch.object(orgs, "_db", return_value=_fake_db({"day": today, "month": month, "dayCost": 0.5, "monthCost": 0.6})):
        assert orgs.check_allowance("u1") is None
    with mock.patch.object(orgs, "user_profile", return_value={"orgId": "o"}), mock.patch.object(flags, "get", return_value=dict(flags.DEFAULTS)):
        assert orgs.check_allowance("u1") is None


def test_ai_routes_return_structured_limit(client):
    err = {"error": "You've used today's Pinda usage on Free.", "code": "usage_limit", "plan": "free", "window": "day", "resetsAt": "x"}
    with mock.patch.object(orgs, "check_allowance", return_value=err):
        r = client.post("/pinda", json={"messages": [{"role": "user", "text": "hi"}]}, headers=AUTH)
    assert r.status_code == 429 and r.get_json()["code"] == "usage_limit"


def test_checkout_is_off_without_paystack(client):
    with mock.patch.dict(os.environ, {"PAYSTACK_SECRET_KEY": ""}):
        r = client.post("/billing/checkout", json={"plan": "max"}, headers=AUTH)
    assert r.status_code == 503


def test_paystack_webhook_checks_signature_and_activates(client):
    secret = "sk_test_" + "x" * 30
    env = {"PAYSTACK_SECRET_KEY": secret}
    event = {"event": "charge.success", "data": {"metadata": {"uid": "u42", "plan": "research_plus"}, "customer": {"customer_code": "CUS_1"}}}
    raw = json.dumps(event).encode()
    sig = _hm.new(secret.encode(), raw, _h.sha512).hexdigest()
    with mock.patch.dict(os.environ, env):
        assert client.post("/billing/paystack/webhook", data=raw, headers={"X-Paystack-Signature": "0" * 128, "Content-Type": "application/json"}).status_code == 401
        db = mock.Mock()
        with mock.patch.object(billing, "_db", return_value=db):
            r = client.post("/billing/paystack/webhook", data=raw, headers={"X-Paystack-Signature": sig, "Content-Type": "application/json"})
    assert r.status_code == 200 and r.get_json()["result"] == "ok"
    written = db.document.return_value.set.call_args[0][0]
    assert written["plan"] == "research_plus" and written["planStatus"] == "active"


def test_stream_falls_back_when_fast_model_is_missing():
    class NotFound(Exception):
        status_code = 404

    calls = []

    class FakeStream:
        def __init__(self, model):
            self.model = model
            self.text_stream = iter(["ok"])

        def __enter__(self):
            if self.model != ai.MODEL:
                raise NotFound("model: claude-haiku-x not found")
            return self

        def __exit__(self, *a):
            return False

        def get_final_message(self):
            return mock.Mock(usage=mock.Mock(input_tokens=5, output_tokens=2, cache_read_input_tokens=0, cache_creation_input_tokens=0))

    fake = mock.Mock()
    fake.messages.stream.side_effect = lambda **kw: (calls.append(kw["model"]), FakeStream(kw["model"]))[1]
    usage = {}
    with mock.patch.object(ai, "client", return_value=fake):
        out = "".join(ai.stream_text(system="s", messages=[], max_tokens=10, usage=usage, model="claude-haiku-x"))
    assert calls == ["claude-haiku-x", ai.MODEL] and '"done"' in out and usage["model"] == ai.MODEL


def test_failure_reasons_are_specific():
    class E(Exception):
        def __init__(self, msg, code):
            super().__init__(msg)
            self.status_code = code
    assert "out of credit" in ai.failure_reason(E("Your credit balance is too low", 400))
    assert "key" in ai.failure_reason(E("invalid x-api-key", 401))
    assert "busy" in ai.failure_reason(E("overloaded", 529))


# ── Professional sources ─────────────────────────────────────────────

class _Resp:
    def __init__(self, data=None, text="", content=b""):
        self._data, self.text, self.content, self.status_code = data, text, content or text.encode(), 200
    def json(self):
        return self._data
    def raise_for_status(self):
        pass


def test_europepmc_normalises_results_and_builds_queries():
    data = {"resultList": {"result": [{
        "id": "123", "source": "MED", "pmid": "123", "doi": "10.1/x", "title": "Malaria in children.",
        "authorString": "Okafor A, Bello B.", "pubYear": "2025", "abstractText": "<h4>Background</h4>Text here",
        "journalInfo": {"journal": {"title": "Lancet"}}, "isOpenAccess": "Y",
        "pubTypeList": {"pubType": ["Journal Article", "Practice Guideline"]},
        "fullTextUrlList": {"fullTextUrl": [{"documentStyle": "pdf", "availabilityCode": "OA", "url": "https://x/p.pdf"}]},
    }]}}
    with mock.patch.object(discover.requests, "get", return_value=_Resp(data)) as get:
        papers = discover.search_europepmc("malaria", 5, "date", guidelines=True)
    q = get.call_args.kwargs["params"]["query"]
    assert "TITLE_ABS:(malaria)" in q and "guideline" in q and "FIRST_PDATE" in q
    p = papers[0]
    assert p["title"] == "Malaria in children" and p["authors"] == ["Okafor A", "Bello B"]
    assert p["venue"] == "Lancet" and p["pdfUrl"] == "https://x/p.pdf" and p["kind"] == "Practice Guideline"
    assert p["summary"] == "Background Text here" and p["url"] == "https://europepmc.org/article/MED/123"


UK_FEED = b"""<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom" xmlns:tna="https://caselaw.nationalarchives.gov.uk">
<entry><title>A v B</title><link href="https://caselaw.nationalarchives.gov.uk/uksc/2026/1" rel="alternate"/>
<link href="https://assets/x.pdf" rel="alternate" type="application/pdf"/><published>2026-01-02T00:00:00+00:00</published>
<author><name>United Kingdom Supreme Court</name></author><tna:identifier slug="uksc/2026/1" type="ukncn">[2026] UKSC 1</tna:identifier>
</entry></feed>"""


def test_uk_caselaw_reads_citation_court_and_pdf():
    with mock.patch.object(discover.requests, "get", return_value=_Resp(content=UK_FEED, text=UK_FEED.decode())):
        cases = discover.search_uk_caselaw("contract", 5)
    c = cases[0]
    assert c["title"] == "A v B" and c["citation"] == "[2026] UKSC 1" and c["court"] == "United Kingdom Supreme Court"
    assert c["pdfUrl"] == "https://assets/x.pdf" and c["year"] == 2026 and c["source"] == "uk_caselaw"


def test_discover_routes_new_sources(client):
    with mock.patch("app.search_europepmc", return_value=[{"title": "x"}]) as pmc, \
         mock.patch("app.search_uk_caselaw", return_value=[{"title": "y"}]) as uk:
        assert client.get("/discover?source=europepmc&q=asthma-test-1&type=guidelines").get_json()["papers"][0]["title"] == "x"
        assert pmc.call_args.args[3] is True
        assert client.get("/discover?source=uk_caselaw&q=tort-test-1").get_json()["papers"][0]["title"] == "y"


# ── Study tools ──────────────────────────────────────────────────────

def test_study_validates_and_cleans_quiz(client):
    raw = {"questions": [
        {"question": "Q1", "options": ["a", "b", "c", "d"], "answer": 2, "explanation": "e"},
        {"question": "Q2", "options": ["a", "b"], "answer": 0, "explanation": "bad: two options"},
        {"question": "Q3", "options": ["a", "b", "c", "d"], "answer": 7, "explanation": "bad index"},
    ]}
    with mock.patch.object(ai, "build_context", return_value=[{"type": "text", "text": "<library/>"}]), \
         mock.patch.object(ai, "complete", return_value=raw):
        r = client.post("/study", json={"itemId": "m1", "kind": "quiz"}, headers=AUTH)
    assert r.status_code == 200
    qs = r.get_json()["questions"]
    assert [q["question"] for q in qs] == ["Q1"]
    assert client.recorded.call_args.args[1] == "study"


def test_study_rejects_unknown_kind_and_missing_item(client):
    assert client.post("/study", json={"itemId": "m1", "kind": "essay"}, headers=AUTH).status_code == 400
    with mock.patch.object(ai, "build_context", return_value=[]):
        assert client.post("/study", json={"itemId": "nope", "kind": "brief"}, headers=AUTH).status_code == 404


def test_profession_shapes_the_system_prompt():
    assert "ratio decidendi" in ai.system_prompt("detailed", "students", profession="law")
    assert "never give a diagnosis" in ai.system_prompt("detailed", "students", profession="medicine")
    assert "ratio" not in ai.system_prompt("detailed", "students", profession="unknown")


# ── Alerts ───────────────────────────────────────────────────────────

class _FakeDoc:
    def __init__(self, store, path):
        self.store, self.path = store, path
    def get(self):
        d = self.store.get(self.path)
        return mock.Mock(to_dict=lambda: d, exists=d is not None)


class _FakeDB:
    def __init__(self):
        self.store, self.writes = {}, {}
    def document(self, path):
        return _FakeDoc(self.store, path)
    def batch(self):
        db = self
        class B:
            def set(self, ref, data, merge=False):
                db.writes[ref.path] = data
            def commit(self):
                db.store.update(db.writes)
        return B()


def test_alerts_first_run_is_quiet_then_only_new_items():
    import alerts
    db = _FakeDB()
    profile = {"alerts": {"enabled": True, "subjects": [{"label": "Nursing", "source": "europepmc", "query": "nursing"}]}}
    first = [{"source": "europepmc", "id": f"MED:{i}", "title": f"P{i}"} for i in range(3)]
    with mock.patch.dict(alerts.SOURCES, {"europepmc": lambda q, n: first}), mock.patch.object(discover, "cached", lambda k, f: f()):
        got = alerts.run_for_user("u1", profile, db)
    assert len(got) == 1  # first run: one per subject, the rest remembered as seen
    second = [{"source": "europepmc", "id": "MED:9", "title": "New"}] + first
    db.writes.clear()
    with mock.patch.dict(alerts.SOURCES, {"europepmc": lambda q, n: second}), mock.patch.object(discover, "cached", lambda k, f: f()):
        got = alerts.run_for_user("u1", profile, db)
    assert [p["title"] for p in got] == ["New"]
    assert any(k.startswith("users/u1/alerts/") for k in db.writes)


def test_alerts_off_does_nothing():
    import alerts
    assert alerts.run_for_user("u1", {"alerts": {"enabled": False}}, _FakeDB()) == []


def test_alerts_run_needs_the_cron_secret(client):
    with mock.patch.dict(os.environ, {"CRON_SECRET": "s3cret"}):
        assert client.post("/alerts/run").status_code == 403
        assert client.post("/alerts/run", headers={"X-Cron-Secret": "wrong"}).status_code == 403
        with mock.patch("alerts.run", return_value={"users": 0}):
            assert client.post("/alerts/run", headers={"X-Cron-Secret": "s3cret"}).status_code == 200
    with mock.patch.dict(os.environ, {"CRON_SECRET": ""}):
        assert client.post("/alerts/run", headers={"X-Cron-Secret": ""}).status_code == 403


# ── Pinda's identity and combined search ─────────────────────────────

def test_every_pinda_prompt_carries_its_identity():
    for prompt in (ai.system_prompt("detailed", "students"), ai.REPORT_SYSTEM, ai.STUDY_SYSTEM):
        assert "Your name is Pinda" in prompt
        assert "can't share more detail about the model" in prompt
        assert "Never claim to be human" in prompt
    assert "Ada" in ai.system_prompt("concise", None, user_name="Ada")


def test_chat_uses_first_name_from_profile(client):
    seen = {}
    def fake_stream(**kw):
        seen["system"] = kw["system"]
        yield ai.sse({"type": "done"})
    with mock.patch.object(orgs, "user_profile", return_value={"displayName": "Anthony Ude"}), \
         mock.patch.object(ai, "build_context", return_value=[]), mock.patch.object(ai, "stream_text", fake_stream):
        r = client.post("/pinda", json={"messages": [{"role": "user", "text": "who are you?"}]}, headers=AUTH)
        r.get_data()
    assert "The user's name is Anthony." in seen["system"] and "Your name is Pinda" in seen["system"]


def test_search_all_merges_duplicates_and_keeps_every_source_label():
    import sources
    a = {"title": "Malaria vaccine trial", "source": "openalex", "url": "https://doi.org/10.1/abc", "summary": ""}
    b = {"title": "Malaria Vaccine Trial.", "source": "crossref", "doi": "10.1/ABC", "summary": "Long abstract", "pdfUrl": "https://x/p.pdf"}
    c = {"title": "Unrelated", "source": "doaj", "summary": "x"}
    fake = {"openalex": lambda q, n: [a], "crossref": lambda q, n: [b], "doaj": lambda q, n: [c]}
    with mock.patch.dict(sources.SOURCES, fake, clear=True), mock.patch.object(discover, "cached", lambda k, f: f()):
        out = sources.search_all("malaria vaccine", 10)
    first = out["papers"][0]
    assert first["sources"] == ["openalex", "crossref"]
    assert first["summary"] == "Long abstract" and first["pdfUrl"] == "https://x/p.pdf" and first["openAccess"]
    assert len(out["papers"]) == 2 and out["sources"] == {"openalex": 1, "crossref": 1, "doaj": 1}


def test_search_all_survives_a_failing_source():
    import sources
    def boom(q, n):
        raise RuntimeError("429 Too Many Requests")
    fake = {"openalex": boom, "doaj": lambda q, n: [{"title": "Kept", "source": "doaj"}]}
    with mock.patch.dict(sources.SOURCES, fake, clear=True), mock.patch.object(discover, "cached", lambda k, f: f()):
        out = sources.search_all("x", 10)
    assert out["sources"]["openalex"] == "busy" and out["papers"][0]["title"] == "Kept"


def test_pdf_view_streams_pdf_and_blocks_private_urls(client):
    with mock.patch("app.fetch_pdf", return_value=b"%PDF-1.7 hello"):
        r = client.get("/pdf/view?url=https://arxiv.org/pdf/1706.03762", headers=AUTH)
    assert r.status_code == 200 and r.mimetype == "application/pdf" and r.data.startswith(b"%PDF")
    assert client.get("/pdf/view?url=http://127.0.0.1/x.pdf", headers=AUTH).status_code == 400
    assert client.get("/pdf/view?url=https://arxiv.org/x.pdf").status_code == 401


# ── Shared collections ───────────────────────────────────────────────

class _ShareDB:
    """Just enough Firestore for shares.resolve: documents and equality queries."""
    def __init__(self, docs):
        self.docs = docs
    def document(self, path):
        d = self.docs.get(path)
        return mock.Mock(get=lambda: mock.Mock(exists=d is not None, to_dict=lambda: d, id=path.rsplit("/", 1)[-1]))
    def collection(self, path):
        db = self
        class Q:
            def __init__(self, filters=()):
                self.filters = filters
            def where(self, field, op, value):
                return Q(self.filters + ((field, value),))
            def limit(self, n):
                return self
            def get(self):
                out = []
                for k, v in db.docs.items():
                    if k.startswith(path + "/") and "/" not in k[len(path) + 1:] and all(v.get(f) == val for f, val in self.filters):
                        out.append(mock.Mock(id=k.rsplit("/", 1)[-1], to_dict=lambda v=v: v))
                return out
        return Q()


def _share_docs(**link):
    return {
        "shares/L1": {"ownerId": "owner", "targetType": "category", "targetId": "c1", "permission": "fork", "active": True, **link},
        "users/owner": {"displayName": "Ada Lovelace", "email": "ada@example.com"},
        "users/owner/categories/c1": {"name": "Sepsis", "description": "Reading for the ward round"},
        "users/owner/topics/t1": {"categoryId": "c1", "name": "Fluids"},
        "users/owner/materials/m1": {"categoryId": "c1", "kind": "paper", "title": "Early goal-directed therapy",
                                     "url": "https://example.org/p", "pdfUrl": "https://example.org/p.pdf", "authors": ["Rivers E"]},
        "users/owner/materials/m2": {"categoryId": "c1", "kind": "pdf", "title": "My scan", "storagePath": "users/owner/m2.pdf",
                                     "url": "https://storage/secret?token=x", "pdfUrl": "https://storage/secret?token=x"},
        "users/owner/materials/m3": {"categoryId": "other", "kind": "note", "title": "Private elsewhere", "content": "no"},
    }


def test_share_returns_the_collection_without_private_files():
    import shares
    out = shares.resolve(_ShareDB(_share_docs()), "L1", "viewer")
    assert out["name"] == "Sepsis" and out["ownerName"] == "Ada" and out["canFork"] and not out["mine"]
    assert [i["title"] for i in out["items"]] == ["Early goal-directed therapy", "My scan"]
    scan = out["items"][1]
    assert scan["privateFile"] and "url" not in scan and "pdfUrl" not in scan
    assert "token" not in json.dumps(out) and "ada@example.com" not in json.dumps(out)
    assert out["topics"] == [{"id": "t1", "name": "Fluids", "description": ""}]


@pytest.mark.parametrize("link,status", [
    ({"active": False}, 404),
    ({"expiresAt": "2020-01-01T00:00:00"}, 404),
    ({"password": "x"}, 403),
    ({"allowedEmails": ["someone@else.com"]}, 403),
    ({"targetId": "gone"}, 404),
])
def test_share_refuses_dead_or_restricted_links(link, status):
    import shares
    with pytest.raises(shares.ShareError) as e:
        shares.resolve(_ShareDB(_share_docs(**link)), "L1", "viewer", "me@example.com")
    assert e.value.status == status


def test_share_missing_link_is_404():
    import shares
    with pytest.raises(shares.ShareError):
        shares.resolve(_ShareDB({}), "nope", "viewer")


def test_share_endpoint_needs_sign_in_and_a_clean_id(client):
    assert client.get("/shares/L1").status_code == 401
    assert client.get("/shares/bad-id!", headers=AUTH).status_code == 404


# ── Account deletion ─────────────────────────────────────────────────

def test_account_delete_needs_confirmation(client):
    assert client.post("/account/delete", headers=AUTH, json={}).status_code == 400


def test_account_delete_removes_everything():
    import account
    calls = []
    profile = {"paystack": {"subscriptionCode": "SUB_1"}, "orgId": "o1"}
    rating_paper = mock.Mock()
    rating_paper.get.return_value.to_dict.return_value = {"count": 3, "sum": 12}
    rating = mock.Mock()
    rating.to_dict.return_value = {"stars": 5, "uid": "u1"}
    rating.reference.parent.parent = rating_paper
    share = mock.Mock()
    db = mock.Mock()
    db.document.return_value.get.return_value.to_dict.return_value = profile
    db.collection.return_value.where.return_value.get.return_value = [share]
    db.collection_group.return_value.where.return_value.get.return_value = [rating]
    blob = mock.Mock()
    bucket = mock.Mock(list_blobs=mock.Mock(return_value=[blob, blob]))
    auth = mock.Mock()
    out = account.delete_everything("u1", db, bucket, auth,
                                    cancel_subscription=lambda uid: calls.append("cancel"),
                                    detach_org=lambda org, uid: calls.append(("detach", org)))
    assert calls == ["cancel", ("detach", "o1")]
    share.reference.delete.assert_called_once()
    rating_paper.set.assert_called_once_with({"count": 2, "sum": 7}, merge=True)
    assert blob.delete.call_count == 2
    db.recursive_delete.assert_called_once()
    auth.delete_user.assert_called_once_with("u1")
    assert out == {"subscription": "cancelled", "org": "left", "shares": 1, "ratings": 1, "files": 2}


# ── Blog, referrals, ratings, emails ─────────────────────────────────

def test_blog_slugify_and_validation():
    import blog
    assert blog.slugify("How to Write a Literature Review (2026)!") == "how-to-write-a-literature-review-2026"
    with mock.patch.object(blog, "_db"), mock.patch.object(blog, "revalidate"):
        with pytest.raises(blog.BlogError):
            blog.save_post({"title": "Hi"}, "me")
        with pytest.raises(blog.BlogError):
            blog.save_post({"title": "A real title", "date": "11/11/2026"}, "me")
        out = blog.save_post({"title": "A real title", "body": "Hello", "tags": "a, b", "published": True}, "me")
    assert out["slug"] == "a-real-title" and out["tags"] == ["a", "b"] and out["published"]


def test_blog_public_hides_drafts(client):
    import blog
    with mock.patch.object(blog, "get_post", return_value=None):
        assert client.get("/blog/posts/draft-post").status_code == 404
    with mock.patch.object(blog, "list_posts", return_value=[{"slug": "x"}]):
        assert client.get("/blog/posts").get_json() == {"posts": [{"slug": "x"}]}


def test_referral_boost_factor():
    import referrals
    from datetime import datetime, timedelta, timezone
    future = datetime.now(timezone.utc) + timedelta(days=3)
    past = datetime.now(timezone.utc) - timedelta(days=3)
    assert referrals.boost_factor({"boostUntil": future}) == referrals.BOOST
    assert referrals.boost_factor({"boostUntil": past}) == 1.0
    assert referrals.boost_factor({}) == 1.0


def test_referral_rules():
    import referrals
    from datetime import datetime, timedelta, timezone
    db = mock.Mock()
    db.document.return_value.get.return_value.to_dict.return_value = {"uid": "me"}
    with pytest.raises(referrals.ReferralError, match="Verify"):
        referrals.redeem("me", "ABC2345", False, None, db)
    with pytest.raises(referrals.ReferralError, match="first"):
        referrals.redeem("me", "ABC2345", True, datetime.now(timezone.utc) - timedelta(days=60), db)
    with pytest.raises(referrals.ReferralError, match="own"):
        referrals.redeem("me", "ABC2345", True, datetime.now(timezone.utc), db)


def test_boost_doubles_the_allowance():
    from datetime import datetime, timedelta, timezone
    profile = {"plan": "free", "boostUntil": datetime.now(timezone.utc) + timedelta(days=5)}
    usage = {"day": orgs._today(), "dayCost": 0.15, "month": orgs._month(), "monthCost": 0.2}
    db = mock.Mock()
    db.document.return_value.get.return_value.to_dict.return_value = usage
    with mock.patch.object(orgs, "user_profile", return_value=profile), mock.patch.object(orgs, "_db", return_value=db), \
         mock.patch("flags.free_daily_usd", return_value=None):
        assert orgs.check_allowance("u1") is None  # 0.15 is under the boosted 0.20
        profile["boostUntil"] = datetime.now(timezone.utc) - timedelta(days=1)
        assert orgs.check_allowance("u1")["code"] == "usage_limit"


def test_app_rating_validates_stars(client):
    with mock.patch("firebase_admin.firestore.client"):
        assert client.post("/feedback/rating", headers=AUTH, json={"stars": 9}).status_code == 400
        assert client.post("/feedback/rating", headers=AUTH, json={"stars": 4, "comment": "Great"}).status_code == 200


def test_unsubscribe_token_roundtrip():
    import mailer
    with mock.patch.dict(os.environ, {"SESSION_SECRET": "k"}), mock.patch.object(mailer, "get_firestore_client") as db:
        assert mailer.unsubscribe("u1", mailer.unsubscribe_token("u1"))
        assert not mailer.unsubscribe("u1", "nope")
        db.return_value.document.assert_called_once_with("users/u1")


def test_update_email_renders_markdown_and_unsubscribe():
    import mailer
    html_out = mailer.render("Hi", "## New\n\n- one\n- two\n\nSee [DSCVR](https://www.askpinda.com) **now**.", "Ada Lovelace", "https://x/unsub")
    assert "Hi Ada," in html_out and "<li" in html_out and "<strong>now</strong>" in html_out and "https://x/unsub" in html_out
