"""Google Pay payment verification and subscription management.

Flow:
  1. Client shows Google Pay button (via pay package in Flutter).
  2. User authorises → client receives a payment token from Google.
  3. Client POSTs the token + tier + interval to /payments/verify.
  4. This server verifies the token with the payment processor,
     then writes the subscription to Firestore.
  5. For production, connect a payment processor (Adyen, Braintree,
     Stripe-via-Google-Pay) that actually charges the token.
     The verify endpoint is processor-agnostic: swap the
     _process_payment() body.

Google Pay token structure (simplified):
  {
    "apiVersion": 2,
    "apiVersionMinor": 0,
    "paymentMethodData": {
      "type": "CARD",
      "tokenizationData": {
        "type": "PAYMENT_GATEWAY",
        "token": "<encrypted token from gateway>"
      },
      "info": { "cardNetwork": "VISA", "cardDetails": "1234" }
    }
  }
"""
from __future__ import annotations

import json
import logging
from datetime import datetime, timedelta, timezone
from typing import Any

from firebase_admin import firestore

from security import get_firestore_client

logger = logging.getLogger(__name__)

# Pricing table (cents)
PRICING = {
    "pro": {"monthly": 1200, "yearly": 9600},
    "team": {"monthly": 2900, "yearly": 24000},
}


def verify_google_pay_token(token_data: dict[str, Any]) -> dict[str, Any]:
    """Verify and process a Google Pay payment token.

    In production, this calls your payment gateway (Adyen / Braintree / Stripe)
    to charge the token. For now it validates the structure and returns
    the card info for confirmation.

    Returns:
        {"success": True, "card_network": "VISA", "card_details": "1234"}
        or {"success": False, "error": "reason"}
    """
    try:
        pmd = token_data.get("paymentMethodData", {})
        token_type = pmd.get("type", "")
        tokenization = pmd.get("tokenizationData", {})
        tok_type = tokenization.get("type", "")
        raw_token = tokenization.get("token", "")

        if not raw_token:
            return {"success": False, "error": "Missing payment token."}

        card_info = pmd.get("info", {})
        card_network = card_info.get("cardNetwork", "UNKNOWN")
        card_details = card_info.get("cardDetails", "****")

        # ── Production: send raw_token to your gateway here ──────────
        # Example with Stripe:
        #   charge = stripe.Charge.create(
        #       amount=amount_cents,
        #       currency="usd",
        #       source=raw_token,
        #       description="DSCVR subscription",
        #   )
        #
        # Example with Adyen:
        #   result = adyen.checkout.payments({
        #       "amount": {"value": amount_cents, "currency": "USD"},
        #       "paymentMethod": {"type": "paywithgoogle", "googlePayToken": raw_token},
        #       "reference": f"dscvr-{uid}-{tier}",
        #       "merchantAccount": ADYEN_MERCHANT,
        #   })
        # ─────────────────────────────────────────────────────────────

        return {
            "success": True,
            "card_network": card_network,
            "card_details": card_details,
        }

    except Exception as e:
        logger.exception("Google Pay verification failed")
        return {"success": False, "error": str(e)}


def activate_subscription(
    uid: str,
    tier: str,
    interval: str,
    payment_result: dict[str, Any],
) -> dict[str, Any]:
    """Write the subscription to Firestore after successful payment."""
    now = datetime.now(timezone.utc)
    if interval == "yearly":
        period_end = now + timedelta(days=365)
    else:
        period_end = now + timedelta(days=30)

    sub_data = {
        "tier": tier,
        "interval": interval,
        "currentPeriodEnd": period_end.isoformat(),
        "cancelAtPeriodEnd": False,
        "paymentMethod": "google_pay",
        "cardNetwork": payment_result.get("card_network", ""),
        "cardDetails": payment_result.get("card_details", ""),
        "activatedAt": now.isoformat(),
    }

    db = get_firestore_client()
    db.document(f"users/{uid}").set(
        {"subscription": sub_data},
        merge=True,
    )

    return {
        "tier": tier,
        "interval": interval,
        "currentPeriodEnd": period_end.isoformat(),
    }


def cancel_subscription(uid: str) -> dict[str, Any]:
    """Mark the subscription for cancellation at period end."""
    db = get_firestore_client()
    db.document(f"users/{uid}").set(
        {"subscription": {"cancelAtPeriodEnd": True}},
        merge=True,
    )
    return {"cancelled": True}


def get_subscription(uid: str) -> dict[str, Any]:
    """Read the user's current subscription from Firestore."""
    db = get_firestore_client()
    doc = db.document(f"users/{uid}").get()
    data = (doc.to_dict() or {}).get("subscription", {})
    return {
        "tier": data.get("tier", "free"),
        "interval": data.get("interval", "monthly"),
        "currentPeriodEnd": data.get("currentPeriodEnd"),
        "cancelAtPeriodEnd": data.get("cancelAtPeriodEnd", False),
        "paymentMethod": data.get("paymentMethod"),
    }
