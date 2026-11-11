"""Security middleware: rate limiting, Firebase auth, input sanitization."""
from __future__ import annotations

import json
import os
import re
import time
from collections import defaultdict
from functools import wraps
from typing import Any, Callable

from flask import abort, g, jsonify, request
import firebase_admin
from firebase_admin import auth as fb_auth, credentials, firestore

# ── Firebase init ────────────────────────────────────────────────────
_app: firebase_admin.App | None = None


def init_firebase(project_id: str) -> None:
    """Initialize Firebase Admin SDK (call once at startup)."""
    global _app
    if _app is not None:
        return
    try:
        # On hosts without a credentials file (Railway), pass the whole
        # service-account JSON in FIREBASE_SERVICE_ACCOUNT_JSON.
        raw = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
        # GOOGLE_APPLICATION_CREDENTIALS must be a file path. If someone pasted
        # the JSON itself there, use it and clear the variable, otherwise
        # google.auth tries to open the JSON as a filename and every
        # Firestore call fails.
        gac = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "").strip()
        if gac.startswith("{"):
            raw = raw or gac
            os.environ.pop("GOOGLE_APPLICATION_CREDENTIALS", None)
        cred = (
            credentials.Certificate(json.loads(raw))
            if raw
            else credentials.ApplicationDefault()
        )
        _app = firebase_admin.initialize_app(cred, {
            "projectId": project_id,
            "storageBucket": os.getenv("FIREBASE_STORAGE_BUCKET", f"{project_id}.firebasestorage.app"),
        })
    except ValueError:
        # Already initialized
        _app = firebase_admin.get_app()


def get_firestore_client():
    return firestore.client()


# ── Firebase Auth verification ───────────────────────────────────────

def verify_token(token: str) -> dict[str, Any] | None:
    """Verify a Firebase ID token. Returns decoded claims or None."""
    try:
        return fb_auth.verify_id_token(token)
    except Exception as e:  # noqa: BLE001
        import logging
        logging.getLogger("auth").warning("token rejected: %s: %s", type(e).__name__, str(e)[:300])
        return None


def require_auth(f: Callable) -> Callable:
    """Decorator: require a valid Firebase Bearer token. Sets g.uid."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        header = request.headers.get("Authorization", "")
        match = re.match(r"^Bearer (.+)$", header)
        if not match:
            return jsonify(error="Sign in to continue."), 401
        claims = verify_token(match.group(1))
        if claims is None:
            return jsonify(error="Invalid or expired token."), 401
        g.uid = claims["uid"]
        g.email = claims.get("email")
        g.email_verified = bool(claims.get("email_verified"))
        return f(*args, **kwargs)
    return wrapper


def optional_auth(f: Callable) -> Callable:
    """Decorator: sets g.uid if a valid token is present, else None."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        header = request.headers.get("Authorization", "")
        match = re.match(r"^Bearer (.+)$", header)
        g.uid = None
        if match:
            claims = verify_token(match.group(1))
            if claims:
                g.uid = claims["uid"]
        return f(*args, **kwargs)
    return wrapper


# ── Sliding-window rate limiter ──────────────────────────────────────

_windows: dict[str, list[float]] = defaultdict(list)
_last_prune = time.monotonic()
_PRUNE_INTERVAL = 300  # 5 minutes


def _prune(window_sec: float) -> None:
    global _last_prune
    now = time.monotonic()
    if now - _last_prune < _PRUNE_INTERVAL:
        return
    _last_prune = now
    cutoff = now - window_sec
    stale = [k for k, v in _windows.items() if not v or v[-1] < cutoff]
    for k in stale:
        del _windows[k]


def rate_limit_check(key: str, max_requests: int, window_sec: float) -> bool:
    """Returns True if the request is allowed."""
    _prune(window_sec)
    now = time.monotonic()
    cutoff = now - window_sec
    ts = _windows[key]
    _windows[key] = [t for t in ts if t > cutoff]
    if len(_windows[key]) >= max_requests:
        return False
    _windows[key].append(now)
    return True


# Per-endpoint presets
LIMITS = {
    "discover":   {"per_min": 30, "per_hour": 300},
    "checkout":   {"per_min": 5,  "per_hour": 20},
    "verify":     {"per_min": 10, "per_hour": 60},
    "webhook":    {"per_min": 30, "per_hour": 300},
    "portal":     {"per_min": 10, "per_hour": 60},
    "pinda":      {"per_min": 12, "per_hour": 200},
    "report":     {"per_min": 3,  "per_hour": 30},
    "summary":    {"per_min": 5,  "per_hour": 60},
    "parliament": {"per_min": 4,  "per_hour": 40},
    "study":      {"per_min": 6,  "per_hour": 60},
    "alerts":     {"per_min": 2,  "per_hour": 6},
    "import":     {"per_min": 10, "per_hour": 120},
    "pdfview":    {"per_min": 20, "per_hour": 300},
    "rate":       {"per_min": 30, "per_hour": 300},
    "orgs":       {"per_min": 5,  "per_hour": 30},
    "rooms":      {"per_min": 10, "per_hour": 60},
    "shares":     {"per_min": 20, "per_hour": 200},
    "account":    {"per_min": 3, "per_hour": 10},
    "referrals":  {"per_min": 5, "per_hour": 30},
    "feedback":   {"per_min": 5, "per_hour": 20},
}


def check_rate(identity: str, endpoint: str) -> str | None:
    """Check per-minute and per-hour limits. Returns error message or None."""
    limits = LIMITS.get(endpoint, {"per_min": 30, "per_hour": 300})
    if not rate_limit_check(f"{identity}:{endpoint}:min", limits["per_min"], 60):
        return f"Too many requests. Limit: {limits['per_min']}/minute."
    if not rate_limit_check(f"{identity}:{endpoint}:hr", limits["per_hour"], 3600):
        return f"Hourly limit reached ({limits['per_hour']}/hour). Try again later."
    return None


# ── Input sanitization ───────────────────────────────────────────────

def sanitize(value: Any, max_len: int = 500) -> str:
    """Strip null bytes, trim, and cap length."""
    if not isinstance(value, str):
        return ""
    return value.replace("\x00", "").strip()[:max_len]


def check_body_size(max_bytes: int = 512 * 1024) -> bool:
    """Returns True if the request body exceeds max_bytes."""
    data = request.get_data(cache=True)
    return len(data) > max_bytes


# ── Firestore-backed abuse logging ───────────────────────────────────

def log_usage(uid: str, endpoint: str) -> None:
    """Best-effort usage logging to Firestore."""
    try:
        from datetime import datetime, timezone
        db = get_firestore_client()
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        ref = db.document(f"usage/{uid}/daily/{today}")
        ref.set(
            {
                "total": firestore.Increment(1),
                endpoint: firestore.Increment(1),
                "lastRequest": datetime.now(timezone.utc).isoformat(),
            },
            merge=True,
        )
    except Exception:
        pass  # Usage logging must never break requests


# ── Subscription tier helpers ────────────────────────────────────────

def get_user_tier(uid: str) -> str:
    """Read the user's subscription tier from Firestore."""
    try:
        db = get_firestore_client()
        doc = db.document(f"users/{uid}").get()
        tier = (doc.to_dict() or {}).get("subscription", {}).get("tier", "free")
        return tier if tier in ("pro", "team") else "free"
    except Exception:
        return "free"


def require_tier(actual: str, minimum: str) -> str | None:
    """Returns None if allowed, or an error message."""
    rank = {"free": 0, "pro": 1, "team": 2}
    if rank.get(actual, 0) >= rank.get(minimum, 1):
        return None
    label = "Pro" if minimum == "pro" else "Team"
    return f"This feature requires a {label} plan or higher."
