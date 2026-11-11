"""Shared collections: what someone sees when they open a share link.

Links live in /shares/{id} (written by the owner from the app). A viewer can't
read the owner's library directly, so this module resolves the link and
returns a read-only copy of the category or topic it points to.

What is shared: titles, authors, summaries, public links, and the text of
notes the owner wrote as library items. What is never shared: PDFs the owner
uploaded to their own storage, margin notes, ratings, reading progress and
Pinda conversations.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

MAX_ITEMS = 300
MAX_CONTENT = 20_000


class ShareError(Exception):
    def __init__(self, message: str, status: int = 404):
        super().__init__(message)
        self.status = status


def _expired(value: Any) -> bool:
    if not value:
        return False
    try:
        when = value if isinstance(value, datetime) else datetime.fromisoformat(str(value))
    except ValueError:
        return False
    if when.tzinfo is None:
        when = when.replace(tzinfo=timezone.utc)
    return when < datetime.now(timezone.utc)


def _text(value: Any, limit: int) -> str:
    return value[:limit] if isinstance(value, str) else ""


def public_item(item_id: str, m: dict[str, Any]) -> dict[str, Any]:
    """The fields of a library item that are safe to show a viewer."""
    kind = m.get("kind") if m.get("kind") in ("paper", "pdf", "link", "note", "youtube") else "link"
    private_file = bool(m.get("storagePath"))
    out: dict[str, Any] = {
        "id": item_id,
        "kind": kind,
        "title": _text(m.get("title"), 300) or "Untitled",
        "authors": [a[:120] for a in (m.get("authors") or []) if isinstance(a, str)][:30],
        "year": m.get("year") if isinstance(m.get("year"), int) else None,
        "summary": _text(m.get("summary"), 4000),
        "siteName": _text(m.get("siteName"), 120) or None,
        "source": _text(m.get("source"), 40) or None,
        "externalId": _text(m.get("externalId"), 200) or None,
        "thumbnailUrl": _text(m.get("thumbnailUrl"), 600) or None,
        "topicId": m.get("topicId") if isinstance(m.get("topicId"), str) else None,
        "privateFile": private_file,
    }
    # An uploaded PDF's links point into the owner's storage: never pass them on.
    if not private_file:
        out["url"] = _text(m.get("url"), 1000) or None
        out["pdfUrl"] = _text(m.get("pdfUrl"), 1000) or None
    if kind in ("note", "link", "youtube"):
        out["content"] = _text(m.get("content"), MAX_CONTENT)
    return out


def resolve(db, link_id: str, viewer_uid: str, viewer_email: str | None = None) -> dict[str, Any]:
    """Returns the shared collection for a link, or raises ShareError."""
    snap = db.document(f"shares/{link_id}").get()
    link = snap.to_dict() if snap.exists else None
    if not link or link.get("active") is False or _expired(link.get("expiresAt")):
        raise ShareError("This link has expired or was turned off.")
    if link.get("password"):
        raise ShareError("This link is protected and can't be opened here.", 403)
    allowed = [e.lower() for e in (link.get("allowedEmails") or []) if isinstance(e, str)]
    owner = link.get("ownerId") or ""
    if allowed and viewer_uid != owner and (viewer_email or "").lower() not in allowed:
        raise ShareError("This link was shared with someone else.", 403)

    target_type = link.get("targetType")
    target_id = link.get("targetId") or ""
    if target_type not in ("category", "topic") or not owner or not target_id:
        raise ShareError("This link is not valid.")
    base = f"users/{owner}"
    target = db.document(f"{base}/{'categories' if target_type == 'category' else 'topics'}/{target_id}").get()
    if not target.exists:
        raise ShareError("The owner removed what this link pointed to.")
    t = target.to_dict() or {}

    field = "categoryId" if target_type == "category" else "topicId"
    docs = db.collection(f"{base}/materials").where(field, "==", target_id).limit(MAX_ITEMS).get()
    items = [public_item(d.id, d.to_dict() or {}) for d in docs]
    items.sort(key=lambda i: i["title"].lower())

    topics: list[dict[str, Any]] = []
    if target_type == "category":
        for d in db.collection(f"{base}/topics").where("categoryId", "==", target_id).limit(100).get():
            td = d.to_dict() or {}
            topics.append({"id": d.id, "name": _text(td.get("name"), 120) or "Untitled",
                           "description": _text(td.get("description"), 600)})
        topics.sort(key=lambda x: x["name"].lower())

    owner_profile = db.document(base).get().to_dict() or {}
    permission = link.get("permission") if link.get("permission") in ("view", "comment", "fork") else "view"
    return {
        "id": link_id,
        "type": target_type,
        "permission": permission,
        "canFork": permission == "fork",
        "mine": viewer_uid == owner,
        "name": _text(t.get("name"), 120) or "Untitled",
        "description": _text(t.get("description"), 1000),
        "ownerName": (_text(owner_profile.get("displayName"), 80) or "A DSCVR user").split(" ")[0],
        "topics": topics,
        "items": items,
    }
