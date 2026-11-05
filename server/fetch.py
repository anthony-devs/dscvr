"""Safe outbound fetching for user-supplied URLs (PDFs).

Guards against SSRF: https/http only, public IPs only (checked after DNS
resolution and on every redirect), a size cap, and a timeout.
"""
from __future__ import annotations

import ipaddress
import socket
from urllib.parse import urljoin, urlparse

import requests

MAX_REDIRECTS = 4
TIMEOUT = 20


class UnsafeUrl(Exception):
    pass


def _check_host(url: str) -> None:
    parsed = urlparse(url)
    if parsed.scheme not in ("https", "http") or not parsed.hostname:
        raise UnsafeUrl("Only public http(s) links are allowed.")
    try:
        infos = socket.getaddrinfo(parsed.hostname, parsed.port or (443 if parsed.scheme == "https" else 80))
    except socket.gaierror as e:
        raise UnsafeUrl("Could not resolve that address.") from e
    for info in infos:
        ip = ipaddress.ip_address(info[4][0])
        if not ip.is_global or ip.is_multicast:
            raise UnsafeUrl("That address is not allowed.")


def fetch_pdf(url: str, max_bytes: int = 30 * 1024 * 1024) -> bytes:
    """Downloads a PDF from a public URL. Raises UnsafeUrl or ValueError."""
    current = url
    for _ in range(MAX_REDIRECTS + 1):
        _check_host(current)
        resp = requests.get(current, stream=True, timeout=TIMEOUT, allow_redirects=False,
                            headers={"User-Agent": "DSCVR/1.0 (research library)", "Accept": "application/pdf"})
        if resp.is_redirect or resp.status_code in (301, 302, 303, 307, 308):
            location = resp.headers.get("Location")
            resp.close()
            if not location:
                raise ValueError("Broken redirect.")
            current = urljoin(current, location)
            continue
        if resp.status_code != 200:
            resp.close()
            raise ValueError(f"Source returned {resp.status_code}.")
        declared = int(resp.headers.get("Content-Length") or 0)
        if declared > max_bytes:
            resp.close()
            raise ValueError("That PDF is too large.")
        chunks: list[bytes] = []
        total = 0
        for chunk in resp.iter_content(64 * 1024):
            total += len(chunk)
            if total > max_bytes:
                resp.close()
                raise ValueError("That PDF is too large.")
            chunks.append(chunk)
        data = b"".join(chunks)
        if not data.startswith(b"%PDF"):
            raise ValueError("That link is not a PDF.")
        return data
    raise ValueError("Too many redirects.")
