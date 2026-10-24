"""DSCVR API Server — Python Flask.

Endpoints:
  GET   /discover          arXiv / Semantic Scholar proxy (CORS-safe)
  POST  /payments/verify   Verify a Google Pay token and activate subscription
  POST  /payments/cancel   Cancel subscription at period end
  GET   /payments/status   Get current subscription status
  GET   /health            Health check

All endpoints that touch user data require a Firebase Bearer token.
The server verifies tokens directly with Firebase Admin SDK.
"""
from __future__ import annotations

import logging
import os

from flask import Flask, g, jsonify, request
from flask_cors import CORS

from config import Config
from discover import search_arxiv, search_semantic_scholar
from payments import (
    PRICING,
    activate_subscription,
    cancel_subscription,
    get_subscription,
    verify_google_pay_token,
)
from security import (
    check_body_size,
    check_rate,
    init_firebase,
    log_usage,
    optional_auth,
    require_auth,
    sanitize,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def create_app(config: Config | None = None) -> Flask:
    app = Flask(__name__)

    if config is None:
        config = Config()

    # CORS — allow the web app and localhost
    CORS(
        app,
        origins=config.ALLOWED_ORIGINS,
        allow_headers=["Authorization", "Content-Type"],
        methods=["GET", "POST", "OPTIONS"],
        max_age=3600,
    )

    # Init Firebase Admin
    init_firebase(config.FIREBASE_PROJECT_ID)

    # ── Health ───────────────────────────────────────────────────────

    @app.route("/health")
    def health():
        return jsonify(status="ok", service="dscvr-server")

    # ── Discover (CORS proxy) ────────────────────────────────────────

    @app.route("/discover")
    @optional_auth
    def discover():
        # Rate limit by uid or IP
        identity = g.uid or request.remote_addr or "anon"
        rate_err = check_rate(identity, "discover")
        if rate_err:
            return jsonify(error=rate_err), 429

        q = sanitize(request.args.get("q", ""), 300)
        source = sanitize(request.args.get("source", "arxiv"), 30)
        sort = "date" if request.args.get("sort") == "date" else "relevance"
        try:
            limit = min(max(int(request.args.get("limit", 20)), 1), 50)
        except (ValueError, TypeError):
            limit = 20

        if not q:
            return jsonify(error="Provide q"), 400

        try:
            if source == "semantic_scholar":
                papers = search_semantic_scholar(q, limit)
            else:
                papers = search_arxiv(q, sort, limit)

            resp = jsonify(papers=papers)
            resp.cache_control.public = True
            resp.cache_control.max_age = 600
            return resp

        except Exception as e:
            logger.warning("Discover failed: %s", e)
            return jsonify(error="Search provider unavailable"), 502

    # ── Payments: Google Pay ─────────────────────────────────────────

    @app.route("/payments/verify", methods=["POST"])
    @require_auth
    def payments_verify():
        if check_body_size(64 * 1024):
            return jsonify(error="Request too large."), 413

        rate_err = check_rate(g.uid, "checkout")
        if rate_err:
            return jsonify(error=rate_err), 429

        log_usage(g.uid, "checkout")

        body = request.get_json(silent=True) or {}
        tier = sanitize(body.get("tier", ""), 10)
        interval = sanitize(body.get("interval", ""), 10)
        token_data = body.get("paymentToken")

        if tier not in ("pro", "team"):
            return jsonify(error="Invalid tier. Choose 'pro' or 'team'."), 400
        if interval not in ("monthly", "yearly"):
            return jsonify(error="Invalid interval. Choose 'monthly' or 'yearly'."), 400
        if not token_data or not isinstance(token_data, dict):
            return jsonify(error="Missing Google Pay payment token."), 400

        # Verify with Google Pay / gateway
        result = verify_google_pay_token(token_data)
        if not result.get("success"):
            return jsonify(error=result.get("error", "Payment failed.")), 402

        # Activate subscription in Firestore
        try:
            sub = activate_subscription(g.uid, tier, interval, result)
            return jsonify(
                success=True,
                subscription=sub,
                message=f"Welcome to DSCVR {tier.title()}!",
            )
        except Exception as e:
            logger.exception("Subscription activation failed")
            return jsonify(error="Could not activate subscription. Try again."), 500

    @app.route("/payments/cancel", methods=["POST"])
    @require_auth
    def payments_cancel():
        rate_err = check_rate(g.uid, "portal")
        if rate_err:
            return jsonify(error=rate_err), 429

        try:
            result = cancel_subscription(g.uid)
            return jsonify(success=True, **result)
        except Exception as e:
            logger.exception("Cancellation failed")
            return jsonify(error="Could not cancel. Try again."), 500

    @app.route("/payments/status")
    @require_auth
    def payments_status():
        rate_err = check_rate(g.uid, "portal")
        if rate_err:
            return jsonify(error=rate_err), 429

        try:
            sub = get_subscription(g.uid)
            return jsonify(subscription=sub)
        except Exception as e:
            logger.exception("Status check failed")
            return jsonify(error="Could not read subscription."), 500

    # ── Pricing info (public) ────────────────────────────────────────

    @app.route("/payments/pricing")
    def payments_pricing():
        return jsonify(pricing=PRICING, currency="usd")

    # ── Error handlers ───────────────────────────────────────────────

    @app.errorhandler(404)
    def not_found(_):
        return jsonify(error="Not found"), 404

    @app.errorhandler(500)
    def internal(_):
        return jsonify(error="Internal server error"), 500

    return app


# ── Entry point ──────────────────────────────────────────────────────

if __name__ == "__main__":
    app = create_app()
    port = int(os.getenv("PORT", 8080))
    app.run(host="0.0.0.0", port=port, debug=Config.DEBUG)
