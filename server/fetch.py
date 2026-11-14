"""Safe outbound fetching for user-supplied URLs (PDFs).

Guards against SSRF: https/http only, public IPs only (checked after DNS
resolution and on every redirect), a size cap, and a timeout.
"""
from __future__ import annotations

import ipaddress
import socket
from typing import Iterator
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


MB = 1024 * 1024
# Scanned history books from the Internet Archive or the Library of Congress
# are often 50 to 200 MB, so the viewer streams up to VIEW_MAX and imports
# keep up to IMPORT_MAX.
VIEW_MAX = 250 * MB
IMPORT_MAX = 120 * MB


def _open(url: str, max_bytes: int) -> requests.Response:
    """Follows redirects safely and returns an open 200 response."""
    current = url
    for _ in range(MAX_REDIRECTS + 1):
        _check_host(current)
        resp = requests.get(current, stream=True, timeout=TIMEOUT, allow_redirects=False,
                            headers={"User-Agent": "DSCVR/1.0 (research library)",
                                     # Some repositories (Zenodo) answer 406 to a strict "application/pdf".
                                     "Accept": "application/pdf,*/*;q=0.8"})
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
        if int(resp.headers.get("Content-Length") or 0) > max_bytes:
            resp.close()
            raise ValueError("That PDF is too large.")
        return resp
    raise ValueError("Too many redirects.")


def fetch_pdf(url: str, max_bytes: int = IMPORT_MAX) -> bytes:
    """Downloads a PDF from a public URL. Raises UnsafeUrl or ValueError."""
    resp = _open(url, max_bytes)
    chunks: list[bytes] = []
    total = 0
    for chunk in resp.iter_content(256 * 1024):
        total += len(chunk)
        if total > max_bytes:
            resp.close()
            raise ValueError("That PDF is too large.")
        chunks.append(chunk)
    data = b"".join(chunks)
    if not data.startswith(b"%PDF"):
        raise ValueError("That link is not a PDF.")
    return data


def stream_pdf(url: str, max_bytes: int = VIEW_MAX) -> tuple[Iterator[bytes], int | None]:
    """Opens a PDF and returns (chunks, length) without holding it all in memory.
    Checks the first bytes are a PDF before returning."""
    resp = _open(url, max_bytes)
    it = resp.iter_content(256 * 1024)
    first = b""
    try:
        while len(first) < 5:
            first += next(it)
    except StopIteration:
        pass
    if not first.lstrip()[:5].startswith(b"%PDF"):
        resp.close()
        raise ValueError("That link is not a PDF.")
    length = int(resp.headers.get("Content-Length") or 0) or None

    def gen() -> Iterator[bytes]:
        total = len(first)
        try:
            yield first
            for chunk in it:
                total += len(chunk)
                if total > max_bytes:
                    break
                yield chunk
        finally:
            resp.close()
    return gen(), length
