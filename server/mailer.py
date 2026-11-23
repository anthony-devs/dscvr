"""Email for DSCVR: one sender, one look, and consent the user can see.

Transport: Zoho Mail SMTP (SMTP_USER + SMTP_PASSWORD, an app-specific password) or,
if that isn't set, Resend (RESEND_API_KEY). The same branded layout is used for:

    verification   confirm your email (link made with Firebase, sent by us)
    welcome        sent once, when the email is confirmed (or at once for Google sign-in)
    password reset
    updates        product news, sent from the admin console, only to people who opted in
    digest         the alerts email

Service emails (verification, welcome, reset) always go out. Everything else needs the
person's opt-in, carries a one-click unsubscribe link (also as List-Unsubscribe headers
for mail apps) and is never sent to unverified addresses.
"""
from __future__ import annotations

import hashlib
import hmac
import html
import logging
import os
import re
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import formataddr, parseaddr
from typing import Any

import requests

from security import get_firestore_client

log = logging.getLogger("mailer")

BATCH = 100
# Bump when the terms change materially: people are asked to accept again.
TERMS_VERSION = os.getenv("TERMS_VERSION", "2026-11")
BRAND = "#4F5BFF"


class MailError(Exception):
    def __init__(self, message: str, status: int = 400):
        super().__init__(message)
        self.status = status


# ── Settings ─────────────────────────────────────────────────────────

def _smtp_ready() -> bool:
    return bool(os.getenv("SMTP_USER") and os.getenv("SMTP_PASSWORD"))


def _resend_ready() -> bool:
    return bool(os.getenv("RESEND_API_KEY") and (os.getenv("MAIL_FROM") or os.getenv("UPDATES_FROM_EMAIL") or os.getenv("ALERTS_FROM_EMAIL")))


def configured() -> bool:
    return _smtp_ready() or _resend_ready()


def _sender() -> str:
    from_ = os.getenv("MAIL_FROM") or os.getenv("UPDATES_FROM_EMAIL") or os.getenv("ALERTS_FROM_EMAIL")
    if from_:
        return from_
    return formataddr(("AskPinda", os.getenv("SMTP_USER", "mail@askpinda.com")))


def _app_url() -> str:
    return os.getenv("APP_URL", "https://app.askpinda.com").rstrip("/")


def _server_url() -> str:
    return os.getenv("SERVER_URL", "https://api.askpinda.com").rstrip("/")


def _site_url() -> str:
    return os.getenv("SITE_URL", "https://www.askpinda.com").rstrip("/")


# ── Unsubscribe ──────────────────────────────────────────────────────

CATEGORIES = {"updates": "product updates", "alerts": "subject alert emails"}


def unsubscribe_token(uid: str, cat: str = "updates") -> str:
    key = os.getenv("SESSION_SECRET", "").encode()
    msg = f"unsub:{uid}" if cat == "updates" else f"unsub:{cat}:{uid}"  # "updates" keeps the links already sent valid
    return hmac.new(key, msg.encode(), hashlib.sha256).hexdigest()[:32]


def unsubscribe_url(uid: str, cat: str = "updates") -> str:
    return f"{_server_url()}/email/unsubscribe?u={uid}&t={unsubscribe_token(uid, cat)}&c={cat}"


def _valid(uid: str, token: str, cat: str) -> bool:
    return bool(uid and os.getenv("SESSION_SECRET") and cat in CATEGORIES
                and hmac.compare_digest(unsubscribe_token(uid, cat), token or ""))


def _set_pref(uid: str, cat: str, on: bool) -> None:
    ref = get_firestore_client().document(f"users/{uid}")
    if cat == "alerts":
        ref.set({"alerts": {"email": on}}, merge=True)
    else:
        ref.set({"emailUpdates": on}, merge=True)


def unsubscribe(uid: str, token: str, cat: str = "updates") -> bool:
    if not _valid(uid, token, cat):
        return False
    _set_pref(uid, cat, False)
    return True


def resubscribe(uid: str, token: str, cat: str = "updates") -> bool:
    if not _valid(uid, token, cat):
        return False
    _set_pref(uid, cat, True)
    return True


def record_consent(uid: str, terms: bool, updates: bool | None = None) -> dict[str, Any]:
    """Stores that the person accepted the terms (and the version) and, if asked, their choice on updates."""
    from firebase_admin import firestore as fs
    if not terms:
        raise MailError("Accept the Terms and Privacy Policy to continue.")
    data: dict[str, Any] = {"termsAcceptedAt": fs.SERVER_TIMESTAMP, "termsVersion": TERMS_VERSION}
    if updates is not None:
        data["emailUpdates"] = bool(updates)
        data["updatesConsentAt"] = fs.SERVER_TIMESTAMP
    get_firestore_client().document(f"users/{uid}").set(data, merge=True)
    return {"terms": True, "version": TERMS_VERSION, **({"emailUpdates": bool(updates)} if updates is not None else {})}


def consent_status(uid: str) -> dict[str, Any]:
    d = get_firestore_client().document(f"users/{uid}").get().to_dict() or {}
    return {"terms": d.get("termsVersion") == TERMS_VERSION, "version": TERMS_VERSION,
            "emailUpdates": d.get("emailUpdates") is True}


# ── Layout ───────────────────────────────────────────────────────────

def _inline(s: str) -> str:
    s = html.escape(s)
    s = re.sub(r"\[([^\]]+)\]\((https?://[^)\s]+)\)", rf'<a href="\2" style="color:{BRAND}">\1</a>', s)
    return re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)


def button(label: str, url: str) -> str:
    return (f'<table role="presentation" cellspacing="0" cellpadding="0" style="margin:22px 0"><tr><td style="background:{BRAND};border-radius:10px">'
            f'<a href="{html.escape(url)}" style="display:inline-block;padding:13px 24px;color:#fff;font-weight:600;font-size:15px;text-decoration:none">'
            f'{html.escape(label)}</a></td></tr></table>')


def layout(inner: str, *, preheader: str = "", footer: str = "") -> str:
    """The one look every email shares: wordmark, a white card, a quiet footer."""
    return (
        '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>'
        '<body style="margin:0;padding:0;background:#F4F4F6">'
        f'<div style="display:none;max-height:0;overflow:hidden;color:#F4F4F6">{html.escape(preheader)}</div>'
        '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#F4F4F6"><tr><td align="center" style="padding:28px 14px">'
        '<table role="presentation" width="560" cellspacing="0" cellpadding="0" style="max-width:560px;width:100%">'
        f'<tr><td style="padding:0 6px 14px;font-family:-apple-system,Segoe UI,Roboto,sans-serif;font-size:15px;letter-spacing:.18em;font-weight:700;color:#111">'
        f'DSCVR <span style="letter-spacing:0;font-weight:400;color:#888;font-size:12px">by AskPinda</span></td></tr>'
        '<tr><td style="background:#fff;border-radius:14px;padding:30px 30px 26px;font-family:-apple-system,Segoe UI,Roboto,sans-serif;'
        f'color:#111;line-height:1.6;font-size:15px">{inner}</td></tr>'
        '<tr><td style="padding:16px 8px 0;font-family:-apple-system,Segoe UI,Roboto,sans-serif;color:#8a8a93;font-size:12px;line-height:1.6">'
        f'{footer}<br>AskPinda · Enugu, Nigeria · <a href="{_site_url()}/privacy" style="color:#8a8a93">Privacy</a> · '
        f'<a href="{_site_url()}/terms" style="color:#8a8a93">Terms</a> · <a href="{_site_url()}/support" style="color:#8a8a93">Help</a>'
        '</td></tr></table></td></tr></table></body></html>')


def _service_footer(email: str) -> str:
    return (f"You're getting this because {html.escape(email)} has a DSCVR account. It's a service email, so it arrives even if "
            f'you\'ve turned updates off. <a href="{_app_url()}/settings" style="color:#8a8a93">Email preferences</a>.')


def _marketing_footer(uid: str, cat: str) -> str:
    return (f"You're getting this because you chose to receive {CATEGORIES[cat]} from DSCVR. "
            f'<a href="{html.escape(unsubscribe_url(uid, cat))}" style="color:#8a8a93">Unsubscribe</a> in one click · '
            f'<a href="{_app_url()}/settings" style="color:#8a8a93">Email preferences</a>.')


def _first(name: str | None) -> str:
    return html.escape((name or "there").strip().split(" ")[0] or "there")


def _text(h: str) -> str:
    h = re.sub(r'<a [^>]*href="([^"]+)"[^>]*>(.*?)</a>', r"\2 (\1)", h, flags=re.S)
    h = re.sub(r"</(p|h\d|li|tr|div)>|<br\s*/?>", "\n", h)
    h = re.sub(r"<style.*?</style>|<[^>]+>", "", h, flags=re.S)
    return re.sub(r"\n{3,}", "\n\n", html.unescape(h)).strip()


def render(subject: str, body: str, name: str, unsub_url: str) -> str:
    """Simple Markdown (paragraphs, ## headings, - lists, links, bold) in the shared layout."""
    blocks, out = re.split(r"\n\s*\n", body.strip()), []
    for b in blocks:
        lines = [l.rstrip() for l in b.splitlines() if l.strip()]
        if not lines:
            continue
        if lines[0].startswith("## "):
            out.append(f'<h2 style="font-size:19px;margin:24px 0 8px">{_inline(lines[0][3:])}</h2>')
            lines = lines[1:]
        if lines and all(l.lstrip().startswith(("- ", "* ")) for l in lines):
            out.append("<ul style=\"padding-left:20px\">" + "".join(f'<li style="margin:4px 0">{_inline(l.lstrip()[2:])}</li>' for l in lines) + "</ul>")
        elif lines:
            out.append(f'<p style="margin:0 0 14px">{_inline(" ".join(lines))}</p>')
    inner = f'<p style="margin:0 0 14px">Hi {_first(name)},</p>{"".join(out)}'
    foot = (f"You're getting this because you chose to receive product updates from DSCVR. "
            f'<a href="{html.escape(unsub_url)}" style="color:#8a8a93">Unsubscribe</a> in one click · '
            f'<a href="{_app_url()}/settings" style="color:#8a8a93">Email preferences</a>.')
    return layout(inner, preheader=subject, footer=foot)


# ── Delivery ─────────────────────────────────────────────────────────

def _build(m: dict[str, Any]) -> EmailMessage:
    msg = EmailMessage()
    name, addr = parseaddr(_sender())
    msg["From"] = formataddr((name or "AskPinda", addr))
    msg["To"] = m["to"]
    msg["Subject"] = m["subject"]
    msg["Reply-To"] = os.getenv("MAIL_REPLY_TO") or addr
    for k, v in (m.get("headers") or {}).items():
        msg[k] = v
    msg.set_content(m.get("text") or _text(m["html"]))
    msg.add_alternative(m["html"], subtype="html")
    return msg


def deliver(messages: list[dict[str, Any]]) -> dict[str, int]:
    """Sends messages [{to, subject, html, text?, headers?}] and counts what went."""
    if not configured():
        raise MailError("Email isn't set up on the server. Add SMTP_USER and SMTP_PASSWORD (a Zoho app password).", 503)
    if _smtp_ready():
        return _deliver_smtp(messages)
    return _deliver_resend(messages)


def _deliver_smtp(messages: list[dict[str, Any]]) -> dict[str, int]:
    host, port = os.getenv("SMTP_HOST", "smtp.zoho.com"), int(os.getenv("SMTP_PORT", "465"))
    sent = failed = 0
    conn: smtplib.SMTP | None = None

    def connect() -> smtplib.SMTP:
        c = smtplib.SMTP_SSL(host, port, timeout=20, context=ssl.create_default_context())
        c.login(os.environ["SMTP_USER"], os.environ["SMTP_PASSWORD"])
        return c
    try:
        for m in messages:
            try:
                conn = conn or connect()
                conn.send_message(_build(m))
                sent += 1
            except smtplib.SMTPAuthenticationError as e:
                log.error("SMTP login refused: %s", e)
                raise MailError("The mail server refused the login. Check SMTP_USER and the app password.", 502) from None
            except (smtplib.SMTPException, OSError) as e:
                log.warning("email to %s failed: %s", m.get("to"), e)
                failed += 1
                try:
                    conn and conn.close()
                except Exception:  # noqa: BLE001
                    pass
                conn = None
    finally:
        try:
            conn and conn.quit()
        except Exception:  # noqa: BLE001
            pass
    return {"sent": sent, "failed": failed}


def _deliver_resend(messages: list[dict[str, Any]]) -> dict[str, int]:
    sent = failed = 0
    for i in range(0, len(messages), BATCH):
        chunk = [{"from": _sender(), "to": [m["to"]], "subject": m["subject"], "html": m["html"], "text": m.get("text") or _text(m["html"]),
                  **({"headers": m["headers"]} if m.get("headers") else {})} for m in messages[i:i + BATCH]]
        try:
            res = requests.post("https://api.resend.com/emails/batch", json=chunk, timeout=30,
                                headers={"Authorization": f"Bearer {os.getenv('RESEND_API_KEY')}"})
            if res.ok:
                sent += len(chunk)
            else:
                log.warning("resend failed: %s %s", res.status_code, res.text[:200])
                failed += len(chunk)
        except requests.RequestException as e:
            log.warning("resend failed: %s", e)
            failed += len(chunk)
    return {"sent": sent, "failed": failed}


def _one_click(uid: str, cat: str) -> dict[str, str]:
    u = unsubscribe_url(uid, cat)
    return {"List-Unsubscribe": f"<{u}>", "List-Unsubscribe-Post": "List-Unsubscribe=One-Click"}


# ── Service emails ───────────────────────────────────────────────────

def _action_settings(path: str):
    from firebase_admin import auth as fb_auth
    return fb_auth.ActionCodeSettings(url=f"{_app_url()}{path}", handle_code_in_app=False)


def send_verification(uid: str, email: str, name: str | None) -> None:
    from firebase_admin import auth as fb_auth
    link = fb_auth.generate_email_verification_link(email, _action_settings("/?verified=1"))
    inner = (f'<p style="margin:0 0 14px">Hi {_first(name)},</p>'
             '<p style="margin:0 0 6px">Welcome to DSCVR. Confirm this is your email so we can keep your library safe, '
             'recover your account if you get locked out, and send you what you ask for.</p>'
             f'{button("Confirm my email", link)}'
             '<p style="margin:0 0 10px;color:#555;font-size:13px">If the button doesn\'t work, paste this link into your browser:<br>'
             f'<span style="word-break:break-all">{html.escape(link)}</span></p>'
             '<p style="margin:0;color:#555;font-size:13px">Didn\'t create a DSCVR account? You can ignore this email.</p>')
    deliver([{"to": email, "subject": "Confirm your email for DSCVR",
              "html": layout(inner, preheader="One tap to confirm your email.", footer=_service_footer(email))}])


def send_password_reset(email: str) -> None:
    from firebase_admin import auth as fb_auth
    link = fb_auth.generate_password_reset_link(email, _action_settings("/login"))
    inner = ('<p style="margin:0 0 14px">Hi,</p>'
             '<p style="margin:0 0 6px">Someone asked to reset the password for your DSCVR account. If that was you, choose a new one here.</p>'
             f'{button("Reset my password", link)}'
             '<p style="margin:0 0 10px;color:#555;font-size:13px">The link works once and expires within the hour.</p>'
             '<p style="margin:0;color:#555;font-size:13px">If you didn\'t ask for this, ignore this email. Your password stays as it is.</p>')
    deliver([{"to": email, "subject": "Reset your DSCVR password",
              "html": layout(inner, preheader="Choose a new password.", footer=_service_footer(email))}])


def send_welcome(uid: str, email: str, name: str | None) -> None:
    app = _app_url()
    steps = [("Search a topic", "Try <strong>databases</strong>, <strong>calculus</strong> or <strong>macroeconomics</strong>. Discover finds free textbooks and course notes as well as research papers."),
             ("Save what's useful", "Add a paper, PDF or link to your library and sort it into categories."),
             ("Ask Pinda", "Pinda reads what you saved and answers with the passage it used, so you can check it.")]
    rows = "".join(f'<tr><td style="vertical-align:top;padding:6px 12px 6px 0;color:{BRAND};font-weight:700">{i}</td>'
                   f'<td style="padding:6px 0"><strong>{t}</strong><br><span style="color:#444">{d}</span></td></tr>' for i, (t, d) in enumerate(steps, 1))
    inner = (f'<p style="margin:0 0 14px">Hi {_first(name)},</p>'
             '<p style="margin:0 0 14px">Your DSCVR library is ready. Here is a good way to start:</p>'
             f'<table role="presentation" cellspacing="0" cellpadding="0">{rows}</table>'
             f'{button("Open DSCVR", app)}'
             '<p style="margin:0 0 10px">Something confusing, or missing for your course? Just reply to this email. A person reads it.</p>'
             '<p style="margin:0;color:#555">Anthony<br><span style="font-size:13px">Founder, AskPinda</span></p>')
    deliver([{"to": email, "subject": "Welcome to DSCVR",
              "html": layout(inner, preheader="Your library is ready. Here is how to start.", footer=_service_footer(email))}])


# ── Product updates (admin console) ──────────────────────────────────

def recipients(db=None) -> list[dict[str, Any]]:
    db = db or get_firestore_client()
    out = []
    for s in db.collection("users").where("emailUpdates", "==", True).limit(20000).get():
        d = s.to_dict() or {}
        if d.get("email") and d.get("emailVerified"):
            out.append({"uid": s.id, "email": d["email"], "name": d.get("displayName") or ""})
    return out


def send(subject: str, body: str, to: list[dict[str, Any]]) -> dict[str, int]:
    if not configured():
        raise MailError("Email isn't set up on the server. Add SMTP_USER and SMTP_PASSWORD (a Zoho app password).", 503)
    subject, body = (subject or "").strip()[:150], (body or "").strip()
    if len(subject) < 3 or len(body) < 10:
        raise MailError("Write a subject and a message first.")
    msgs = [{"to": r["email"], "subject": subject, "html": render(subject, body, r.get("name", ""), unsubscribe_url(r["uid"], "updates")),
             "headers": _one_click(r["uid"], "updates")} for r in to]
    return deliver(msgs)


# ── Alerts digest ────────────────────────────────────────────────────

def send_digest(uid: str, email: str, name: str | None, items: list[dict[str, Any]], names: dict[str, str]) -> None:
    app = _app_url()
    rows = []
    for p in items[:25]:
        meta = " · ".join(str(x) for x in (p.get("_subject"), names.get(p.get("source"), ""), p.get("venue") or p.get("year")) if x)
        rows.append(f'<tr><td style="padding:12px 0;border-bottom:1px solid #eee">'
                    f'<a href="{html.escape(p.get("url") or app)}" style="color:#111;font-weight:600;text-decoration:none">{html.escape(p.get("title") or "Untitled")}</a>'
                    f'<div style="color:#666;font-size:13px;margin-top:4px">{html.escape(meta)}</div></td></tr>')
    n = len(items)
    inner = (f'<p style="margin:0 0 14px">Hi {_first(name)},</p>'
             f'<p style="margin:0 0 10px">{n} new item{"s" if n != 1 else ""} in the subjects you follow on DSCVR.</p>'
             f'<table role="presentation" width="100%" cellspacing="0" cellpadding="0">{"".join(rows)}</table>'
             f'{button("Open your alerts", app + "/alerts")}')
    deliver([{"to": email, "subject": f"New in your subjects ({n})", "html": layout(inner, preheader=f"{n} new in your subjects.", footer=_marketing_footer(uid, "alerts")),
              "headers": _one_click(uid, "alerts")}])
