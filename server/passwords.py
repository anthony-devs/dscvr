"""Admin password hashing. Standard library only, so manage.py runs without the server's packages."""
import base64
import hashlib
import hmac
import re
import secrets


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    n, r, p = 2**14, 8, 1
    digest = hashlib.scrypt(password.encode(), salt=salt, n=n, r=r, p=p, dklen=32)
    return f"scrypt${n}${r}${p}${base64.b64encode(salt).decode()}${base64.b64encode(digest).decode()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        scheme, n, r, p, salt, digest = stored.split("$")
        if scheme != "scrypt":
            return False
        want = base64.b64decode(digest)
        got = hashlib.scrypt(password.encode(), salt=base64.b64decode(salt), n=int(n), r=int(r), p=int(p), dklen=len(want))
        return hmac.compare_digest(got, want)
    except Exception:  # noqa: BLE001
        return False


def password_problems(password: str, username: str = "") -> list[str]:
    out = []
    if len(password) < 12:
        out.append("at least 12 characters")
    for pattern, label in ((r"[a-z]", "a lowercase letter"), (r"[A-Z]", "an uppercase letter"),
                           (r"\d", "a number"), (r"[^A-Za-z0-9]", "a symbol")):
        if not re.search(pattern, password):
            out.append(label)
    if username and username.lower() in password.lower():
        out.append("no part of the username")
    if any(w in password.lower() for w in ("password", "dscvr", "qwerty", "123456", "letmein")):
        out.append("nothing easy to guess")
    return out


# ── 6-digit authenticator codes (RFC 6238), works with Google Authenticator, Authy, 1Password ──

import base64 as _b64
import struct
import time
from urllib.parse import quote


def totp_new_secret() -> str:
    """A fresh 160-bit secret in the base32 form authenticator apps expect."""
    return _b64.b32encode(secrets.token_bytes(20)).decode().rstrip("=")


def totp_clean(secret: str) -> str:
    return re.sub(r"[\s-]", "", secret or "").upper()


def totp_valid_secret(secret: str) -> bool:
    s = totp_clean(secret)
    if len(s) < 16 or not re.fullmatch(r"[A-Z2-7]+", s):
        return False
    try:
        _b64.b32decode(s + "=" * (-len(s) % 8))
        return True
    except Exception:  # noqa: BLE001
        return False


def totp_at(secret: str, step: int, digits: int = 6) -> str:
    s = totp_clean(secret)
    key = _b64.b32decode(s + "=" * (-len(s) % 8))
    mac = hmac.new(key, struct.pack(">Q", step), hashlib.sha1).digest()
    off = mac[-1] & 0x0F
    num = (struct.unpack(">I", mac[off:off + 4])[0] & 0x7FFFFFFF) % (10 ** digits)
    return str(num).zfill(digits)


def totp_verify(secret: str, code: str, now: float | None = None, window: int = 1) -> int | None:
    """The 30-second step the code belongs to (allowing one step of clock drift either way), or None."""
    code = re.sub(r"\s", "", code or "")
    if not re.fullmatch(r"\d{6}", code):
        return None
    step = int((time.time() if now is None else now) // 30)
    hit = None
    for s in range(step - window, step + window + 1):
        if hmac.compare_digest(totp_at(secret, s), code):  # no early exit, so timing says nothing
            hit = s
    return hit


def totp_uri(secret: str, account: str, issuer: str = "DSCVR Admin") -> str:
    return f"otpauth://totp/{quote(issuer)}:{quote(account)}?secret={totp_clean(secret)}&issuer={quote(issuer)}&algorithm=SHA1&digits=6&period=30"
