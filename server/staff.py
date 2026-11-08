"""Founder sign-in for the admin dashboard.

Three locks, in this order:
    1. sign in with ADMIN_USERNAME + password (ADMIN_PASSWORD_HASH, made by ``python manage.py hash-password``)
    2. "connect" with ADMIN_KEY
    3. every request carries both, and both are checked every time

With no ADMIN_KEY or no admin password set, the dashboard is switched off.
Sessions are signed, expire after ADMIN_SESSION_HOURS, and end when the password
changes. Five wrong passwords lock that username + address for 15 minutes.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import logging
import os
import re
import secrets
import time
from functools import wraps
from pathlib import Path

from flask import Response, g, jsonify, request
from itsdangerous import BadSignature, URLSafeSerializer

from passwords import hash_password, password_problems, verify_password  # noqa: F401
from security import get_firestore_client

log = logging.getLogger("staff")

MAX_FAILS = int(os.getenv("ADMIN_LOGIN_MAX_FAILS", "5"))
LOCK_MINUTES = int(os.getenv("ADMIN_LOGIN_LOCK_MINUTES", "15"))
SESSION_HOURS = float(os.getenv("ADMIN_SESSION_HOURS", "8"))

PAGE_HEADERS = {
    "Content-Security-Policy": "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; "
    "img-src 'self' data:; connect-src 'self'; object-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
    "Cache-Control": "no-store",
    "X-Robots-Tag": "noindex, nofollow",
}


class StaffError(Exception):
    def __init__(self, status: int, code: str, message: str):
        super().__init__(message)
        self.status, self.code, self.message = status, code, message


# ── passwords ────────────────────────────────────────────────────────

_DUMMY = hash_password("not-the-real-password")


def client_ip() -> str:
    hops = int(os.getenv("TRUST_PROXY", "1"))
    fwd = [x.strip() for x in request.headers.get("X-Forwarded-For", "").split(",") if x.strip()]
    if hops and len(fwd) >= hops:
        return fwd[-hops]
    return request.remote_addr or ""


def html_page(path: Path) -> Response:
    resp = Response(path.read_text(encoding="utf-8"), mimetype="text/html")
    resp.headers.update(PAGE_HEADERS)
    return resp


class Staff:
    def __init__(self) -> None:
        self.username = os.getenv("ADMIN_USERNAME", "").strip().lower()
        self.admin_key = os.getenv("ADMIN_KEY", "")
        secret = os.getenv("SESSION_SECRET", "")
        if len(secret) < 32:
            log.warning("SESSION_SECRET is missing or short: admin sessions end when the server restarts.")
            secret = secrets.token_urlsafe(32)
        self.secret_strong = len(os.getenv("SESSION_SECRET", "")) >= 32
        self._signer = URLSafeSerializer(secret, salt="dscvr-admin-session")
        self._hash, self.problem = "", None
        stored, plain = os.getenv("ADMIN_PASSWORD_HASH", ""), os.getenv("ADMIN_PASSWORD", "")
        if not self.username:
            self.problem = "ADMIN_USERNAME is not set."
        elif len(self.username) < 5 or self.username in ("admin", "root", "administrator", "dscvr"):
            self.problem = "ADMIN_USERNAME must be 5+ characters and not a common name like 'admin'."
        elif stored:
            self._hash = stored if stored.startswith("scrypt$") else ""
            self.problem = None if self._hash else "ADMIN_PASSWORD_HASH was not made by manage.py."
        elif plain:
            bad = password_problems(plain, self.username)
            self.problem = ("ADMIN_PASSWORD needs " + ", ".join(bad) + ".") if bad else None
            self._hash = "" if bad else hash_password(plain)
        else:
            self.problem = "Set ADMIN_PASSWORD_HASH (python manage.py hash-password)."
        self._fails: dict[str, list[float]] = {}
        if self.problem:
            log.error("Admin dashboard sign-in is OFF. %s", self.problem)

    @property
    def enabled(self) -> bool:
        return bool(self._hash)

    @property
    def password_hashed(self) -> bool:
        return bool(os.getenv("ADMIN_PASSWORD_HASH")) or not os.getenv("ADMIN_PASSWORD")

    # -- lock-out (Firestore, so every worker agrees; memory if it is unreachable)
    def _key(self, username: str, ip: str) -> str:
        return "staff_login/" + hashlib.sha256(f"{username}|{ip}".encode()).hexdigest()[:40]

    def _read_lock(self, key: str) -> dict:
        try:
            return get_firestore_client().document(key).get().to_dict() or {}
        except Exception:  # noqa: BLE001
            fails = [t for t in self._fails.get(key, []) if time.time() - t < LOCK_MINUTES * 60]
            return {"fails": len(fails), "lockedUntil": (fails[-1] + LOCK_MINUTES * 60) if len(fails) >= MAX_FAILS else 0}

    def _write_lock(self, key: str, doc: dict) -> None:
        try:
            get_firestore_client().document(key).set(doc)
        except Exception:  # noqa: BLE001
            if doc.get("fails"):
                self._fails.setdefault(key, []).append(time.time())
            else:
                self._fails.pop(key, None)

    def login(self, username: str, password: str, ip: str) -> dict:
        if not self.enabled:
            raise StaffError(503, "admin_disabled", "Admin sign-in is not set up on this server.")
        username = (username or "").strip().lower()[:64]
        key = self._key(username, ip)
        now = time.time()
        rec = self._read_lock(key)
        if float(rec.get("lockedUntil") or 0) > now:
            mins = int((float(rec["lockedUntil"]) - now) // 60) + 1
            raise StaffError(429, "login_locked", f"Too many wrong attempts. Try again in {mins} minute(s).")
        right_user = hmac.compare_digest(username.encode(), self.username.encode())
        ok = verify_password(password or "", self._hash if right_user else _DUMMY) and right_user
        if not ok:
            first = float(rec.get("firstAt") or 0)
            fails = 1 if now - first > LOCK_MINUTES * 60 else int(rec.get("fails") or 0) + 1
            doc = {"fails": fails, "firstAt": first if fails > 1 else now, "lockedUntil": 0}
            if fails >= MAX_FAILS:
                doc = {"fails": 0, "firstAt": 0, "lockedUntil": now + LOCK_MINUTES * 60}
            self._write_lock(key, doc)
            time.sleep(0.3)
            raise StaffError(401, "bad_credentials", "Wrong username or password.")
        self._write_lock(key, {"fails": 0, "firstAt": 0, "lockedUntil": 0})
        exp = now + SESSION_HOURS * 3600
        token = self._signer.dumps({"u": self.username, "v": self._hash[-12:], "e": exp})
        return {"token": token, "username": self.username, "expiresAt": exp, "keyRequired": True}

    def session(self, token: str) -> str:
        try:
            p = self._signer.loads(token)
            if p["u"] != self.username or p["v"] != self._hash[-12:] or time.time() > float(p["e"]):
                raise ValueError
            return p["u"]
        except (BadSignature, ValueError, KeyError, TypeError):
            raise StaffError(401, "staff_unauthenticated", "Sign in again.") from None

    def require(self, with_key: bool = True):
        def deco(view):
            @wraps(view)
            def wrapper(*args, **kwargs):
                if not self.enabled:
                    raise StaffError(503, "admin_disabled", "Admin sign-in is not set up on this server.")
                header = request.headers.get("Authorization", "")
                if not header.startswith("Bearer "):
                    raise StaffError(401, "staff_unauthenticated", "Sign in to continue.")
                g.actor = self.session(header[7:].strip())
                if with_key:
                    if len(self.admin_key) < 16:
                        raise StaffError(503, "admin_key_missing", "Set ADMIN_KEY (16+ characters) on the server.")
                    given = request.headers.get("X-Admin-Key", "")
                    if not hmac.compare_digest(given.encode(), self.admin_key.encode()):
                        raise StaffError(401, "bad_admin_key", "Wrong admin key.")
                return view(*args, **kwargs)
            return wrapper
        return deco


def error_json(e: StaffError):
    return jsonify(error=e.code, message=e.message), e.status
