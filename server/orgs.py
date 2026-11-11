"""Enterprise organisations, usage metering, billing and paper ratings.

Pricing model
-------------
Students and Researchers are free, with a daily Pinda allowance.
Enterprise is billed by usage, like the Claude API:
  * Seat-days: a member counts once per day they use DSCVR,
    at SEAT_DAY_USD per day, capped at SEAT_MONTH_CAP_USD per member per month.
  * AI usage: per million tokens processed by Pinda, reports and fact-checks.
All prices are environment-configurable.

Firestore layout
----------------
  orgs/{orgId}                         name, ownerUid, inviteCode, createdAt
  orgs/{orgId}/members/{uid}           name, email, role (admin|member), joinedAt
  orgs/{orgId}/usage/{YYYY-MM-DD}      seats{uid:true}, inputTokens, outputTokens, requests, byFeature{}
  orgs/{orgId}/invoices/{YYYY-MM}      status, amountUsd, paidAt, payment{}
  users/{uid}                          orgId, orgRole, edition
  users/{uid}/meta/usage               day, count (free daily allowance)
  papers/{key}                         title, sum, count       (community ratings)
  papers/{key}/ratings/{uid}           stars, updatedAt
  stats/{YYYY-MM-DD}                   app-wide daily totals for the admin dashboard:
                                       active{uid}, aiUsers{uid}, requests, inputTokens, outputTokens, byFeature{}
"""
from __future__ import annotations

import os
import re
import secrets
import time
from datetime import datetime, timezone
from typing import Any

from firebase_admin import firestore

from security import get_firestore_client

SEAT_DAY_USD = float(os.getenv("SEAT_DAY_USD", "0.40"))
SEAT_MONTH_CAP_USD = float(os.getenv("SEAT_MONTH_CAP_USD", "8.00"))
AI_INPUT_PER_M_USD = float(os.getenv("AI_INPUT_PER_M_USD", "4.00"))
AI_OUTPUT_PER_M_USD = float(os.getenv("AI_OUTPUT_PER_M_USD", "20.00"))
PRICING = {
    "students": {"price": 0, "plan": "free"},
    "researchers": {"price": 0, "plan": "free"},
    "enterprise": {
        "seatDayUsd": SEAT_DAY_USD,
        "seatMonthCapUsd": SEAT_MONTH_CAP_USD,
        "aiInputPerMillionUsd": AI_INPUT_PER_M_USD,
        "aiOutputPerMillionUsd": AI_OUTPUT_PER_M_USD,
    },
}


class OrgError(Exception):
    def __init__(self, message: str, status: int = 400):
        super().__init__(message)
        self.status = status


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _today() -> str:
    return _now().strftime("%Y-%m-%d")


def _month() -> str:
    return _now().strftime("%Y-%m")


def _db():
    return get_firestore_client()


# ── User → org lookup (cached briefly; called on every AI request) ───

_user_cache: dict[str, tuple[float, dict[str, Any]]] = {}


def user_profile(uid: str, fresh: bool = False) -> dict[str, Any]:
    hit = _user_cache.get(uid)
    if hit and not fresh and time.monotonic() - hit[0] < 60:
        return hit[1]
    snap = _db().document(f"users/{uid}").get()
    data = snap.to_dict() or {}
    _user_cache[uid] = (time.monotonic(), data)
    return data


def _forget(uid: str) -> None:
    _user_cache.pop(uid, None)


# ── Free allowance + metering ────────────────────────────────────────

def check_allowance(uid: str) -> dict[str, Any] | None:
    """Enterprise members are metered, not limited. Everyone else has a daily
    and a monthly usage budget for their plan (see plans.py). Returns an
    error payload when either is used up."""
    import flags
    import plans
    profile = user_profile(uid)
    plan = plans.plan_of(profile)
    caps = plans.budgets(plan, flags.free_daily_usd())
    if caps is None:
        return None
    daily, monthly = caps
    u = _db().document(f"users/{uid}/meta/usage").get().to_dict() or {}
    day_cost = float(u.get("dayCost") or 0) if u.get("day") == _today() else 0.0
    month_cost = float(u.get("monthCost") or 0) if u.get("month") == _month() else 0.0
    day_reset, month_reset = plans.resets()
    label = plans.PLANS[plan]["label"]
    upgrade = "" if plan == "max" else " Upgrade for more."
    if month_cost >= monthly:
        return {"error": f"You've used this month's Pinda usage on {label}. It resets in {plans.until(month_reset)}.{upgrade}",
                "code": "usage_limit", "plan": plan, "window": "month", "resetsAt": month_reset.isoformat()}
    if day_cost >= daily:
        return {"error": f"You've used today's Pinda usage on {label}. It resets in {plans.until(day_reset)}.{upgrade}",
                "code": "usage_limit", "plan": plan, "window": "day", "resetsAt": day_reset.isoformat()}
    return None


def usage_for(uid: str) -> dict[str, Any]:
    """The usage meter a user sees: percentages and reset times, no dollars."""
    import flags
    import plans
    profile = user_profile(uid, fresh=True)
    plan = plans.plan_of(profile)
    caps = plans.budgets(plan, flags.free_daily_usd())
    u = _db().document(f"users/{uid}/meta/usage").get().to_dict() or {}
    day_cost = float(u.get("dayCost") or 0) if u.get("day") == _today() else 0.0
    month_cost = float(u.get("monthCost") or 0) if u.get("month") == _month() else 0.0
    day_reset, month_reset = plans.resets()
    meter = None
    if caps:
        meter = {"dayPct": min(100, round(day_cost / caps[0] * 100)) if caps[0] else 100,
                 "monthPct": min(100, round(month_cost / caps[1] * 100)) if caps[1] else 100,
                 "dayResetsAt": day_reset.isoformat(), "monthResetsAt": month_reset.isoformat()}
    ends = profile.get("planEndsAt")
    return {"plan": plan, "planStatus": profile.get("planStatus") or ("active" if plan != "free" else None),
            "planEndsAt": ends.isoformat() if hasattr(ends, "isoformat") else ends,
            "usage": meter, "requests": int(u.get("total") or 0)}


def record_usage(uid: str, feature: str, input_tokens: int = 0, output_tokens: int = 0, model: str | None = None) -> None:
    """Best-effort metering. Never raises."""
    try:
        import plans
        profile = user_profile(uid)
        org_id = profile.get("orgId")
        db = _db()
        if org_id:
            db.document(f"orgs/{org_id}/usage/{_today()}").set({
                "seats": {uid: True},
                "inputTokens": firestore.Increment(int(input_tokens)),
                "outputTokens": firestore.Increment(int(output_tokens)),
                "requests": firestore.Increment(1),
                "byFeature": {feature: firestore.Increment(1)},
                "updatedAt": _now(),
            }, merge=True)
        cost = plans.cost_usd(model or plans.FAST_MODEL, int(input_tokens), int(output_tokens))
        ref = db.document(f"users/{uid}/meta/usage")
        today, month = _today(), _month()

        @firestore.transactional
        def txn(tx):
            u = ref.get(transaction=tx).to_dict() or {}
            tx.set(ref, {
                "day": today, "month": month,
                "dayCost": (float(u.get("dayCost") or 0) if u.get("day") == today else 0.0) + cost,
                "monthCost": (float(u.get("monthCost") or 0) if u.get("month") == month else 0.0) + cost,
                "total": int(u.get("total") or 0) + 1,
                "inputTokens": int(u.get("inputTokens") or 0) + int(input_tokens),
                "outputTokens": int(u.get("outputTokens") or 0) + int(output_tokens),
                "costUsd": float(u.get("costUsd") or 0) + cost,
            }, merge=True)

        txn(db.transaction())
        db.document(f"stats/{_today()}").set({
            "active": {uid: True},
            "aiUsers": {uid: True},
            "requests": firestore.Increment(1),
            "inputTokens": firestore.Increment(int(input_tokens)),
            "outputTokens": firestore.Increment(int(output_tokens)),
            "costUsd": firestore.Increment(cost),
            "byFeature": {feature: firestore.Increment(1)},
            "byEdition": {("enterprise" if org_id else (profile.get("edition") or "researchers")): firestore.Increment(1)},
            "byPlan": {plans.plan_of(profile): firestore.Increment(1)},
        }, merge=True)
    except Exception:  # noqa: BLE001
        pass


def mark_active(uid: str) -> None:
    """Counts today's active user, and a seat-day for enterprise members."""
    try:
        org_id = user_profile(uid).get("orgId")
        _db().document(f"stats/{_today()}").set({"active": {uid: True}}, merge=True)
        if org_id:
            _db().document(f"orgs/{org_id}/usage/{_today()}").set(
                {"seats": {uid: True}, "updatedAt": _now()}, merge=True)
    except Exception:  # noqa: BLE001
        pass


# ── Billing maths ────────────────────────────────────────────────────

def bill_for(usage_days: list[dict[str, Any]]) -> dict[str, Any]:
    """Computes a month's bill from its daily usage docs."""
    seat_days: dict[str, int] = {}
    tin = tout = requests_ = 0
    for day in usage_days:
        for uid, active in (day.get("seats") or {}).items():
            if active:
                seat_days[uid] = seat_days.get(uid, 0) + 1
        tin += int(day.get("inputTokens") or 0)
        tout += int(day.get("outputTokens") or 0)
        requests_ += int(day.get("requests") or 0)
    seat_cost = sum(min(n * SEAT_DAY_USD, SEAT_MONTH_CAP_USD) for n in seat_days.values())
    ai_cost = tin / 1e6 * AI_INPUT_PER_M_USD + tout / 1e6 * AI_OUTPUT_PER_M_USD
    return {
        "activeMembers": len(seat_days),
        "seatDays": sum(seat_days.values()),
        "inputTokens": tin,
        "outputTokens": tout,
        "requests": requests_,
        "seatCostUsd": round(seat_cost, 2),
        "aiCostUsd": round(ai_cost, 2),
        "totalUsd": round(seat_cost + ai_cost, 2),
    }


def month_usage(org_id: str, month: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    docs = (_db().collection(f"orgs/{org_id}/usage")
            .where(firestore.FieldPath.document_id(), ">=", f"{month}-01")
            .where(firestore.FieldPath.document_id(), "<=", f"{month}-31").get())
    days = [{"day": d.id, **(d.to_dict() or {})} for d in docs]
    daily = [{"day": d["day"], "activeMembers": sum(1 for v in (d.get("seats") or {}).values() if v),
              "inputTokens": int(d.get("inputTokens") or 0), "outputTokens": int(d.get("outputTokens") or 0),
              "requests": int(d.get("requests") or 0)} for d in sorted(days, key=lambda x: x["day"])]
    return days, daily


# ── Organisations ────────────────────────────────────────────────────

def _code() -> str:
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return "".join(secrets.choice(alphabet) for _ in range(8))


def _member_doc(name: str, email: str, role: str) -> dict[str, Any]:
    return {"name": name[:80], "email": email[:120], "role": role, "joinedAt": _now()}


def create_org(uid: str, name: str, email: str, display_name: str) -> dict[str, Any]:
    name = name.strip()[:80]
    if len(name) < 2:
        raise OrgError("Give your organisation a name.")
    if user_profile(uid, fresh=True).get("orgId"):
        raise OrgError("You're already in an organisation. Leave it first.")
    db = _db()
    ref = db.collection("orgs").document()
    batch = db.batch()
    batch.set(ref, {"name": name, "ownerUid": uid, "inviteCode": _code(), "createdAt": _now()})
    batch.set(ref.collection("members").document(uid), _member_doc(display_name, email, "admin"))
    batch.set(db.document(f"users/{uid}"), {"orgId": ref.id, "orgRole": "admin", "edition": "enterprise"}, merge=True)
    batch.commit()
    _forget(uid)
    return get_org(uid)


def _require_org(uid: str, admin: bool = False) -> tuple[str, dict[str, Any]]:
    profile = user_profile(uid, fresh=True)
    org_id = profile.get("orgId")
    if not org_id:
        raise OrgError("You're not in an organisation.", 404)
    if admin and profile.get("orgRole") != "admin":
        raise OrgError("Only organisation admins can do that.", 403)
    return org_id, profile


def get_org(uid: str) -> dict[str, Any]:
    org_id, profile = _require_org(uid)
    db = _db()
    org = db.document(f"orgs/{org_id}").get().to_dict() or {}
    is_admin = profile.get("orgRole") == "admin"
    out: dict[str, Any] = {"id": org_id, "name": org.get("name", ""), "role": profile.get("orgRole", "member"),
                           "pricing": PRICING["enterprise"]}
    if is_admin:
        members = [{"uid": m.id, **{k: v for k, v in (m.to_dict() or {}).items() if k != "joinedAt"},
                    "joinedAt": (m.to_dict() or {}).get("joinedAt").isoformat() if (m.to_dict() or {}).get("joinedAt") else None}
                   for m in db.collection(f"orgs/{org_id}/members").get()]
        days, daily = month_usage(org_id, _month())
        out.update({"inviteCode": org.get("inviteCode"), "members": members, "month": _month(),
                    "estimate": bill_for(days), "daily": daily})
    return out


def rotate_invite(uid: str) -> str:
    org_id, _ = _require_org(uid, admin=True)
    code = _code()
    _db().document(f"orgs/{org_id}").update({"inviteCode": code})
    return code


def join_org(uid: str, code: str, email: str, display_name: str) -> dict[str, Any]:
    code = re.sub(r"[^A-Z0-9]", "", code.upper())
    if len(code) != 8:
        raise OrgError("That invite code doesn't look right.")
    if user_profile(uid, fresh=True).get("orgId"):
        raise OrgError("You're already in an organisation. Leave it first.")
    db = _db()
    matches = db.collection("orgs").where("inviteCode", "==", code).limit(1).get()
    if not matches:
        raise OrgError("No organisation uses that invite code.", 404)
    org_ref = matches[0].reference
    batch = db.batch()
    batch.set(org_ref.collection("members").document(uid), _member_doc(display_name, email, "member"))
    batch.set(db.document(f"users/{uid}"), {"orgId": org_ref.id, "orgRole": "member", "edition": "enterprise"}, merge=True)
    batch.commit()
    _forget(uid)
    return get_org(uid)


def remove_member(uid: str, member_uid: str) -> None:
    org_id, _ = _require_org(uid, admin=True)
    if member_uid == uid:
        raise OrgError("Use Leave to remove yourself.")
    _detach(org_id, member_uid)


def leave_org(uid: str) -> None:
    org_id, profile = _require_org(uid)
    if profile.get("orgRole") == "admin":
        admins = _db().collection(f"orgs/{org_id}/members").where("role", "==", "admin").get()
        if len(admins) <= 1:
            raise OrgError("Make someone else an admin before you leave.")
    _detach(org_id, uid)


def set_role(uid: str, member_uid: str, role: str) -> None:
    org_id, _ = _require_org(uid, admin=True)
    if role not in ("admin", "member"):
        raise OrgError("Unknown role.")
    db = _db()
    batch = db.batch()
    batch.update(db.document(f"orgs/{org_id}/members/{member_uid}"), {"role": role})
    batch.set(db.document(f"users/{member_uid}"), {"orgRole": role}, merge=True)
    batch.commit()
    _forget(member_uid)


def _detach(org_id: str, member_uid: str) -> None:
    db = _db()
    batch = db.batch()
    batch.delete(db.document(f"orgs/{org_id}/members/{member_uid}"))
    batch.set(db.document(f"users/{member_uid}"),
              {"orgId": firestore.DELETE_FIELD, "orgRole": firestore.DELETE_FIELD, "edition": "researchers"}, merge=True)
    batch.commit()
    _forget(member_uid)


def invoices(uid: str) -> list[dict[str, Any]]:
    org_id, _ = _require_org(uid, admin=True)
    db = _db()
    paid = {d.id: d.to_dict() or {} for d in db.collection(f"orgs/{org_id}/invoices").get()}
    months = sorted({d.id[:7] for d in db.collection(f"orgs/{org_id}/usage").select([]).get()}, reverse=True)[:12]
    out = []
    for m in months:
        days, _ = month_usage(org_id, m)
        bill = bill_for(days)
        status = paid.get(m, {}).get("status") or ("open" if m == _month() else "due")
        out.append({"month": m, **bill, "status": status})
    return out


def pay_invoice(uid: str, month: str, payment: dict[str, Any]) -> dict[str, Any]:
    org_id, _ = _require_org(uid, admin=True)
    if not re.fullmatch(r"\d{4}-\d{2}", month) or month >= _month():
        raise OrgError("Only completed months can be paid.")
    days, _ = month_usage(org_id, month)
    bill = bill_for(days)
    _db().document(f"orgs/{org_id}/invoices/{month}").set({
        "status": "paid", "amountUsd": bill["totalUsd"], "paidAt": _now(), "paidBy": uid,
        "payment": {k: payment.get(k) for k in ("transaction_id", "card_network", "card_details")},
    }, merge=True)
    return {"month": month, **bill, "status": "paid"}


# ── Community paper ratings ──────────────────────────────────────────

def _paper_key(key: str) -> str:
    key = re.sub(r"[^A-Za-z0-9._:-]", "_", key.strip())[:120]
    if len(key) < 3:
        raise OrgError("Unknown paper.")
    return key


def rate_paper(uid: str, key: str, stars: int, title: str) -> dict[str, Any]:
    key = _paper_key(key)
    if stars not in (1, 2, 3, 4, 5):
        raise OrgError("Rate from 1 to 5 stars.")
    db = _db()
    paper = db.document(f"papers/{key}")
    mine = paper.collection("ratings").document(uid)

    @firestore.transactional
    def txn(tx):
        prev = mine.get(transaction=tx).to_dict()
        agg = paper.get(transaction=tx).to_dict() or {}
        total = int(agg.get("sum", 0)) - int(prev["stars"] if prev else 0) + stars
        count = int(agg.get("count", 0)) + (0 if prev else 1)
        tx.set(paper, {"sum": total, "count": count, "title": title[:300] or agg.get("title", "")}, merge=True)
        tx.set(mine, {"stars": stars, "uid": uid, "updatedAt": _now()})
        return total, count

    total, count = txn(db.transaction())
    return {"key": key, "average": round(total / count, 2), "count": count, "mine": stars}


def ratings_for(uid: str | None, keys: list[str]) -> dict[str, Any]:
    db = _db()
    out: dict[str, Any] = {}
    for raw in keys[:50]:
        try:
            key = _paper_key(raw)
        except OrgError:
            continue
        agg = db.document(f"papers/{key}").get().to_dict() or {}
        count = int(agg.get("count", 0))
        mine = None
        if uid:
            mine = (db.document(f"papers/{key}/ratings/{uid}").get().to_dict() or {}).get("stars")
        out[raw] = {"average": round(int(agg.get("sum", 0)) / count, 2) if count else None, "count": count, "mine": mine}
    return out
