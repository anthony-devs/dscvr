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
