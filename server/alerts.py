"""Subject alerts: new papers and judgments in the subjects each user follows.

Users switch alerts on in Settings. The app stores what to watch on the
profile:

    users/{uid}.alerts = {enabled: true, email: false,
                          subjects: [{label, source, query}, ...]}

A scheduled job calls run() (POST /alerts/run with the CRON_SECRET header, or
`python manage.py alerts`). For each subject it searches the matching source
for the newest items, skips anything already sent, and writes the rest to
users/{uid}/alerts/{key} for the in-app inbox. If RESEND_API_KEY and
ALERTS_FROM_EMAIL are set and the user opted in, it also emails a digest.

Run it once a day. Each run makes at most MAX_SUBJECTS searches per user and
results are cached, so users who follow the same subject share one search.
"""
from __future__ import annotations

import hashlib
import html
import logging
import os
import time
from datetime import datetime, timezone
from typing import Any, Callable

import requests

import discover
from security import get_firestore_client

log = logging.getLogger("alerts")

MAX_SUBJECTS = 8
PER_SUBJECT = 5
KEEP_SEEN = 400  # remembered item keys per user, newest first

SOURCES: dict[str, Callable[[str, int], list[dict[str, Any]]]] = {
    "arxiv": lambda q, n: discover.search_arxiv(q, "date", n),
    "openalex": lambda q, n: discover.search_openalex(q, n, "date"),
    "europepmc": lambda q, n: discover.search_europepmc(q, n, "date"),
    "uk_caselaw": lambda q, n: discover.search_uk_caselaw(q, n),
}


def item_key(paper: dict[str, Any]) -> str:
    raw = f"{paper.get('source')}|{paper.get('id') or paper.get('url') or paper.get('title')}"
    return hashlib.sha1(raw.encode()).hexdigest()[:20]


def _search(source: str, query: str) -> list[dict[str, Any]]:
    fn = SOURCES.get(source) or SOURCES["openalex"]
    try:
        return discover.cached(("alert", source, query), lambda: fn(query, PER_SUBJECT))
    except Exception as e:  # noqa: BLE001
        log.warning("alert search %s %r failed: %s", source, query, e)
        return []


def run_for_user(uid: str, profile: dict[str, Any], db=None) -> list[dict[str, Any]]:
    """Finds and stores new items for one user. Returns the new items."""
    db = db or get_firestore_client()
    cfg = profile.get("alerts") or {}
    subjects = [s for s in (cfg.get("subjects") or []) if isinstance(s, dict) and s.get("label")][:MAX_SUBJECTS]
    if not cfg.get("enabled") or not subjects:
        return []
    state_ref = db.document(f"users/{uid}/private/alertState")
    state = state_ref.get().to_dict() or {}
    seen: list[str] = list(state.get("seen") or [])
    first_run = not state.get("lastRun")
    seen_set = set(seen)
    fresh: list[dict[str, Any]] = []
    for s in subjects:
        query = (s.get("query") or s["label"]).strip()
        for p in _search(s.get("source") or "openalex", query):
            k = item_key(p)
            if k in seen_set:
                continue
            seen_set.add(k)
            seen.insert(0, k)
            fresh.append({**p, "_key": k, "_subject": s["label"]})
    now = datetime.now(timezone.utc)
    # On the very first run, just remember what exists so the inbox doesn't
    # fill with dozens of old items at once; show only the top one per subject.
    if first_run:
        by_subject: dict[str, dict[str, Any]] = {}
        for p in fresh:
            by_subject.setdefault(p["_subject"], p)
        fresh = list(by_subject.values())
    batch = db.batch()
    for p in fresh:
        batch.set(db.document(f"users/{uid}/alerts/{p['_key']}"), {
            "subject": p["_subject"], "title": p.get("title") or "Untitled", "source": p.get("source"),
            "authors": (p.get("authors") or [])[:6], "year": p.get("year"), "venue": p.get("venue"),
            "summary": (p.get("summary") or "")[:600], "url": p.get("url"), "pdfUrl": p.get("pdfUrl"),
            "paperId": p.get("id"), "kind": p.get("kind"), "createdAt": now, "read": False,
        })
    batch.set(state_ref, {"seen": seen[:KEEP_SEEN], "lastRun": now, "lastCount": len(fresh)}, merge=True)
    batch.commit()
    if fresh and cfg.get("email"):
        _email(profile.get("email"), profile.get("name") or profile.get("displayName"), fresh)
    return fresh


def run(limit_users: int = 5000) -> dict[str, int]:
    db = get_firestore_client()
    users = db.collection("users").where("alerts.enabled", "==", True).limit(limit_users).get()
    sent = items = failed = 0
    started = time.monotonic()
    for snap in users:
        try:
            new = run_for_user(snap.id, snap.to_dict() or {}, db)
            items += len(new)
            sent += 1 if new else 0
        except Exception:  # noqa: BLE001
            failed += 1
            log.exception("alerts failed for a user")
    out = {"users": len(users), "withNew": sent, "items": items, "failed": failed, "seconds": int(time.monotonic() - started)}
    log.info("alerts run: %s", out)
    return out


# ── Email digest (optional) ──────────────────────────────────────────

SOURCE_NAMES = {"arxiv": "arXiv", "openalex": "OpenAlex", "europepmc": "Europe PMC", "uk_caselaw": "Find Case Law (UK)",
                "semantic_scholar": "Semantic Scholar"}


def _email(to: str | None, name: str | None, items: list[dict[str, Any]]) -> None:
    key, sender = os.getenv("RESEND_API_KEY", ""), os.getenv("ALERTS_FROM_EMAIL", "")
    if not (key and sender and to):
        return
    app_url = os.getenv("APP_URL", "https://app.askpinda.com")
    rows = []
    for p in items[:25]:
        meta = " · ".join(str(x) for x in (p.get("_subject"), SOURCE_NAMES.get(p.get("source"), ""), p.get("venue") or p.get("year")) if x)
        rows.append(f'<tr><td style="padding:12px 0;border-bottom:1px solid #eee">'
                    f'<a href="{html.escape(p.get("url") or app_url)}" style="color:#111;font-weight:600;text-decoration:none">'
                    f'{html.escape(p.get("title") or "Untitled")}</a>'
                    f'<div style="color:#666;font-size:13px;margin-top:4px">{html.escape(meta)}</div></td></tr>')
    body = (f'<div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:560px;margin:auto">'
            f'<p>Hi {html.escape((name or "there").split(" ")[0])},</p>'
            f'<p>{len(items)} new item{"s" if len(items) != 1 else ""} in the subjects you follow on DSCVR.</p>'
            f'<table style="width:100%;border-collapse:collapse">{"".join(rows)}</table>'
            f'<p><a href="{app_url}/alerts">Open in DSCVR</a></p>'
            f'<p style="color:#999;font-size:12px">You get this because alerts by email are on. '
            f'Turn them off in DSCVR, Settings, Alerts.</p></div>')
    try:
        r = requests.post("https://api.resend.com/emails", timeout=15, headers={"Authorization": f"Bearer {key}"},
                          json={"from": sender, "to": [to], "subject": f"New in your subjects ({len(items)})", "html": body})
        if r.status_code >= 400:
            log.warning("alert email failed: %s %s", r.status_code, r.text[:200])
    except requests.RequestException as e:
        log.warning("alert email failed: %s", e)
