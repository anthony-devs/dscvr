"""The server's side of the developer console. Nothing else may call it.

Every request must be signed with DEV_API_SECRET (HMAC-SHA256 over the method,
path, a timestamp, a one-time nonce and the body hash). Unsigned, stale,
replayed or wrongly signed requests get a plain 401, and the whole API is off
(404) unless a 32+ character secret is set. Optionally limit it to DEV_ALLOWED_IPS.

It returns health numbers, recent errors, config sanity checks, maintenance
mode and migrations. It never returns secrets, tokens or user data.
"""
from __future__ import annotations

import hashlib
import hmac
import os
import platform
import time
from collections import OrderedDict, deque

from flask import Blueprint, current_app, jsonify, request

import flags
import migrations
from metrics import is_quota, metrics
from security import get_firestore_client

WINDOW_SECONDS = 60
PREFIX = "/internal/dev"


class DevError(Exception):
    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status = status


def sign(secret: str, method: str, path_qs: str, ts: str, nonce: str, body: bytes) -> str:
    msg = "\n".join([method.upper(), path_qs, ts, nonce, hashlib.sha256(body).hexdigest()])
    return hmac.new(secret.encode(), msg.encode(), hashlib.sha256).hexdigest()


def make_devapi(staff) -> Blueprint:
    bp = Blueprint("devapi", __name__)
    nonces: OrderedDict = OrderedDict()
    fails: dict[str, deque] = {}

    def secret() -> str:
        return os.getenv("DEV_API_SECRET", "")

    @bp.errorhandler(DevError)
    def _err(e: DevError):
        return jsonify(error="unauthorized" if e.status == 401 else "error", message=str(e)), e.status

    @bp.before_request
    def guard():
        if len(secret()) < 32:
            raise DevError(404, "Not found.")
        ip = request.remote_addr or ""
        q = fails.setdefault(ip, deque())
        now = time.monotonic()
        while q and now - q[0] > 60:
            q.popleft()
        if len(q) >= 20:
            raise DevError(429, "Too many bad requests.")

        def deny(why: str):
            q.append(now)
            current_app.logger.warning("dev api refused (%s) from %s %s", why, ip, request.path)
            raise DevError(401, "Not allowed.")

        allowed = [x.strip() for x in os.getenv("DEV_ALLOWED_IPS", "").split(",") if x.strip()]
        if allowed and ip not in allowed:
            deny("ip")
        ts, nonce, sig = (request.headers.get(h, "") for h in ("X-Dev-Time", "X-Dev-Nonce", "X-Dev-Sig"))
        if not ts.isdigit() or abs(time.time() - int(ts)) > WINDOW_SECONDS or not (16 <= len(nonce) <= 64):
            deny("stale")
        path_qs = request.path + ("?" + request.query_string.decode() if request.query_string else "")
        if not hmac.compare_digest(sign(secret(), request.method, path_qs, ts, nonce, request.get_data()), sig):
            deny("signature")
        if nonce in nonces:
            deny("replay")
        nonces[nonce] = now
        while len(nonces) > 5000 or (nonces and now - next(iter(nonces.values())) > WINDOW_SECONDS * 2):
            nonces.popitem(last=False)

    def body() -> dict:
        d = request.get_json(silent=True)
        if not isinstance(d, dict):
            raise DevError(400, "Send a JSON object.")
        return d

    @bp.get(PREFIX + "/diag")
    def diag():
        cloud = os.getenv("RAILWAY_ENVIRONMENT_NAME") or os.getenv("K_SERVICE")
        f = flags.get()
        m = f.get("maintenance") or {}
        checks = {
            "aiKeySet": bool(os.getenv("ANTHROPIC_API_KEY")),
            "aiPaused": bool(f.get("aiPaused")),
            "s2KeySet": bool(os.getenv("S2_API_KEY")),
            "adminEnabled": staff.enabled,
            "adminKeySet": bool(staff.admin_key), "adminKeyStrong": len(staff.admin_key) >= 16,
            "sessionSecretStrong": staff.secret_strong, "adminPasswordHashed": staff.password_hashed,
            "serviceAccountSet": bool(os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")) or not cloud,
            "paymentsMode": "simulated",
            "devIpAllowlist": bool(os.getenv("DEV_ALLOWED_IPS")),
        }
        return jsonify({
            "service": cloud or "local", "revision": os.getenv("RAILWAY_DEPLOYMENT_ID") or os.getenv("K_REVISION"),
            "version": (os.getenv("RAILWAY_GIT_COMMIT_SHA") or os.getenv("APP_VERSION") or "dev")[:12],
            "python": platform.python_version(), "model": os.getenv("PINDA_MODEL", "claude-sonnet-5-5"),
            "metrics": metrics.snapshot(300), "checks": checks, "listeners": {},
            "maintenance": {"on": True, "scope": m.get("scope"), "message": m.get("message"), "by": m.get("by")} if m.get("on") else {"on": False},
            "openCrashes": len(metrics.error_groups()),
        })

    @bp.get(PREFIX + "/errors")
    def errors():
        return jsonify({"errors": list(metrics.errors)[::-1]})

    @bp.get(PREFIX + "/crashes")
    def crashes():
        return jsonify({"crashes": metrics.error_groups()[:50]})

    @bp.get(PREFIX + "/db-check")
    def db_check():
        t0 = time.perf_counter()
        try:
            db = get_firestore_client()
            db.document("meta/ping").get()
            list(db.collection("users").limit(1).stream())
            return jsonify({"ok": True, "ms": round((time.perf_counter() - t0) * 1000, 1)})
        except Exception as e:  # noqa: BLE001
            return jsonify({"ok": False, "error": type(e).__name__, "message": str(e)[:200], "quota": is_quota(e)})

    @bp.post(PREFIX + "/selftest")
    def selftest():
        t0 = time.perf_counter()
        try:
            db = get_firestore_client()
            ref = db.document("meta/selftest")
            token = os.urandom(6).hex()
            ref.set({"token": token, "at": time.time()})
            ok = (ref.get().to_dict() or {}).get("token") == token
            ref.delete()
            return jsonify({"ok": ok, "ms": round((time.perf_counter() - t0) * 1000, 1)})
        except Exception as e:  # noqa: BLE001
            return jsonify({"ok": False, "error": type(e).__name__, "message": str(e)[:200]})

    @bp.post(PREFIX + "/ai-check")
    def ai_check():
        """Lists models with the configured key. Free: it doesn't generate anything."""
        t0 = time.perf_counter()
        try:
            import ai
            ai.client().models.list(limit=1)
            return jsonify({"ok": True, "ms": round((time.perf_counter() - t0) * 1000, 1)})
        except Exception as e:  # noqa: BLE001
            return jsonify({"ok": False, "error": type(e).__name__, "message": str(e)[:200]})

    @bp.post(PREFIX + "/maintenance")
    def maintenance():
        d = body()
        scope = "ai" if d.get("scope") in ("ai", "live") else "all"
        return jsonify(flags.set_maintenance(bool(d.get("on")), scope, str(d.get("message") or ""), str(d.get("by") or "developer")))

    @bp.get(PREFIX + "/migrations")
    def migrations_status():
        return jsonify({"migrations": migrations.status()})

    @bp.post(PREFIX + "/migrations/run")
    def migrations_run():
        d = body()
        return jsonify({"report": migrations.run(bool(d.get("apply")), str(d.get("by") or "developer"))})

    @bp.post(PREFIX + "/flush")
    def flush():
        """Called before a deploy. Counters are written as they happen, so this only drops caches."""
        flags.get(fresh=True)
        return jsonify({"ok": True})

    return bp
