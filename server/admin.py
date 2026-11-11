"""Founder dashboard: /admin (page) and /admin/api/* (data).

Sign-in and the admin key are checked on every request (see staff.py). Reads are
cached for a short while and the cache is dropped after any change, so the page
is cheap to leave open and never stale after an action. Every change is written
to admin_audit.
"""
from __future__ import annotations

import logging
import os
import re
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from firebase_admin import auth as fb_auth, firestore
from flask import Blueprint, g, jsonify, request
from werkzeug.exceptions import HTTPException

import flags
import orgs
import plans
from security import get_firestore_client
from staff import Staff, StaffError, client_ip, error_json, html_page

log = logging.getLogger("admin")

UI = Path(__file__).parent / "admin_ui" / "index.html"
CACHE_SECONDS = 60
EDITIONS = ("students", "researchers", "enterprise")
# What Anthropic charges you, to show margin against what enterprise pays.
COST_IN_PER_M = float(os.getenv("ANTHROPIC_INPUT_PER_M_USD", "2.00"))
COST_OUT_PER_M = float(os.getenv("ANTHROPIC_OUTPUT_PER_M_USD", "10.00"))


def _db():
    return get_firestore_client()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(v) -> str | None:
    if v is None:
        return None
    if hasattr(v, "isoformat"):
        return v.isoformat()
    return str(v)


def _count(query) -> int | None:
    try:
        res = query.count().get()
        return int(res[0][0].value)
    except Exception:  # noqa: BLE001
        return None


def _cost(tin: int, tout: int) -> float:
    return round(tin / 1e6 * COST_IN_PER_M + tout / 1e6 * COST_OUT_PER_M, 2)


def _clean_id(v: str, n: int = 128) -> str:
    v = (v or "").strip()
    if not re.fullmatch(r"[A-Za-z0-9._:@+-]{1,%d}" % n, v):
        raise StaffError(400, "bad_id", "That id doesn't look right.")
    return v


def make_admin(staff: Staff) -> Blueprint:
    bp = Blueprint("admin", __name__)
    guarded = staff.require()
    _cache: dict[Any, tuple[float, Any]] = {}

    @bp.errorhandler(StaffError)
    def _staff_error(e: StaffError):
        return error_json(e)

    @bp.errorhandler(Exception)
    def _unexpected(e: Exception):
        """Signed-in staff see what actually failed (Firestore index, permissions, ...), not just "Internal server error"."""
        if isinstance(e, HTTPException):
            return e
        log.exception("admin %s failed", request.path)
        return jsonify(error="server_error", message=f"{type(e).__name__}: {str(e)[:400]}"), 500

    def cached(key, build):
        hit = _cache.get(key)
        if hit and time.monotonic() - hit[0] < CACHE_SECONDS and request.args.get("fresh") != "1":
            return hit[1]
        value = build()
        _cache[key] = (time.monotonic(), value)
        if len(_cache) > 200:
            _cache.clear()
        return value

    @bp.after_request
    def _drop_cache(resp):
        if request.method == "POST" and request.path.startswith("/admin/api/") and not request.path.endswith(("/login", "/totp")):
            _cache.clear()
        resp.headers["Cache-Control"] = "no-store"
        return resp

    def body() -> dict:
        d = request.get_json(silent=True)
        if not isinstance(d, dict):
            raise StaffError(400, "invalid_body", "Send a JSON object.")
        return d

    def audit(action: str, target: str = "", detail: dict | None = None) -> None:
        try:
            _db().collection("admin_audit").add({
                "at": _now(), "actor": g.actor, "ip": client_ip(), "action": action,
                "target": target[:160], "detail": detail or {},
            })
        except Exception:  # noqa: BLE001
            pass

    # ── page + sign-in ───────────────────────────────────────────────

    @bp.get("/admin")
    def page():
        return html_page(UI)

    @bp.post("/admin/api/login")
    def login():
        d = body()
        return jsonify(staff.login(str(d.get("username") or ""), str(d.get("password") or ""), client_ip()))

    @bp.post("/admin/api/totp")
    def totp():
        d = body()
        return jsonify(staff.verify_code(str(d.get("token") or ""), str(d.get("code") or ""), client_ip()))

    @bp.get("/admin/api/session")
    @staff.require()
    def session():
        return jsonify(username=g.actor)

    @bp.get("/admin/api/ping")
    @guarded
    def ping():
        return jsonify(ok=True, username=g.actor, editions=list(EDITIONS))

    # ── overview ─────────────────────────────────────────────────────

    def _overview(days: int) -> dict:
        db = _db()
        users = db.collection("users")
        now = _now()
        start = (now - timedelta(days=days - 1)).strftime("%Y-%m-%d")
        warnings: list[str] = []
        try:
            stats = {s.id: s.to_dict() or {} for s in db.collection("stats")
                     .where(firestore.FieldPath.document_id(), ">=", start).get()}
        except Exception as e:  # noqa: BLE001
            log.exception("admin overview: stats")
            stats = {}
            warnings.append(f"Daily stats could not be read ({type(e).__name__}: {str(e)[:160]}).")
        series = []
        for i in range(days):
            day = (now - timedelta(days=days - 1 - i)).strftime("%Y-%m-%d")
            s = stats.get(day, {})
            tin, tout = int(s.get("inputTokens") or 0), int(s.get("outputTokens") or 0)
            series.append({
                "day": day, "active": sum(1 for v in (s.get("active") or {}).values() if v),
                "aiUsers": sum(1 for v in (s.get("aiUsers") or {}).values() if v),
                "requests": int(s.get("requests") or 0), "inputTokens": tin, "outputTokens": tout,
                "costUsd": round(float(s.get("costUsd")), 2) if s.get("costUsd") is not None else _cost(tin, tout), "byFeature": s.get("byFeature") or {}, "byEdition": s.get("byEdition") or {},
            })
        today = series[-1]
        week = series[-7:]
        features: dict[str, int] = {}
        for d in series:
            for k, v in d["byFeature"].items():
                features[k] = features.get(k, 0) + int(v or 0)

        month, revenue, last_revenue, org_count = now.strftime("%Y-%m"), 0.0, 0.0, 0
        last_month = (now.replace(day=1) - timedelta(days=1)).strftime("%Y-%m")
        try:
            org_docs = list(db.collection("orgs").select([]).get())
        except Exception as e:  # noqa: BLE001
            log.exception("admin overview: orgs")
            org_docs = []
            warnings.append(f"Teams could not be read ({type(e).__name__}: {str(e)[:160]}).")
        for org in org_docs:
            org_count += 1
            try:
                revenue += orgs.bill_for(orgs.month_usage(org.id, month)[0])["totalUsd"]
                last_revenue += orgs.bill_for(orgs.month_usage(org.id, last_month)[0])["totalUsd"]
            except Exception:  # noqa: BLE001
                pass

        weekly_active: set[str] = set()
        for day in list(stats.values())[-7:]:
            weekly_active.update(k for k, v in (day.get("active") or {}).items() if v)

        return {
            "generatedAt": _iso(now), "days": days, "warnings": warnings,
            "users": {
                "total": _count(users),
                "new7": _count(users.where("createdAt", ">=", (now - timedelta(days=7)).isoformat())),
                "new30": _count(users.where("createdAt", ">=", (now - timedelta(days=30)).isoformat())),
                "byEdition": {e: _count(users.where("edition", "==", e)) for e in EDITIONS},
                "byPlan": {p: _count(users.where("plan", "==", p)) for p in plans.PAID},
                "activeToday": today["active"], "activeWeek": len(weekly_active),
            },
            "ai": {
                "requestsToday": today["requests"], "requests7": sum(d["requests"] for d in week),
                "costToday": today["costUsd"], "cost30": round(sum(d["costUsd"] for d in series), 2),
                "tokens30": sum(d["inputTokens"] + d["outputTokens"] for d in series),
                "byFeature": features, "paused": bool(flags.get().get("aiPaused")),
                "freeDailyUsd": plans.budgets("free", flags.free_daily_usd())[0],
            },
            "enterprise": {"orgs": org_count, "month": month, "revenueMonth": round(revenue, 2),
                           "lastMonth": last_month, "revenueLastMonth": round(last_revenue, 2)},
            "series": series,
            "maintenance": flags.get().get("maintenance"),
        }

    @bp.get("/admin/api/overview")
    @guarded
    def overview():
        days = max(7, min(request.args.get("days", 30, type=int), 90))
        return jsonify(cached(("overview", days), lambda: _overview(days)))

    # ── users ────────────────────────────────────────────────────────

    def _user_row(uid: str, d: dict) -> dict:
        return {
            "plan": plans.plan_of(d), "planStatus": d.get("planStatus"),
            "uid": uid, "displayName": d.get("displayName") or "", "email": d.get("email") or "",
            "edition": "enterprise" if d.get("orgId") else (d.get("edition") or "researchers"),
            "role": d.get("role") or "", "orgId": d.get("orgId"), "orgRole": d.get("orgRole"),
            "createdAt": _iso(d.get("createdAt")), "onboarded": bool(d.get("onboarded")),
        }

    def _users(q: str, edition: str) -> dict:
        col = _db().collection("users")
        if q:
            rows: dict[str, dict] = {}
            snap = col.document(q).get() if re.fullmatch(r"[A-Za-z0-9]{10,40}", q) else None
            if snap is not None and snap.exists:
                rows[snap.id] = snap.to_dict() or {}
            for field, value in (("email", q), ("email", q.lower())):
                for s in col.where(field, "==", value).limit(10).get():
                    rows[s.id] = s.to_dict() or {}
            for s in col.where("displayName", ">=", q).where("displayName", "<", q + "").limit(20).get():
                rows[s.id] = s.to_dict() or {}
            items = list(rows.items())
        elif edition in EDITIONS:
            items = [(s.id, s.to_dict() or {}) for s in col.where("edition", "==", edition).limit(60).get()]
        else:
            items = [(s.id, s.to_dict() or {}) for s in col.order_by("createdAt", direction=firestore.Query.DESCENDING).limit(60).get()]
        out = [_user_row(uid, d) for uid, d in items]
        out.sort(key=lambda r: r["createdAt"] or "", reverse=True)
        return {"users": out}

    @bp.get("/admin/api/users")
    @guarded
    def users():
        q = (request.args.get("q") or "").strip()[:120]
        edition = request.args.get("edition") or ""
        return jsonify(cached(("users", q, edition), lambda: _users(q, edition)))

    def _user_detail(uid: str) -> dict:
        db = _db()
        snap = db.document(f"users/{uid}").get()
        if not snap.exists:
            raise StaffError(404, "user_not_found", "No user with that id.")
        d = snap.to_dict() or {}
        try:
            a = fb_auth.get_user(uid)
            auth_info = {
                "disabled": a.disabled, "emailVerified": a.email_verified,
                "providers": [p.provider_id for p in a.provider_data],
                "createdAt": a.user_metadata.creation_timestamp, "lastSignInAt": a.user_metadata.last_sign_in_timestamp,
            }
        except Exception:  # noqa: BLE001
            auth_info = None
        usage = db.document(f"users/{uid}/meta/usage").get().to_dict() or {}
        today = _now().strftime("%Y-%m-%d")
        meter = orgs.usage_for(uid)
        counts = {c: _count(db.collection(f"users/{uid}/{c}")) for c in ("materials", "reports", "sessions", "conversations", "categories")}
        devices = [{"id": x.id, "label": (x.to_dict() or {}).get("label"), "platform": (x.to_dict() or {}).get("platform"),
                    "lastActiveAt": _iso((x.to_dict() or {}).get("lastActiveAt")), "revoked": bool((x.to_dict() or {}).get("revoked"))}
                   for x in db.collection(f"users/{uid}/devices").limit(20).get()]
        org = None
        if d.get("orgId"):
            o = db.document(f"orgs/{d['orgId']}").get().to_dict() or {}
            org = {"id": d["orgId"], "name": o.get("name"), "role": d.get("orgRole")}
        tin, tout = int(usage.get("inputTokens") or 0), int(usage.get("outputTokens") or 0)
        return {
            "user": _user_row(uid, d), "interests": d.get("interests") or [], "auth": auth_info, "org": org, "counts": counts,
            "usage": {"total": int(usage.get("total") or 0), "inputTokens": tin, "outputTokens": tout,
                      "costUsd": round(float(usage.get("costUsd") or 0) or _cost(tin, tout), 2),
                      "todayUsd": round(float(usage.get("dayCost") or 0), 3) if usage.get("day") == today else 0,
                      "meter": meter.get("usage")},
            "plan": {"id": meter["plan"], "status": meter.get("planStatus"), "endsAt": meter.get("planEndsAt"),
                     "paystack": bool((d.get("paystack") or {}).get("subscriptionCode"))},
            "devices": devices,
        }

    @bp.get("/admin/api/users/<uid>")
    @guarded
    def user(uid: str):
        uid = _clean_id(uid)
        return jsonify(cached(("user", uid), lambda: _user_detail(uid)))

    @bp.post("/admin/api/users/<uid>/edition")
    @guarded
    def user_edition(uid: str):
        uid = _clean_id(uid)
        edition = body().get("edition")
        if edition not in ("students", "researchers"):
            raise StaffError(400, "bad_edition", "Pick Students or Researchers. Enterprise comes from joining an organisation.")
        if orgs.user_profile(uid, fresh=True).get("orgId"):
            raise StaffError(409, "in_org", "This user is in an organisation. Remove them from it first.")
        _db().document(f"users/{uid}").set({"edition": edition}, merge=True)
        orgs._forget(uid)
        audit("user_edition", uid, {"edition": edition})
        return jsonify(ok=True)

    @bp.post("/admin/api/users/<uid>/disable")
    @guarded
    def user_disable(uid: str):
        uid = _clean_id(uid)
        d = body()
        disabled = bool(d.get("disabled"))
        if disabled and str(d.get("confirm") or "") != "DISABLE":
            raise StaffError(400, "confirm", "Type DISABLE to confirm.")
        fb_auth.update_user(uid, disabled=disabled)
        if disabled:
            fb_auth.revoke_refresh_tokens(uid)
            _revoke_devices(uid)
        audit("user_disable" if disabled else "user_enable", uid, {"reason": str(d.get("reason") or "")[:300]})
        return jsonify(ok=True, disabled=disabled)

    def _revoke_devices(uid: str) -> int:
        db = _db()
        docs = db.collection(f"users/{uid}/devices").get()
        batch = db.batch()
        for x in docs:
            batch.set(x.reference, {"revoked": True}, merge=True)
        batch.commit()
        return len(docs)

    @bp.post("/admin/api/users/<uid>/signout")
    @guarded
    def user_signout(uid: str):
        uid = _clean_id(uid)
        fb_auth.revoke_refresh_tokens(uid)
        n = _revoke_devices(uid)
        audit("user_signout", uid, {"devices": n})
        return jsonify(ok=True, devices=n)

    @bp.post("/admin/api/users/<uid>/reset-allowance")
    @guarded
    def user_reset(uid: str):
        uid = _clean_id(uid)
        _db().document(f"users/{uid}/meta/usage").set({"dayCost": 0, "monthCost": 0}, merge=True)
        audit("user_reset_allowance", uid)
        return jsonify(ok=True)

    @bp.post("/admin/api/users/<uid>/plan")
    @guarded
    def user_plan(uid: str):
        """Give someone a plan for free for N days (a gift, a refund, a tester),
        or put them back on Free. Paid Paystack subscriptions are not touched."""
        uid = _clean_id(uid)
        d = body()
        plan = d.get("plan")
        if plan not in ("free", *plans.PAID):
            raise StaffError(400, "bad_plan", "Pick free, student_plus, research_plus or max.")
        if plan == "free":
            doc = {"plan": "free", "planStatus": None, "planEndsAt": None}
        else:
            days = d.get("days", 30)
            if not isinstance(days, int) or not 1 <= days <= 366:
                raise StaffError(400, "bad_days", "Give between 1 and 366 days.")
            # "cancelled" with an end date: it simply expires, nothing renews.
            doc = {"plan": plan, "planStatus": "cancelled", "planEndsAt": _now() + timedelta(days=days), "planGrantedBy": g.actor}
        _db().document(f"users/{uid}").set(doc, merge=True)
        orgs._forget(uid)
        audit("user_plan", uid, {"plan": plan, "days": d.get("days")})
        return jsonify(ok=True)

    # ── organisations ────────────────────────────────────────────────

    def _org_row(oid: str, o: dict) -> dict:
        return {"id": oid, "name": o.get("name") or "", "ownerUid": o.get("ownerUid"), "createdAt": _iso(o.get("createdAt"))}

    @bp.get("/admin/api/orgs")
    @guarded
    def org_list():
        def build():
            month = _now().strftime("%Y-%m")
            out = []
            for o in _db().collection("orgs").limit(200).get():
                row = _org_row(o.id, o.to_dict() or {})
                row["members"] = _count(_db().collection(f"orgs/{o.id}/members"))
                try:
                    row["month"] = orgs.bill_for(orgs.month_usage(o.id, month)[0])
                except Exception:  # noqa: BLE001
                    row["month"] = None
                out.append(row)
            out.sort(key=lambda r: (r["month"] or {}).get("totalUsd", 0), reverse=True)
            return {"orgs": out, "month": month}
        return jsonify(cached("orgs", build))

    def _org_detail(oid: str) -> dict:
        db = _db()
        o = db.document(f"orgs/{oid}").get()
        if not o.exists:
            raise StaffError(404, "org_not_found", "No organisation with that id.")
        members = [{"uid": m.id, "name": (m.to_dict() or {}).get("name"), "email": (m.to_dict() or {}).get("email"),
                    "role": (m.to_dict() or {}).get("role"), "joinedAt": _iso((m.to_dict() or {}).get("joinedAt"))}
                   for m in db.collection(f"orgs/{oid}/members").get()]
        recorded = {d.id: d.to_dict() or {} for d in db.collection(f"orgs/{oid}/invoices").get()}
        months = sorted({d.id[:7] for d in db.collection(f"orgs/{oid}/usage").select([]).get()}, reverse=True)[:12]
        current = _now().strftime("%Y-%m")
        invoices = []
        for m in months:
            bill = orgs.bill_for(orgs.month_usage(oid, m)[0])
            rec = recorded.get(m, {})
            invoices.append({"month": m, **bill, "status": rec.get("status") or ("open" if m == current else "due"),
                             "note": rec.get("note"), "paidAt": _iso(rec.get("paidAt"))})
        days, daily = orgs.month_usage(oid, current)
        return {"org": _org_row(oid, o.to_dict() or {}), "inviteCode": (o.to_dict() or {}).get("inviteCode"),
                "members": members, "invoices": invoices, "daily": daily, "estimate": orgs.bill_for(days)}

    @bp.get("/admin/api/orgs/<oid>")
    @guarded
    def org_detail(oid: str):
        oid = _clean_id(oid)
        return jsonify(cached(("org", oid), lambda: _org_detail(oid)))

    @bp.post("/admin/api/orgs/<oid>/invoices/<month>")
    @guarded
    def org_invoice(oid: str, month: str):
        oid = _clean_id(oid)
        if not re.fullmatch(r"\d{4}-\d{2}", month) or month >= _now().strftime("%Y-%m"):
            raise StaffError(400, "bad_month", "Only completed months can be settled.")
        d = body()
        status = d.get("status")
        if status not in ("paid", "waived", "due"):
            raise StaffError(400, "bad_status", "Use paid, waived or due.")
        bill = orgs.bill_for(orgs.month_usage(oid, month)[0])
        _db().document(f"orgs/{oid}/invoices/{month}").set({
            "status": status, "amountUsd": bill["totalUsd"], "note": str(d.get("note") or "")[:300],
            "paidAt": _now() if status == "paid" else None, "settledBy": g.actor, "method": "manual",
        }, merge=True)
        audit("invoice_" + status, f"{oid}/{month}", {"amountUsd": bill["totalUsd"], "note": str(d.get("note") or "")[:300]})
        return jsonify(ok=True)

    @bp.post("/admin/api/orgs/<oid>/members/<uid>/remove")
    @guarded
    def org_remove(oid: str, uid: str):
        oid, uid = _clean_id(oid), _clean_id(uid)
        if orgs.user_profile(uid, fresh=True).get("orgId") != oid:
            raise StaffError(409, "not_member", "That user isn't in this organisation.")
        orgs._detach(oid, uid)
        audit("org_remove_member", f"{oid}/{uid}")
        return jsonify(ok=True)

    # ── community content ────────────────────────────────────────────

    @bp.get("/admin/api/papers")
    @guarded
    def papers():
        def build():
            rows = []
            for p in _db().collection("papers").order_by("count", direction=firestore.Query.DESCENDING).limit(60).get():
                d = p.to_dict() or {}
                n = int(d.get("count") or 0)
                rows.append({"key": p.id, "title": d.get("title") or p.id, "count": n,
                             "average": round(int(d.get("sum") or 0) / n, 2) if n else None})
            return {"papers": rows}
        return jsonify(cached("papers", build))

    @bp.post("/admin/api/papers/<path:key>/clear")
    @guarded
    def paper_clear(key: str):
        key = _clean_id(key, 120)
        db = _db()
        ref = db.document(f"papers/{key}")
        ratings = ref.collection("ratings").get()
        for i in range(0, len(ratings), 400):
            batch = db.batch()
            for r in ratings[i:i + 400]:
                batch.delete(r.reference)
            batch.commit()
        ref.set({"sum": 0, "count": 0}, merge=True)
        audit("paper_clear_ratings", key, {"removed": len(ratings)})
        return jsonify(ok=True, removed=len(ratings))

    @bp.get("/admin/api/rooms")
    @guarded
    def rooms():
        def build():
            out = []
            for r in _db().collection("rooms").where("endedAt", "==", None).limit(60).get():
                d = r.to_dict() or {}
                out.append({"id": r.id, "title": d.get("title"), "host": d.get("hostName"), "hostUid": d.get("hostUid"),
                            "members": len(d.get("memberUids") or []), "papers": len(d.get("papers") or []),
                            "createdAt": _iso(d.get("createdAt"))})
            out.sort(key=lambda r: r["createdAt"] or "", reverse=True)
            return {"rooms": out}
        return jsonify(cached("rooms", build))

    @bp.post("/admin/api/rooms/<rid>/end")
    @guarded
    def room_end(rid: str):
        rid = _clean_id(rid)
        _db().document(f"rooms/{rid}").set({"endedAt": firestore.SERVER_TIMESTAMP, "focusUntil": None}, merge=True)
        audit("room_end", rid)
        return jsonify(ok=True)

    # ── switches ─────────────────────────────────────────────────────

    @bp.get("/admin/api/flags")
    @guarded
    def flags_get():
        f = flags.get(fresh=True)
        return jsonify({**f, "defaultFreeDailyUsd": plans.PLANS["free"]["dailyUsd"], "model": plans.BEST_MODEL, "fastModel": plans.FAST_MODEL,
                        "plans": [{**p} for p in plans.PLANS.values()],
                        "aiKeySet": bool(os.getenv("ANTHROPIC_API_KEY"))})

    @bp.post("/admin/api/flags")
    @guarded
    def flags_set():
        d = body()
        fields: dict[str, Any] = {}
        if "aiPaused" in d:
            fields["aiPaused"] = bool(d["aiPaused"])
        if "aiPausedMessage" in d:
            fields["aiPausedMessage"] = str(d["aiPausedMessage"] or "").strip()[:200] or flags.DEFAULTS["aiPausedMessage"]
        if "freeDailyUsd" in d:
            v = d["freeDailyUsd"]
            if v in (None, ""):
                fields["freeDailyUsd"] = None
            else:
                try:
                    v = float(v)
                except (TypeError, ValueError):
                    raise StaffError(400, "bad_limit", "The daily budget must be a number of dollars.") from None
                if not 0 <= v <= 5:
                    raise StaffError(400, "bad_limit", "Pick a daily budget from $0 to $5 per user.")
                fields["freeDailyUsd"] = round(v, 3)
        if not fields:
            raise StaffError(400, "nothing", "Nothing to change.")
        out = flags.update(fields, g.actor)
        audit("flags", "", fields)
        return jsonify(out)

    @bp.get("/admin/api/audit")
    @guarded
    def audit_log():
        rows = []
        for a in _db().collection("admin_audit").order_by("at", direction=firestore.Query.DESCENDING).limit(80).get():
            d = a.to_dict() or {}
            rows.append({"at": _iso(d.get("at")), "actor": d.get("actor"), "ip": d.get("ip"), "action": d.get("action"),
                         "target": d.get("target"), "detail": d.get("detail")})
        return jsonify(rows=rows)

    # ── blog ─────────────────────────────────────────────────────────

    @bp.get("/admin/api/blog")
    @guarded
    def blog_list():
        import blog
        return jsonify(posts=blog.list_posts(include_drafts=True))

    @bp.get("/admin/api/blog/<slug>")
    @guarded
    def blog_get(slug):
        import blog
        post = blog.get_post(slug, include_drafts=True)
        if not post:
            raise StaffError(404, "not_found", "No post with that address.")
        return jsonify(post)

    @bp.post("/admin/api/blog")
    @guarded
    def blog_save():
        import blog
        try:
            post = blog.save_post(body(), g.actor)
        except blog.BlogError as e:
            raise StaffError(e.status, "blog", str(e)) from None
        audit("blog_save", post["slug"], {"published": post["published"]})
        return jsonify(post)

    @bp.post("/admin/api/blog/<slug>/delete")
    @guarded
    def blog_delete(slug):
        import blog
        try:
            blog.delete_post(slug)
        except blog.BlogError as e:
            raise StaffError(e.status, "blog", str(e)) from None
        audit("blog_delete", slug)
        return jsonify(ok=True)

    # ── feedback: Rate DSCVR ─────────────────────────────────────────

    @bp.get("/admin/api/ratings")
    @guarded
    def app_ratings():
        def build():
            rows, total, dist = [], 0, {str(i): 0 for i in range(1, 6)}
            for snap in _db().collection("app_ratings").limit(2000).get():
                d = snap.to_dict() or {}
                stars = int(d.get("stars") or 0)
                if not 1 <= stars <= 5:
                    continue
                total += stars
                dist[str(stars)] += 1
                rows.append({"uid": snap.id, "stars": stars, "comment": d.get("comment") or "", "at": _iso(d.get("at")),
                             "name": d.get("name"), "email": d.get("email"), "edition": d.get("edition"), "plan": d.get("plan")})
            rows.sort(key=lambda r: r["at"] or "", reverse=True)
            n = len(rows)
            return {"count": n, "average": round(total / n, 2) if n else None, "distribution": dist, "ratings": rows[:200]}
        return jsonify(cached("ratings", build))

    # ── emails: product updates ──────────────────────────────────────

    @bp.get("/admin/api/emails")
    @guarded
    def emails_info():
        import mailer
        def build():
            return {"configured": mailer.configured(), "recipients": len(mailer.recipients())}
        return jsonify(cached("emails", build))

    @bp.post("/admin/api/emails/send")
    @guarded
    def emails_send():
        import mailer
        d = body()
        subject, text = str(d.get("subject") or ""), str(d.get("body") or "")
        if d.get("test"):
            to = str(d.get("to") or "").strip()
            if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", to):
                raise StaffError(400, "bad_email", "Enter the email address to send the test to.")
            targets = [{"uid": "test", "email": to, "name": "there"}]
        else:
            if d.get("confirm") != "SEND":
                raise StaffError(400, "confirm", "Confirm before sending to everyone.")
            targets = mailer.recipients()
        try:
            out = mailer.send(subject, text, targets)
        except mailer.MailError as e:
            raise StaffError(e.status, "mail", str(e)) from None
        audit("email_test" if d.get("test") else "email_send", subject[:150], out)
        return jsonify(out)

    return bp
