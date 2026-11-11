"""Product update emails, sent from the admin console.

Only people who switched on "Product updates" in Settings and verified their
email get them. Every email has a one-click unsubscribe link signed with
SESSION_SECRET. Sending uses Resend (RESEND_API_KEY and UPDATES_FROM_EMAIL,
falling back to ALERTS_FROM_EMAIL).
"""
from __future__ import annotations

import hashlib
import hmac
import html
import os
import re
from typing import Any

import requests

from security import get_firestore_client

BATCH = 100


class MailError(Exception):
    def __init__(self, message: str, status: int = 400):
        super().__init__(message)
        self.status = status


def configured() -> bool:
    return bool(os.getenv("RESEND_API_KEY") and (os.getenv("UPDATES_FROM_EMAIL") or os.getenv("ALERTS_FROM_EMAIL")))


def _sender() -> str:
    return os.getenv("UPDATES_FROM_EMAIL") or os.getenv("ALERTS_FROM_EMAIL", "")


def unsubscribe_token(uid: str) -> str:
    key = os.getenv("SESSION_SECRET", "").encode()
    return hmac.new(key, f"unsub:{uid}".encode(), hashlib.sha256).hexdigest()[:32]


def unsubscribe(uid: str, token: str) -> bool:
    if not os.getenv("SESSION_SECRET") or not hmac.compare_digest(unsubscribe_token(uid), token or ""):
        return False
    get_firestore_client().document(f"users/{uid}").set({"emailUpdates": False}, merge=True)
    return True


def _inline(s: str) -> str:
    s = html.escape(s)
    s = re.sub(r"\[([^\]]+)\]\((https?://[^)\s]+)\)", r'<a href="\2" style="color:#4F5BFF">\1</a>', s)
    return re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)


def render(subject: str, body: str, name: str, unsub_url: str) -> str:
    """Plain, readable HTML from simple Markdown: paragraphs, ## headings, - lists, links, bold."""
    blocks, out = re.split(r"\n\s*\n", body.strip()), []
    for b in blocks:
        lines = [l.rstrip() for l in b.splitlines() if l.strip()]
        if not lines:
            continue
        if lines[0].startswith("## "):
            out.append(f'<h2 style="font-size:18px;margin:24px 0 8px">{_inline(lines[0][3:])}</h2>')
            lines = lines[1:]
        if lines and all(l.lstrip().startswith(("- ", "* ")) for l in lines):
            out.append("<ul>" + "".join(f"<li style=\"margin:4px 0\">{_inline(l.lstrip()[2:])}</li>" for l in lines) + "</ul>")
        elif lines:
            out.append(f'<p style="margin:0 0 14px">{_inline(" ".join(lines))}</p>')
    first = html.escape((name or "there").split(" ")[0])
    return (f'<div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:560px;margin:auto;color:#111;line-height:1.6;font-size:15px">'
            f'<p style="margin:0 0 14px">Hi {first},</p>{"".join(out)}'
            f'<p style="margin:28px 0 0;color:#999;font-size:12px">You get this because product updates are on in DSCVR. '
            f'<a href="{html.escape(unsub_url)}" style="color:#999">Unsubscribe</a>.</p></div>')


def recipients(db=None) -> list[dict[str, Any]]:
    db = db or get_firestore_client()
    out = []
    for s in db.collection("users").where("emailUpdates", "==", True).limit(20000).get():
        d = s.to_dict() or {}
        if d.get("email") and d.get("emailVerified"):
            out.append({"uid": s.id, "email": d["email"], "name": d.get("displayName") or ""})
    return out


def _server_url() -> str:
    return os.getenv("SERVER_URL", "https://dscvr-server-production.up.railway.app").rstrip("/")


def send(subject: str, body: str, to: list[dict[str, Any]]) -> dict[str, int]:
    if not configured():
        raise MailError("Email isn't set up on the server. Add RESEND_API_KEY and UPDATES_FROM_EMAIL in Railway.", 503)
    subject, body = (subject or "").strip()[:150], (body or "").strip()
    if len(subject) < 3 or len(body) < 10:
        raise MailError("Write a subject and a message first.")
    sent = failed = 0
    for i in range(0, len(to), BATCH):
        chunk = []
        for r in to[i:i + BATCH]:
            unsub = f"{_server_url()}/email/unsubscribe?u={r['uid']}&t={unsubscribe_token(r['uid'])}"
            chunk.append({"from": _sender(), "to": [r["email"]], "subject": subject,
                          "html": render(subject, body, r.get("name", ""), unsub),
                          "headers": {"List-Unsubscribe": f"<{unsub}>", "List-Unsubscribe-Post": "List-Unsubscribe=One-Click"}})
        try:
            res = requests.post("https://api.resend.com/emails/batch", json=chunk, timeout=30,
                                headers={"Authorization": f"Bearer {os.getenv('RESEND_API_KEY')}"})
            if res.ok:
                sent += len(chunk)
            else:
                failed += len(chunk)
        except requests.RequestException:
            failed += len(chunk)
    return {"sent": sent, "failed": failed}
