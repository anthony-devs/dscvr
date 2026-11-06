"""Plus and Max subscriptions through Paystack.

Set up once in the Paystack dashboard (Products > Plans), one monthly plan per
paid tier, then put the plan codes and your secret key on the server:

    PAYSTACK_SECRET_KEY            sk_live_... (or sk_test_... while testing)
    PAYSTACK_PLAN_STUDENT_PLUS     PLN_...
    PAYSTACK_PLAN_RESEARCH_PLUS    PLN_...
    PAYSTACK_PLAN_MAX              PLN_...
    PAYSTACK_CALLBACK_URL          where Paystack sends people after paying,
                                   e.g. https://dscvr-9d362.web.app/plans?paid=1

and point the Paystack webhook (Settings > API Keys & Webhooks) at
    https://<server>/billing/paystack/webhook

Flow: the app asks /billing/checkout for a payment page, the user pays on
Paystack, Paystack calls our webhook, and the webhook switches the plan on.
The plan lives on users/{uid}: plan, planStatus, planEndsAt, paystack{...}.
Clients can't write those fields (Firestore rules).

With no PAYSTACK_SECRET_KEY, checkout answers 503 and nothing is charged.
"""
from __future__ import annotations

import hashlib
import hmac
import logging
import os
from datetime import datetime, timezone
from typing import Any

import requests

import plans
from security import get_firestore_client

log = logging.getLogger("billing")
API = "https://api.paystack.co"


class BillingError(Exception):
    def __init__(self, message: str, status: int = 400):
        super().__init__(message)
        self.status = status


def _secret() -> str:
    return os.getenv("PAYSTACK_SECRET_KEY", "")


def enabled() -> bool:
    return bool(_secret()) and all(plan_code(p) for p in plans.PAID)


def plan_code(plan: str) -> str:
    return os.getenv(f"PAYSTACK_PLAN_{plan.upper()}", "")


def _plan_for_code(code: str | None) -> str | None:
    for p in plans.PAID:
        if code and plan_code(p) == code:
            return p
    return None


def _call(method: str, path: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
    r = requests.request(method, API + path, json=body, timeout=20,
                         headers={"Authorization": f"Bearer {_secret()}", "Content-Type": "application/json"})
    try:
        data = r.json()
    except ValueError:
        data = {}
    if r.status_code >= 400 or not data.get("status"):
        log.warning("paystack %s %s -> %s %s", method, path, r.status_code, str(data)[:300])
        raise BillingError(data.get("message") or "Payment provider error. Try again shortly.", 502)
    return data.get("data") or {}


def _db():
    return get_firestore_client()


def _ts(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


# ── Checkout ─────────────────────────────────────────────────────────

def checkout(uid: str, email: str | None, plan: str) -> dict[str, Any]:
    if plan not in plans.PAID:
        raise BillingError("Pick Student Plus, Research Plus or Max.")
    if not enabled():
        raise BillingError("Payments aren't switched on yet. Please check back soon.", 503)
    profile = _db().document(f"users/{uid}").get().to_dict() or {}
    if profile.get("orgId"):
        raise BillingError("Your organisation already covers your usage.", 409)
    email = email or profile.get("email")
    if not email:
        raise BillingError("Add an email address to your account first.")
    data = _call("POST", "/transaction/initialize", {
        "email": email,
        "amount": int(round(plans.PLANS[plan]["priceUsd"] * 100)),  # Paystack uses the plan's own amount
        "plan": plan_code(plan),
        "callback_url": os.getenv("PAYSTACK_CALLBACK_URL") or None,
        "metadata": {"uid": uid, "plan": plan},
    })
    return {"url": data.get("authorization_url"), "reference": data.get("reference")}


def verify(uid: str, reference: str) -> dict[str, Any]:
    """Called when the user lands back in the app, so the plan switches on
    straight away even if the webhook is a few seconds behind."""
    if not enabled():
        raise BillingError("Payments aren't switched on yet.", 503)
    data = _call("GET", f"/transaction/verify/{requests.utils.quote(reference, safe='')}")
    meta = data.get("metadata") or {}
    if isinstance(meta, str):
        meta = {}
    if meta.get("uid") != uid:
        raise BillingError("That payment belongs to another account.", 403)
    if data.get("status") == "success":
        _activate(uid, meta.get("plan") or _plan_for_code((data.get("plan_object") or {}).get("plan_code")),
                  data.get("customer") or {})
    return {"status": data.get("status")}


def cancel(uid: str) -> dict[str, Any]:
    """Stops renewal. The plan stays on until the end of the paid month."""
    ref = _db().document(f"users/{uid}")
    profile = ref.get().to_dict() or {}
    ps = profile.get("paystack") or {}
    if not ps.get("subscriptionCode") or not ps.get("emailToken"):
        raise BillingError("No active subscription to cancel.", 404)
    _call("POST", "/subscription/disable", {"code": ps["subscriptionCode"], "token": ps["emailToken"]})
    ref.set({"planStatus": "cancelled"}, merge=True)
    _forget(uid)
    return {"ok": True}


# ── Webhook ──────────────────────────────────────────────────────────

def valid_signature(raw: bytes, signature: str) -> bool:
    if not _secret() or not signature:
        return False
    want = hmac.new(_secret().encode(), raw, hashlib.sha512).hexdigest()
    return hmac.compare_digest(want, signature)


def _forget(uid: str) -> None:
    try:
        import orgs
        orgs._forget(uid)
    except Exception:  # noqa: BLE001
        pass


def _uid_for_customer(customer: dict[str, Any]) -> str | None:
    code = customer.get("customer_code")
    if code:
        hits = _db().collection("users").where("paystack.customerCode", "==", code).limit(1).get()
        if hits:
            return hits[0].id
    email = customer.get("email")
    if email:
        hits = _db().collection("users").where("email", "==", email).limit(1).get()
        if hits:
            return hits[0].id
    return None


def _activate(uid: str, plan: str | None, customer: dict[str, Any], ends: datetime | None = None) -> None:
    if plan not in plans.PAID:
        return
    doc: dict[str, Any] = {"plan": plan, "planStatus": "active", "planUpdatedAt": datetime.now(timezone.utc)}
    if ends:
        doc["planEndsAt"] = ends
    if customer.get("customer_code"):
        doc["paystack"] = {"customerCode": customer["customer_code"]}
    _db().document(f"users/{uid}").set(doc, merge=True)
    _forget(uid)


def handle_event(event: dict[str, Any]) -> str:
    kind = event.get("event") or ""
    data = event.get("data") or {}
    customer = data.get("customer") or {}
    meta = data.get("metadata") if isinstance(data.get("metadata"), dict) else {}
    uid = (meta or {}).get("uid") or _uid_for_customer(customer)
    if not uid:
        log.warning("paystack %s: no matching user", kind)
        return "ignored"
    plan_obj = data.get("plan") if isinstance(data.get("plan"), dict) else {}
    plan = (meta or {}).get("plan") or _plan_for_code(plan_obj.get("plan_code"))
    ref = _db().document(f"users/{uid}")

    if kind == "charge.success":
        _activate(uid, plan or (ref.get().to_dict() or {}).get("plan"), customer)
    elif kind == "subscription.create":
        _activate(uid, plan, customer, _ts(data.get("next_payment_date")))
        ref.set({"paystack": {"customerCode": customer.get("customer_code"), "subscriptionCode": data.get("subscription_code"),
                              "emailToken": data.get("email_token")}}, merge=True)
    elif kind in ("subscription.not_renew", "subscription.disable"):
        ref.set({"planStatus": "cancelled", "planEndsAt": _ts(data.get("next_payment_date")) or datetime.now(timezone.utc)}, merge=True)
    elif kind == "invoice.payment_failed":
        ref.set({"planStatus": "past_due"}, merge=True)
    elif kind == "invoice.update" and (data.get("paid") or data.get("status") == "success"):
        sub = data.get("subscription") or {}
        ref.set({"planStatus": "active", "planEndsAt": _ts(sub.get("next_payment_date"))}, merge=True)
    else:
        return "ignored"
    _forget(uid)
    return "ok"
