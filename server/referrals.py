"""Invite a friend: you both get more Pinda.

Each user has a short code (referral_codes/{code} -> uid). A new user redeems a
code once, after verifying their email, within REFERRAL_WINDOW_DAYS of signing
up. Both people then get a boost: their daily and monthly Pinda budgets are
multiplied by REFERRAL_BOOST for REFERRAL_DAYS. Boosts stack by extending the
end date, up to REFERRAL_MAX_DAYS ahead. A referrer earns at most
REFERRAL_MAX_REWARDS boosts.
"""
from __future__ import annotations

import os
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any

from google.cloud import firestore

from security import get_firestore_client

ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # no 0/O or 1/I


def _f(name: str, default: float) -> float:
    try:
        return float(os.getenv(name, default))
    except ValueError:
        return default


BOOST = _f("REFERRAL_BOOST", 2.0)
DAYS = int(_f("REFERRAL_DAYS", 30))
MAX_DAYS = int(_f("REFERRAL_MAX_DAYS", 180))
WINDOW_DAYS = int(_f("REFERRAL_WINDOW_DAYS", 14))
MAX_REWARDS = int(_f("REFERRAL_MAX_REWARDS", 20))


class ReferralError(Exception):
    def __init__(self, message: str, status: int = 400):
        super().__init__(message)
        self.status = status


def _db():
    return get_firestore_client()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _ts(v: Any) -> float | None:
    if v is None:
        return None
    if hasattr(v, "timestamp"):
        return v.timestamp()
    if isinstance(v, (int, float)):
        return float(v)
    try:
        return datetime.fromisoformat(str(v)).timestamp()
    except ValueError:
        return None


def boost_factor(profile: dict[str, Any]) -> float:
    """How much to multiply a user's Pinda budgets by right now."""
    until = _ts(profile.get("boostUntil"))
    return BOOST if until and until > _now().timestamp() else 1.0


def _extend(current: Any) -> datetime:
    start = max(_now().timestamp(), _ts(current) or 0)
    end = datetime.fromtimestamp(start, timezone.utc) + timedelta(days=DAYS)
    return min(end, _now() + timedelta(days=MAX_DAYS))


def code_for(uid: str, db=None) -> str:
    """The user's referral code, created on first use."""
    db = db or _db()
    ref = db.document(f"users/{uid}")
    existing = (ref.get().to_dict() or {}).get("referralCode")
    if existing:
        return existing
    for _ in range(8):
        code = "".join(secrets.choice(ALPHABET) for _ in range(7))
        code_ref = db.document(f"referral_codes/{code}")
        if not code_ref.get().exists:
            code_ref.set({"uid": uid, "createdAt": _now()})
            ref.set({"referralCode": code}, merge=True)
            return code
    raise ReferralError("Couldn't make an invite code. Try again.", 500)


def status(uid: str, db=None) -> dict[str, Any]:
    db = db or _db()
    code = code_for(uid, db)
    profile = db.document(f"users/{uid}").get().to_dict() or {}
    until = _ts(profile.get("boostUntil"))
    active = bool(until and until > _now().timestamp())
    return {
        "code": code,
        "link": f"{os.getenv('APP_URL', 'https://app.askpinda.com')}/signup?ref={code}",
        "referred": int(profile.get("referralCount") or 0),
        "redeemed": bool(profile.get("referredBy")),
        "boost": BOOST, "days": DAYS,
        "boostUntil": datetime.fromtimestamp(until, timezone.utc).isoformat() if active else None,
    }


def redeem(uid: str, code: str, email_verified: bool, created_at: datetime | None, db=None) -> dict[str, Any]:
    db = db or _db()
    code = "".join(ch for ch in (code or "").upper() if ch.isalnum())[:12]
    if not code:
        raise ReferralError("Enter an invite code.")
    if not email_verified:
        raise ReferralError("Verify your email first, then use the invite code.", 403)
    if created_at and _now() - created_at > timedelta(days=WINDOW_DAYS):
        raise ReferralError(f"Invite codes work in your first {WINDOW_DAYS} days on DSCVR.")
    target = db.document(f"referral_codes/{code}").get().to_dict()
    if not target:
        raise ReferralError("That invite code doesn't exist.", 404)
    referrer = target["uid"]
    if referrer == uid:
        raise ReferralError("You can't use your own invite code.")

    me_ref, them_ref = db.document(f"users/{uid}"), db.document(f"users/{referrer}")

    @firestore.transactional
    def txn(tx):
        me = me_ref.get(transaction=tx).to_dict() or {}
        them = them_ref.get(transaction=tx).to_dict() or {}
        if me.get("referredBy"):
            raise ReferralError("You've already used an invite code.")
        mine = _extend(me.get("boostUntil"))
        tx.set(me_ref, {"referredBy": referrer, "referredAt": _now(), "boostUntil": mine}, merge=True)
        rewarded = int(them.get("referralCount") or 0) < MAX_REWARDS
        update: dict[str, Any] = {"referralCount": firestore.Increment(1)}
        if rewarded:
            update["boostUntil"] = _extend(them.get("boostUntil"))
        tx.set(them_ref, update, merge=True)
        tx.set(db.collection("referrals").document(), {"referrer": referrer, "referred": uid, "code": code, "at": _now(), "rewarded": rewarded})
        return mine

    mine = txn(db.transaction())
    return {"ok": True, "boost": BOOST, "days": DAYS, "boostUntil": mine.isoformat()}
