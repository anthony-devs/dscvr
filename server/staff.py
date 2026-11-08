"""Founder sign-in for the admin dashboard.

Two steps:
    1. username + password (ADMIN_PASSWORD_HASH, made by ``python manage.py hash-password``)
    2. the 6-digit code from an authenticator app (ADMIN_TOTP_SECRET, made by ``python manage.py totp-setup``)

A right password only opens the code step. With no password or no authenticator secret set,
the dashboard is switched off. Sessions are signed, expire after ADMIN_SESSION_HOURS, and end
when the password or secret changes. Five wrong passwords, or five wrong codes, lock that
username + address for 15 minutes, and a code works only once.
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

from passwords import (  # noqa: F401
    hash_password, password_problems, totp_clean, totp_valid_secret, totp_verify, verify_password,
)
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
        self.totp_secret = totp_clean(os.getenv("ADMIN_TOTP_SECRET", ""))
        self._last_step = 0
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
        if self._hash and not self.problem and not totp_valid_secret(self.totp_secret):
            self.problem = "Set ADMIN_TOTP_SECRET (python manage.py totp-setup), then add it to your authenticator app."
            self._hash = ""
        # Sessions must verify on every worker. Without SESSION_SECRET, derive one from the
        # credentials so all workers agree and it survives restarts (changes when they change).
        secret = os.getenv("SESSION_SECRET", "")
        self.secret_strong = len(secret) >= 32
        if not self.secret_strong:
            log.warning("SESSION_SECRET is missing or short: using a secret derived from the admin credentials.")
            secret = hashlib.sha256(f"dscvr-admin-session|{self.username}|{stored or plain}|{self.totp_secret}".encode()).hexdigest()
        self._signer = URLSafeSerializer(secret, salt="dscvr-admin-session")
        # Identifies the credentials a session was issued for (stable across workers, unlike a salted hash).
        self._ver = hashlib.sha256(f"{stored or plain}|{self.totp_secret}".encode()).hexdigest()[:12]
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
    def _key(self, username: str, ip: str, kind: str = "login") -> str:
        return "staff_login/" + hashlib.sha256(f"{kind}|{username}|{ip}".encode()).hexdigest()[:40]

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

    def _check_locked(self, rec: dict, now: float) -> None:
        if float(rec.get("lockedUntil") or 0) > now:
            mins = int((float(rec["lockedUntil"]) - now) // 60) + 1
            raise StaffError(429, "login_locked", f"Too many wrong attempts. Try again in {mins} minute(s).")

    def _record_fail(self, key: str, rec: dict, now: float) -> None:
        first = float(rec.get("firstAt") or 0)
        fails = 1 if now - first > LOCK_MINUTES * 60 else int(rec.get("fails") or 0) + 1
        doc = {"fails": fails, "firstAt": first if fails > 1 else now, "lockedUntil": 0}
        if fails >= MAX_FAILS:
            doc = {"fails": 0, "firstAt": 0, "lockedUntil": now + LOCK_MINUTES * 60}
        self._write_lock(key, doc)
        time.sleep(0.3)

    def _token(self, stage: str, seconds: float) -> tuple[str, float]:
        exp = time.time() + seconds
        return self._signer.dumps({"u": self.username, "v": self._ver, "e": exp, "s": stage}), exp

    def login(self, username: str, password: str, ip: str) -> dict:
        """Step 1. A right password only earns a 5-minute pass to the code step, never the dashboard."""
        if not self.enabled:
            raise StaffError(503, "admin_disabled", "Admin sign-in is not set up on this server.")
        username = (username or "").strip().lower()[:64]
        key = self._key(username, ip)
        now = time.time()
        rec = self._read_lock(key)
        self._check_locked(rec, now)
        right_user = hmac.compare_digest(username.encode(), self.username.encode())
        ok = verify_password(password or "", self._hash if right_user else _DUMMY) and right_user
        if not ok:
            self._record_fail(key, rec, now)
            raise StaffError(401, "bad_credentials", "Wrong username or password.")
        self._write_lock(key, {"fails": 0, "firstAt": 0, "lockedUntil": 0})
        token, exp = self._token("pw", 300)
        return {"token": token, "username": self.username, "expiresAt": exp, "totpRequired": True}

    def verify_code(self, token: str, code: str, ip: str) -> dict:
        """Step 2. The 6-digit code from the authenticator app opens the dashboard."""
        self.session(token, "pw")
        key = self._key(self.username, ip, "totp")
        now = time.time()
        rec = self._read_lock(key)
        self._check_locked(rec, now)
        step = totp_verify(self.totp_secret, code, now)
        if step is None or step <= self._last_step:  # a code works once
            self._record_fail(key, rec, now)
            raise StaffError(401, "bad_code", "That code is wrong or already used. Wait for a new one and try again.")
        self._last_step = step
        self._write_lock(key, {"fails": 0, "firstAt": 0, "lockedUntil": 0})
        full, exp = self._token("full", SESSION_HOURS * 3600)
        return {"token": full, "username": self.username, "expiresAt": exp}

    def session(self, token: str, stage: str = "full") -> str:
        try:
            p = self._signer.loads(token)
            if p["u"] != self.username or p["v"] != self._ver or time.time() > float(p["e"]):
                raise ValueError
            if stage != "any" and p.get("s") != stage:
                raise ValueError
            return p["u"]
        except (BadSignature, ValueError, KeyError, TypeError):
            raise StaffError(401, "staff_unauthenticated", "Sign in again.") from None

    def require(self, stage: str = "full"):
        def deco(view):
            @wraps(view)
            def wrapper(*args, **kwargs):
                if not self.enabled:
                    raise StaffError(503, "admin_disabled", "Admin sign-in is not set up on this server.")
                header = request.headers.get("Authorization", "")
                if not header.startswith("Bearer "):
                    raise StaffError(401, "staff_unauthenticated", "Sign in to continue.")
                g.actor = self.session(header[7:].strip(), stage)
                return view(*args, **kwargs)
            return wrapper
        return deco


def error_json(e: StaffError):
    return jsonify(error=e.code, message=e.message), e.status
