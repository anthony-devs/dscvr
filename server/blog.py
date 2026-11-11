"""Blog posts you write from the admin console.

Posts live in Firestore at blog_posts/{slug}. The website (landing/) reads the
published ones from GET /blog/posts and /blog/posts/<slug>, merges them with
the posts kept as Markdown files in the repo, and refreshes within minutes.
A post saved here with the same slug as a file post replaces it on the site.
"""
from __future__ import annotations

import os
import re
from datetime import datetime, timezone
from typing import Any

import requests

from security import get_firestore_client

SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+){0,15}$")
MAX_BODY = 60_000


class BlogError(Exception):
    def __init__(self, message: str, status: int = 400):
        super().__init__(message)
        self.status = status


def _db():
    return get_firestore_client()


def slugify(s: str) -> str:
    return re.sub(r"-{2,}", "-", re.sub(r"[^a-z0-9]+", "-", (s or "").lower())).strip("-")[:90]


def _iso(v: Any) -> str | None:
    if v is None:
        return None
    return v.isoformat() if hasattr(v, "isoformat") else str(v)


def _out(slug: str, d: dict[str, Any], body: bool) -> dict[str, Any]:
    post = {
        "slug": slug,
        "title": d.get("title") or slug,
        "description": d.get("description") or "",
        "date": d.get("date") or (_iso(d.get("createdAt")) or "")[:10],
        "updated": (_iso(d.get("updatedAt")) or "")[:10] or None,
        "author": d.get("author") or "The DSCVR team",
        "tags": [t for t in (d.get("tags") or []) if isinstance(t, str)],
        "published": bool(d.get("published")),
    }
    if body:
        post["body"] = d.get("body") or ""
    return post


def list_posts(include_drafts: bool = False) -> list[dict[str, Any]]:
    out = []
    for s in _db().collection("blog_posts").limit(500).get():
        d = s.to_dict() or {}
        if include_drafts or d.get("published"):
            out.append(_out(s.id, d, body=False))
    return sorted(out, key=lambda p: p["date"] or "", reverse=True)


def get_post(slug: str, include_drafts: bool = False) -> dict[str, Any] | None:
    if not SLUG.match(slug or ""):
        return None
    snap = _db().document(f"blog_posts/{slug}").get()
    d = snap.to_dict() if snap.exists else None
    if not d or (not d.get("published") and not include_drafts):
        return None
    return _out(slug, d, body=True)


def save_post(data: dict[str, Any], actor: str) -> dict[str, Any]:
    title = str(data.get("title") or "").strip()[:160]
    if len(title) < 4:
        raise BlogError("Give the post a title.")
    slug = slugify(str(data.get("slug") or "") or title)
    if not SLUG.match(slug):
        raise BlogError("The address (slug) can only use lowercase letters, numbers and dashes.")
    body = str(data.get("body") or "").strip()
    if len(body) > MAX_BODY:
        raise BlogError("That post is too long. Keep it under 60,000 characters.")
    date = str(data.get("date") or "").strip()[:10] or datetime.now(timezone.utc).date().isoformat()
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
        raise BlogError("The date must look like 2026-11-11.")
    tags = data.get("tags") or []
    if isinstance(tags, str):
        tags = tags.split(",")
    doc = {
        "title": title,
        "description": str(data.get("description") or "").strip()[:300],
        "body": body,
        "date": date,
        "author": str(data.get("author") or "").strip()[:80] or "The DSCVR team",
        "tags": [t.strip()[:40] for t in tags if isinstance(t, str) and t.strip()][:12],
        "published": bool(data.get("published")),
        "updatedAt": datetime.now(timezone.utc),
        "updatedBy": actor,
    }
    previous = str(data.get("previousSlug") or "").strip()
    db = _db()
    ref = db.document(f"blog_posts/{slug}")
    if not ref.get().exists:
        doc["createdAt"] = datetime.now(timezone.utc)
    ref.set(doc, merge=True)
    if previous and previous != slug and SLUG.match(previous):
        db.document(f"blog_posts/{previous}").delete()
    revalidate()
    return _out(slug, doc, body=True)


def delete_post(slug: str) -> None:
    if not SLUG.match(slug or ""):
        raise BlogError("Unknown post.", 404)
    _db().document(f"blog_posts/{slug}").delete()
    revalidate()


def revalidate() -> None:
    """Asks the website to refresh its blog pages now instead of within minutes."""
    site, secret = os.getenv("LANDING_URL", "https://www.askpinda.com"), os.getenv("REVALIDATE_SECRET", "")
    if not secret:
        return
    try:
        requests.post(f"{site.rstrip('/')}/api/revalidate", json={"secret": secret}, timeout=8)
    except requests.RequestException:
        pass
