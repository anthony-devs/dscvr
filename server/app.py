"""DSCVR API Server — Python Flask.

Endpoints:
  GET   /health                      Health check
  GET   /pricing                     Public pricing (all editions)

  Research
  GET   /discover                    search: source=all merges every free source; or one source
  GET   /pdf/find                    free PDF for a DOI (Unpaywall)
  GET   /pdf/view                    PDF bytes for the in-app viewer
  GET   /arxiv?ref=                  One arXiv paper by id or URL
  POST  /account/delete              Delete the caller's account and all their data
  GET   /blog/posts[/<slug>]         Published blog posts (public)
  POST  /me/sync, /me/email-updates  Email verified state; product update emails on/off
  GET   /referrals/me, POST /referrals/redeem
  GET/POST /feedback/rating          Rate DSCVR (1-5 stars)
  GET   /shares/<id>                 Read-only copy of a shared category or topic
  GET   /related                     Related papers (Semantic Scholar)
  POST  /pdf/import                  Copy a public PDF into the user's storage

  AI (Claude)
  POST  /pinda                       Streamed chat over the user's library (SSE)
  POST  /parliament                  Three-perspective fact-check
  POST  /reports/draft               Streamed cited report from chosen sources (SSE)
  POST  /sessions/summary            Summary of a focus or group session

  Plans (Paystack)
  GET   /billing/me                  Plan, usage meter, available plans
  POST  /billing/checkout            Paystack payment page for a plan
  POST  /billing/verify              Confirm a payment after returning from Paystack
  POST  /billing/cancel              Stop renewal at the end of the paid month
  POST  /billing/paystack/webhook    Paystack events (signed)

  Ratings
  GET   /ratings?keys=a,b            Community ratings for papers
  POST  /ratings                     Rate a paper 1-5

  Enterprise
  POST  /rooms/join                  Join a live group session by code

  POST  /activity                    Counts today's seat for enterprise members
  POST  /orgs                        Create an organisation
  GET   /orgs/me                     Organisation, members and usage estimate
  POST  /orgs/join                   Join with an invite code
  POST  /orgs/leave                  Leave the organisation
  POST  /orgs/invite/rotate          New invite code (admin)
  POST  /orgs/members/<uid>/remove   Remove a member (admin)
  POST  /orgs/members/<uid>/role     Change a member's role (admin)
  GET   /orgs/invoices               Monthly bills (admin)
  POST  /orgs/invoices/<month>/pay   Pay a completed month with Google Pay (admin)

All endpoints that touch user data require a Firebase Bearer token.
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
import os
import uuid
from urllib.parse import quote

import time

from flask import Flask, Response, g, got_request_exception, jsonify, request, stream_with_context
from flask_cors import CORS

import ai
import sources
import flags
import billing
import orgs
import plans
import shares
import blog
import referrals
import mailer
from admin import make_admin
from devapi import make_devapi
from metrics import metrics
from staff import Staff
from config import Config
from discover import (arxiv_by_id, cached, parse_arxiv_id, related_papers, s2_key_for, search_arxiv, search_europepmc,
                      search_openalex, search_semantic_scholar, search_uk_caselaw)
from fetch import UnsafeUrl, fetch_pdf
from payments import verify_google_pay_token
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

SCOPES = {"general", "category", "topic", "material", "selection"}
AI_PATHS = {"/pinda", "/reports/draft", "/sessions/summary", "/parliament"}
# Paths that keep working during maintenance: staff tools, and signals that cost nothing.
MAINTENANCE_OPEN = ("/admin", "/internal/dev", "/health", "/healthz", "/pricing", "/activity", "/billing/paystack", "/alerts/run")


def _ids(value) -> list[str]:
    if not isinstance(value, list):
        return []
    return [sanitize(v, 64) for v in value if isinstance(v, str) and v.strip()][:40]


def _edition(uid: str) -> str:
    profile = orgs.user_profile(uid)
    if profile.get("orgId"):
        return "enterprise"
    edition = profile.get("edition")
    return edition if edition in ("students", "researchers", "enterprise") else "researchers"


PROFESSIONS = {"medicine", "nursing", "pharmacy", "public_health", "law", "engineering", "business", "education"}


def _profession(uid: str) -> str | None:
    p = orgs.user_profile(uid).get("profession")
    return p if p in PROFESSIONS else None


def _sse_response(generator) -> Response:
    resp = Response(stream_with_context(generator), mimetype="text/event-stream")
    resp.headers["Cache-Control"] = "no-cache, no-transform"
    resp.headers["X-Accel-Buffering"] = "no"
    return resp


def create_app(config: Config | None = None) -> Flask:
    app = Flask(__name__)
    config = config or Config()

    CORS(
        app,
        origins=config.ALLOWED_ORIGINS,
        allow_headers=["Authorization", "Content-Type"],
        methods=["GET", "POST", "OPTIONS"],
        max_age=3600,
    )
    init_firebase(config.FIREBASE_PROJECT_ID)

    staff = Staff()
    app.register_blueprint(make_admin(staff))
    app.register_blueprint(make_devapi(staff))

    @app.before_request
    def _start_and_gate():
        g.t0 = time.perf_counter()
        path = request.path
        if request.method == "OPTIONS" or path.startswith(MAINTENANCE_OPEN):
            return None
        if path in AI_PATHS:
            if (why := flags.ai_block_message()):
                return jsonify(error=why, maintenance=True), 503
        m = flags.maintenance()
        if m and m.get("scope") == "all" and request.method == "POST":
            return jsonify(error=m.get("message") or "DSCVR is being updated. Back shortly.", maintenance=True), 503
        return None

    @app.after_request
    def _measure(resp):
        t0 = g.get("t0")
        if t0 is not None:
            metrics.record(request.path, resp.status_code, (time.perf_counter() - t0) * 1000)
        return resp

    def _on_exception(sender, exception, **extra):
        metrics.error(exception, request.path)

    got_request_exception.connect(_on_exception, app, weak=False)

    def limited(endpoint: str, identity: str | None = None):
        err = check_rate(identity or g.uid, endpoint)
        return (jsonify(error=err), 429) if err else None

    @app.errorhandler(orgs.OrgError)
    def org_error(e: orgs.OrgError):
        return jsonify(error=str(e)), e.status

    # ── Health & pricing ─────────────────────────────────────────────

    @app.route("/health")
    @app.route("/healthz")
    def health():
        return jsonify(ok=True, status="ok", service="dscvr-server", ai=bool(os.getenv("ANTHROPIC_API_KEY")),
                       alertsEmail=bool(os.getenv("RESEND_API_KEY") and os.getenv("ALERTS_FROM_EMAIL")))

    @app.route("/pricing")
    @app.route("/payments/pricing")
    def pricing():
        return jsonify(pricing=orgs.PRICING, plans=plans.public_plans(), currency="usd")

    # ── Research ─────────────────────────────────────────────────────

    @app.route("/discover")
    @optional_auth
    def discover():
        if (r := limited("discover", g.uid or request.remote_addr or "anon")):
            return r
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
            if source == "all":
                only = [x for x in sanitize(request.args.get("only", ""), 200).split(",") if x] or None
                result = sources.search_all(q, limit, sort, only, open_access=request.args.get("oa") == "1")
                resp = jsonify(result)
                resp.cache_control.public = True
                resp.cache_control.max_age = 600
                return resp
            if source == "semantic_scholar":
                papers = cached(("s2", q, limit), lambda: search_semantic_scholar(q, limit))
            elif source == "openalex":
                papers = cached(("oa", q, sort, limit), lambda: search_openalex(q, limit, sort))
            elif source == "europepmc":
                guidelines = request.args.get("type") == "guidelines"
                papers = cached(("pmc", q, sort, limit, guidelines), lambda: search_europepmc(q, limit, sort, guidelines))
            elif source == "uk_caselaw":
                court = sanitize(request.args.get("court", ""), 20)
                papers = cached(("ukcl", q, limit, court), lambda: search_uk_caselaw(q, limit, court))
            else:
                papers = cached(("arxiv", q, sort, limit), lambda: search_arxiv(q, sort, limit))
            resp = jsonify(papers=papers)
            resp.cache_control.public = True
            resp.cache_control.max_age = 600
            return resp
        except Exception as e:  # noqa: BLE001
            logger.warning("Discover failed: %s", e)
            return jsonify(error="Search provider unavailable"), 502

    @app.route("/arxiv")
    @optional_auth
    def arxiv():
        if (r := limited("discover", g.uid or request.remote_addr or "anon")):
            return r
        arxiv_id = parse_arxiv_id(sanitize(request.args.get("ref", ""), 300))
        if not arxiv_id:
            return jsonify(error="That doesn't look like an arXiv link or id."), 400
        try:
            paper = cached(("arxiv-id", arxiv_id), lambda: [p] if (p := arxiv_by_id(arxiv_id)) else [])
        except Exception as e:  # noqa: BLE001
            logger.warning("arXiv lookup failed: %s", e)
            return jsonify(error="arXiv is not responding. Try again shortly."), 502
        if not paper:
            return jsonify(error="No arXiv paper has that id."), 404
        return jsonify(paper=paper[0])

    @app.route("/related")
    @optional_auth
    def related():
        if (r := limited("discover", g.uid or request.remote_addr or "anon")):
            return r
        ref = s2_key_for(sanitize(request.args.get("source", ""), 40), sanitize(request.args.get("externalId", ""), 120))
        title = sanitize(request.args.get("title", ""), 300)
        if not ref and not title:
            return jsonify(error="Provide a paper id or title."), 400
        try:
            papers = cached(("related", ref, title), lambda: related_papers(ref, title))
        except Exception as e:  # noqa: BLE001
            logger.warning("Related failed: %s", e)
            return jsonify(error="Related papers are unavailable right now."), 502
        return jsonify(papers=papers)

    @app.route("/pdf/find")
    @optional_auth
    def pdf_find():
        """A free, legal PDF for a DOI (Unpaywall)."""
        if (r := limited("discover", g.uid or request.remote_addr or "anon")):
            return r
        doi = sanitize(request.args.get("doi", ""), 300)
        try:
            hit = cached(("unpaywall", doi), lambda: [x] if (x := sources.find_pdf(doi)) else [])
        except Exception as e:  # noqa: BLE001
            logger.info("Unpaywall failed: %s", e)
            return jsonify(error="Couldn't check for a free copy right now."), 502
        if not hit:
            return jsonify(error="No free copy of this paper was found."), 404
        return jsonify(hit[0])

    @app.route("/pdf/view")
    @require_auth
    def pdf_view():
        """Streams a public PDF to the in-app viewer. Browsers can't fetch most
        publishers' PDFs directly (no CORS), so the server fetches it, with the
        same private-network guard as imports."""
        if (r := limited("pdfview")):
            return r
        url = sanitize(request.args.get("url", ""), 2000)
        if not url.startswith(("https://", "http://")):
            return jsonify(error="Provide a PDF link."), 400
        try:
            data = fetch_pdf(url)
        except UnsafeUrl as e:
            return jsonify(error=str(e)), 400
        except Exception as e:  # noqa: BLE001
            logger.info("PDF view failed for %s: %s", url, e)
            return jsonify(error="Could not open that PDF. The publisher may not allow it."), 502
        resp = Response(data, mimetype="application/pdf")
        resp.headers["Cache-Control"] = "private, max-age=86400"
        resp.headers["Content-Disposition"] = "inline"
        return resp

    @app.route("/pdf/import", methods=["POST"])
    @require_auth
    def pdf_import():
        if (r := limited("import")):
            return r
        body = request.get_json(silent=True) or {}
        url = sanitize(body.get("url", ""), 2000)
        item_id = sanitize(body.get("itemId", ""), 64)
        if not url or not item_id.replace("-", "").isalnum():
            return jsonify(error="Provide a PDF link and item id."), 400
        try:
            data = fetch_pdf(url)
        except UnsafeUrl as e:
            return jsonify(error=str(e)), 400
        except Exception as e:  # noqa: BLE001
            logger.info("PDF import failed for %s: %s", url, e)
            return jsonify(error="Could not download that PDF."), 502
        from firebase_admin import storage

        path = f"users/{g.uid}/materials/{item_id}/{uuid.uuid4().hex[:8]}.pdf"
        token = uuid.uuid4().hex
        blob = storage.bucket().blob(path)
        blob.metadata = {"firebaseStorageDownloadTokens": token}
        blob.upload_from_string(data, content_type="application/pdf")
        bucket = storage.bucket().name
        download = (f"https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{quote(path, safe='')}"
                    f"?alt=media&token={token}")
        log_usage(g.uid, "import")
        return jsonify(storagePath=path, url=download, bytes=len(data))

    # ── AI ───────────────────────────────────────────────────────────

    def ai_guard(endpoint: str, max_body: int):
        if check_body_size(max_body):
            return jsonify(error="Request too large."), 413
        if (r := limited(endpoint)):
            return r
        if (err := orgs.check_allowance(g.uid)):
            return jsonify(err), 429
        return None

    @app.route("/pinda", methods=["POST"])
    @require_auth
    def pinda():
        if (r := ai_guard("pinda", 512 * 1024)):
            return r
        body = request.get_json(silent=True) or {}
        ctx = body.get("context") or {}
        scope = ctx.get("scope", "general")
        if scope not in SCOPES:
            return jsonify(error="Unknown context"), 400
        uid = g.uid
        try:
            context = ai.build_context(uid, scope, sanitize(ctx.get("id") or "", 64) or None, _ids(ctx.get("itemIds")))
        except Exception:  # noqa: BLE001
            logger.exception("pinda context failed")
            return jsonify(error="Could not load your library for Pinda."), 500
        messages = ai.build_messages(body.get("messages") or [], context)
        if not messages:
            return jsonify(error="Ask a question first."), 400
        style = "concise" if body.get("style") == "concise" else "detailed"
        voice = bool(body.get("voice"))
        name = (orgs.user_profile(uid).get("displayName") or "").strip().split(" ")[0][:40]
        system = ai.system_prompt(style, _edition(uid), voice=voice, profession=_profession(uid),
                                  user_name=name if name and name.lower() not in ("dscvr", "user") else None)
        max_tokens = 700 if voice else (1500 if style == "concise" else 4096)

        model = plans.model_for(plans.plan_of(orgs.user_profile(uid)), "chat")

        def run():
            usage: dict[str, int] = {}
            yield from ai.stream_text(system=system, messages=messages, max_tokens=max_tokens, usage=usage, model=model)
            orgs.record_usage(uid, "voice" if voice else "pinda", usage.get("input", 0), usage.get("output", 0), model)

        return _sse_response(run())

    @app.route("/reports/draft", methods=["POST"])
    @require_auth
    def report_draft():
        if (r := ai_guard("report", 64 * 1024)):
            return r
        body = request.get_json(silent=True) or {}
        item_ids = _ids(body.get("itemIds"))
        if not item_ids:
            return jsonify(error="Pick at least one source for the report."), 400
        uid = g.uid
        try:
            context = ai.build_context(uid, "selection", None, item_ids)
        except Exception:  # noqa: BLE001
            logger.exception("report context failed")
            return jsonify(error="Could not load your sources."), 500
        prompt = ai.report_prompt(sanitize(body.get("kind", ""), 40), sanitize(body.get("title", ""), 200),
                                  sanitize(body.get("instructions", ""), 2000))
        messages = [{"role": "user", "content": [*context, {"type": "text", "text": prompt}]}]
        system = "\n\n".join(x for x in (ai.REPORT_SYSTEM, ai.EDITION.get(_edition(uid), ""),
                                          ai.PROFESSION.get(_profession(uid) or "", "")) if x)

        model = plans.model_for(plans.plan_of(orgs.user_profile(uid)), "heavy")

        def run():
            usage: dict[str, int] = {}
            yield from ai.stream_text(system=system, messages=messages, max_tokens=6000, usage=usage, model=model)
            orgs.record_usage(uid, "report", usage.get("input", 0), usage.get("output", 0), model)

        return _sse_response(run())

    @app.route("/sessions/summary", methods=["POST"])
    @require_auth
    def session_summary():
        if (r := ai_guard("summary", 128 * 1024)):
            return r
        body = request.get_json(silent=True) or {}
        usage: dict[str, int] = {}
        model = plans.model_for(plans.plan_of(orgs.user_profile(g.uid)), "heavy")
        try:
            summary = ai.session_summary(
                model=model,
                title=sanitize(body.get("title", ""), 200) or "Research session",
                minutes=max(0, min(int(body.get("minutes") or 0), 24 * 60)),
                notes=sanitize(body.get("notes", ""), 8000),
                items=ai.load_items(g.uid, _ids(body.get("itemIds"))),
                transcript=sanitize(body.get("transcript", ""), 12000),
                usage=usage,
            )
        except ai.AIUnavailable as e:
            return jsonify(error=str(e)), 503
        except Exception as e:  # noqa: BLE001
            logger.exception("session summary failed")
            return jsonify(error=ai.failure_reason(e)), 502
        orgs.record_usage(g.uid, "summary", usage.get("input", 0), usage.get("output", 0), model)
        return jsonify(summary=summary)

    @app.route("/study", methods=["POST"])
    @require_auth
    def study():
        """Flashcards, exam questions, a case brief or an evidence summary
        for one library item. Body: {itemId, kind, count?}."""
        if (r := ai_guard("study", 16 * 1024)):
            return r
        body = request.get_json(silent=True) or {}
        kind = body.get("kind")
        if kind not in ai.STUDY_TOOLS:
            return jsonify(error="Pick flashcards, quiz, brief or evidence."), 400
        item_id = sanitize(body.get("itemId") or "", 64)
        if not item_id:
            return jsonify(error="Open an item first."), 400
        uid = g.uid
        try:
            context = ai.build_context(uid, "material", item_id)
        except Exception:  # noqa: BLE001
            logger.exception("study context failed")
            return jsonify(error="Could not load that item."), 500
        if not context:
            return jsonify(error="That item isn't in your library."), 404
        try:
            count = int(body.get("count") or 12)
        except (TypeError, ValueError):
            count = 12
        usage: dict[str, int] = {}
        model = plans.model_for(plans.plan_of(orgs.user_profile(uid)), "heavy")
        try:
            result = ai.study(kind, context, usage, count=count, edition=_edition(uid), profession=_profession(uid), model=model)
        except ai.AIUnavailable as e:
            return jsonify(error=str(e)), 503
        except Exception as e:  # noqa: BLE001
            logger.exception("study failed")
            return jsonify(error=ai.failure_reason(e)), 502
        orgs.record_usage(uid, "study", usage.get("input", 0), usage.get("output", 0), model)
        if kind == "quiz":
            good = []
            for q in result.get("questions") or []:
                opts = [str(o) for o in (q.get("options") or [])][:4]
                ans = q.get("answer")
                if len(opts) == 4 and isinstance(ans, int) and 0 <= ans < 4 and q.get("question"):
                    good.append({**q, "options": opts})
            result = {"questions": good}
        elif kind == "flashcards":
            result = {"cards": [c for c in (result.get("cards") or []) if c.get("front") and c.get("back")]}
        if not any(result.values()):
            return jsonify(error="Pinda couldn't make that from this item. Try another one."), 502
        return jsonify(kind=kind, **result)

    @app.route("/alerts/run", methods=["POST"])
    def alerts_run():
        """Called once a day by a scheduler with the CRON_SECRET header."""
        import hmac as _hmac
        secret = os.getenv("CRON_SECRET", "")
        given = request.headers.get("X-Cron-Secret", "")
        if not secret or not _hmac.compare_digest(secret, given):
            return jsonify(error="Not allowed."), 403
        import alerts
        return jsonify(alerts.run())

    @app.route("/alerts/check", methods=["POST"])
    @require_auth
    def alerts_check():
        """Lets a user fetch their alerts now (after turning them on)."""
        if (r := limited("alerts", g.uid)):
            return r
        import alerts
        try:
            new = alerts.run_for_user(g.uid, orgs.user_profile(g.uid, fresh=True))
        except Exception:  # noqa: BLE001
            logger.exception("alerts check failed")
            return jsonify(error="Couldn't check for new items right now."), 502
        return jsonify(new=len(new))

    @app.route("/parliament", methods=["POST"])
    @require_auth
    def parliament():
        if (r := ai_guard("parliament", 32 * 1024)):
            return r
        body = request.get_json(silent=True) or {}
        claim = sanitize(body.get("claim", ""), 2000)
        if len(claim) < 5:
            return jsonify(error="Provide a claim (5-2000 characters)."), 400
        usage: dict[str, int] = {}
        model = plans.model_for(plans.plan_of(orgs.user_profile(g.uid)), "heavy")
        try:
            result = ai.parliament(claim, sanitize(body.get("context", ""), 5000), usage, model)
        except ai.AIUnavailable as e:
            return jsonify(error=str(e)), 503
        except Exception as e:  # noqa: BLE001
            logger.exception("parliament failed")
            return jsonify(error=ai.failure_reason(e)), 502
        orgs.record_usage(g.uid, "parliament", usage.get("input", 0), usage.get("output", 0), model)
        return jsonify(result)

    # ── Plans and billing ────────────────────────────────────────────

    @app.errorhandler(billing.BillingError)
    def _billing_error(e: billing.BillingError):
        return jsonify(error=str(e)), e.status

    @app.route("/billing/me")
    @require_auth
    def billing_me():
        return jsonify({**orgs.usage_for(g.uid), "plans": plans.public_plans(), "paymentsEnabled": billing.enabled()})

    @app.route("/billing/checkout", methods=["POST"])
    @require_auth
    def billing_checkout():
        if (r := limited("orgs")):
            return r
        body = request.get_json(silent=True) or {}
        return jsonify(billing.checkout(g.uid, g.get("email"), sanitize(body.get("plan", ""), 40)))

    @app.route("/billing/verify", methods=["POST"])
    @require_auth
    def billing_verify():
        if (r := limited("orgs")):
            return r
        ref = sanitize((request.get_json(silent=True) or {}).get("reference", ""), 120)
        if not ref:
            return jsonify(error="Missing payment reference."), 400
        return jsonify(billing.verify(g.uid, ref))

    @app.route("/billing/cancel", methods=["POST"])
    @require_auth
    def billing_cancel():
        if (r := limited("orgs")):
            return r
        return jsonify(billing.cancel(g.uid))

    @app.route("/billing/paystack/webhook", methods=["POST"])
    def paystack_webhook():
        raw = request.get_data(cache=True)
        if len(raw) > 256 * 1024 or not billing.valid_signature(raw, request.headers.get("X-Paystack-Signature", "")):
            return jsonify(error="Bad signature."), 401
        try:
            result = billing.handle_event(request.get_json(silent=True) or {})
        except Exception:  # noqa: BLE001
            logger.exception("paystack webhook failed")
            return jsonify(error="Could not process event."), 500
        return jsonify(result=result)

    # ── Ratings ──────────────────────────────────────────────────────

    @app.route("/ratings")
    @optional_auth
    def ratings():
        keys = [k for k in sanitize(request.args.get("keys", ""), 4000).split(",") if k]
        return jsonify(ratings=orgs.ratings_for(g.uid, keys))

    @app.route("/ratings", methods=["POST"])
    @require_auth
    def rate():
        if (r := limited("rate")):
            return r
        body = request.get_json(silent=True) or {}
        try:
            stars = int(body.get("stars"))
        except (TypeError, ValueError):
            return jsonify(error="Rate from 1 to 5 stars."), 400
        return jsonify(orgs.rate_paper(g.uid, sanitize(body.get("key", ""), 200), stars, sanitize(body.get("title", ""), 300)))

    # ── Live rooms ───────────────────────────────────────────────────

    @app.route("/rooms/join", methods=["POST"])
    @require_auth
    def join_room():
        if (r := limited("rooms")):
            return r
        body = request.get_json(silent=True) or {}
        code = "".join(ch for ch in sanitize(body.get("code", ""), 12).upper() if ch.isalnum())
        if len(code) != 6:
            return jsonify(error="Room codes are 6 characters."), 400
        from firebase_admin import firestore as fs

        db = fs.client()
        rooms = db.collection("rooms").where("code", "==", code).where("endedAt", "==", None).limit(1).get()
        if not rooms:
            return jsonify(error="No live session uses that code."), 404
        room = rooms[0]
        if len((room.to_dict() or {}).get("memberUids", [])) >= 50:
            return jsonify(error="This session is full."), 403
        profile = orgs.user_profile(g.uid)
        room.reference.update({"memberUids": fs.ArrayUnion([g.uid])})
        room.reference.collection("members").document(g.uid).set(
            {"name": (profile.get("displayName") or "Member")[:80], "lastSeen": fs.SERVER_TIMESTAMP}, merge=True)
        return jsonify(roomId=room.id)

    # ── Account ──────────────────────────────────────────────────────

    @app.route("/account/delete", methods=["POST"])
    @require_auth
    def delete_account():
        """Deletes the caller's account and everything in it. Can't be undone."""
        if (r := limited("account")):
            return r
        body = request.get_json(silent=True) or {}
        if body.get("confirm") != "DELETE":
            return jsonify(error="Confirm deletion first."), 400
        import account
        from firebase_admin import auth as fb_auth, firestore as fs, storage
        try:
            done = account.delete_everything(
                g.uid, fs.client(), storage.bucket(), fb_auth,
                cancel_subscription=billing.cancel, detach_org=orgs._detach)
        except Exception:  # noqa: BLE001
            logger.exception("account deletion failed")
            return jsonify(error="Couldn't delete your account. Email mail@askpinda.com and we'll do it."), 500
        orgs._forget(g.uid)
        return jsonify(ok=True, deleted=done)

    # ── Blog (public; written from the admin console) ────────────────

    @app.route("/blog/posts")
    def blog_list():
        resp = jsonify(posts=blog.list_posts())
        resp.headers["Cache-Control"] = "public, max-age=60"
        return resp

    @app.route("/blog/posts/<slug>")
    def blog_get(slug: str):
        post = blog.get_post(sanitize(slug, 100))
        if not post:
            return jsonify(error="Not found."), 404
        resp = jsonify(post)
        resp.headers["Cache-Control"] = "public, max-age=60"
        return resp

    # ── Me: email status and preferences ─────────────────────────────

    @app.route("/me/sync", methods=["POST"])
    @require_auth
    def me_sync():
        """Records whether the user's email is verified (from their sign-in token)."""
        from firebase_admin import firestore as fs
        fs.client().document(f"users/{g.uid}").set(
            {"emailVerified": bool(g.get("email_verified")), **({"email": g.email} if g.get("email") else {})}, merge=True)
        orgs._forget(g.uid)
        return jsonify(ok=True, emailVerified=bool(g.get("email_verified")))

    @app.route("/me/email-updates", methods=["POST"])
    @require_auth
    def me_email_updates():
        body = request.get_json(silent=True) or {}
        on = bool(body.get("on"))
        from firebase_admin import firestore as fs
        fs.client().document(f"users/{g.uid}").set({"emailUpdates": on}, merge=True)
        orgs._forget(g.uid)
        return jsonify(ok=True, emailUpdates=on)

    @app.route("/email/unsubscribe", methods=["GET", "POST"])
    def email_unsubscribe():
        uid, token = sanitize(request.args.get("u", ""), 128), sanitize(request.args.get("t", ""), 64)
        ok = bool(uid) and mailer.unsubscribe(uid, token)
        msg = ("You're unsubscribed from DSCVR product updates. You can turn them back on in Settings."
               if ok else "That unsubscribe link isn't valid. Turn updates off in DSCVR, Settings.")
        return Response(f"<!doctype html><meta name=viewport content='width=device-width'><title>DSCVR</title>"
                        f"<div style='font-family:system-ui;max-width:460px;margin:80px auto;padding:0 20px;line-height:1.6'>"
                        f"<h2>DSCVR</h2><p>{msg}</p></div>", mimetype="text/html", status=200 if ok else 400)

    # ── Referrals ────────────────────────────────────────────────────

    @app.route("/referrals/me")
    @require_auth
    def referrals_me():
        return jsonify(referrals.status(g.uid))

    @app.route("/referrals/redeem", methods=["POST"])
    @require_auth
    def referrals_redeem():
        if (r := limited("referrals")):
            return r
        body = request.get_json(silent=True) or {}
        from firebase_admin import auth as fb_auth
        try:
            meta = fb_auth.get_user(g.uid).user_metadata
            created = datetime.fromtimestamp(meta.creation_timestamp / 1000, timezone.utc) if meta and meta.creation_timestamp else None
        except Exception:  # noqa: BLE001
            created = None
        try:
            out = referrals.redeem(g.uid, str(body.get("code", "")), bool(g.get("email_verified")), created)
        except referrals.ReferralError as e:
            return jsonify(error=str(e)), e.status
        orgs._forget(g.uid)
        return jsonify(out)

    # ── Rate DSCVR ───────────────────────────────────────────────────

    @app.route("/feedback/rating", methods=["GET", "POST"])
    @require_auth
    def app_rating():
        from firebase_admin import firestore as fs
        ref = fs.client().document(f"app_ratings/{g.uid}")
        if request.method == "GET":
            d = ref.get().to_dict() or {}
            return jsonify(stars=d.get("stars"), comment=d.get("comment", ""))
        if (r := limited("feedback")):
            return r
        body = request.get_json(silent=True) or {}
        try:
            stars = int(body.get("stars"))
        except (TypeError, ValueError):
            stars = 0
        if stars not in (1, 2, 3, 4, 5):
            return jsonify(error="Pick from 1 to 5 stars."), 400
        profile = orgs.user_profile(g.uid)
        import plans as _plans
        ref.set({"stars": stars, "comment": sanitize(str(body.get("comment", "")), 2000), "at": fs.SERVER_TIMESTAMP,
                 "email": g.get("email") or profile.get("email"), "name": profile.get("displayName"),
                 "edition": profile.get("edition"), "plan": _plans.plan_of(profile),
                 "platform": sanitize(str(body.get("platform", "")), 20)}, merge=True)
        return jsonify(ok=True, stars=stars)

    # ── Shared collections ───────────────────────────────────────────

    @app.route("/shares/<link_id>")
    @require_auth
    def open_share(link_id: str):
        """What a share link points to, as a read-only copy for the viewer."""
        if (r := limited("shares")):
            return r
        link_id = sanitize(link_id, 64)
        if not link_id.isalnum():
            return jsonify(error="This link is not valid."), 404
        from firebase_admin import firestore as fs
        try:
            return jsonify(shares.resolve(fs.client(), link_id, g.uid, g.get("email")))
        except shares.ShareError as e:
            return jsonify(error=str(e)), e.status

    # ── Enterprise ───────────────────────────────────────────────────

    def _identity():
        body = request.get_json(silent=True) or {}
        profile = orgs.user_profile(g.uid)
        return body, profile.get("email", ""), profile.get("displayName", "")

    @app.route("/activity", methods=["POST"])
    @require_auth
    def activity():
        orgs.mark_active(g.uid)
        return jsonify(ok=True)

    @app.route("/orgs", methods=["POST"])
    @require_auth
    def create_org():
        if (r := limited("orgs")):
            return r
        body, email, name = _identity()
        return jsonify(org=orgs.create_org(g.uid, sanitize(body.get("name", ""), 80), email, name))

    @app.route("/orgs/me")
    @require_auth
    def my_org():
        return jsonify(org=orgs.get_org(g.uid))

    @app.route("/orgs/join", methods=["POST"])
    @require_auth
    def join_org():
        if (r := limited("orgs")):
            return r
        body, email, name = _identity()
        return jsonify(org=orgs.join_org(g.uid, sanitize(body.get("code", ""), 20), email, name))

    @app.route("/orgs/leave", methods=["POST"])
    @require_auth
    def leave_org():
        orgs.leave_org(g.uid)
        return jsonify(ok=True)

    @app.route("/orgs/invite/rotate", methods=["POST"])
    @require_auth
    def rotate_invite():
        return jsonify(inviteCode=orgs.rotate_invite(g.uid))

    @app.route("/orgs/members/<member_uid>/remove", methods=["POST"])
    @require_auth
    def remove_member(member_uid: str):
        orgs.remove_member(g.uid, sanitize(member_uid, 128))
        return jsonify(ok=True)

    @app.route("/orgs/members/<member_uid>/role", methods=["POST"])
    @require_auth
    def member_role(member_uid: str):
        body = request.get_json(silent=True) or {}
        orgs.set_role(g.uid, sanitize(member_uid, 128), sanitize(body.get("role", ""), 10))
        return jsonify(ok=True)

    @app.route("/orgs/invoices")
    @require_auth
    def invoices():
        return jsonify(invoices=orgs.invoices(g.uid))

    @app.route("/orgs/invoices/<month>/pay", methods=["POST"])
    @require_auth
    def pay_invoice(month: str):
        if (r := limited("checkout")):
            return r
        body = request.get_json(silent=True) or {}
        token = body.get("paymentToken")
        if not isinstance(token, dict):
            return jsonify(error="Missing Google Pay payment token."), 400
        result = verify_google_pay_token(token)
        if not result.get("success"):
            return jsonify(error=result.get("error", "Payment failed.")), 402
        return jsonify(invoice=orgs.pay_invoice(g.uid, sanitize(month, 7), result))

    # ── Errors ───────────────────────────────────────────────────────

    @app.errorhandler(404)
    def not_found(_):
        return jsonify(error="Not found"), 404

    @app.errorhandler(500)
    def internal(_):
        return jsonify(error="Internal server error"), 500

    return app


if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    create_app().run(host="0.0.0.0", port=port, debug=Config.DEBUG, threaded=True)
