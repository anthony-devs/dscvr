"""Safe outbound fetching for user-supplied URLs (PDFs).

Guards against SSRF: https/http only, public IPs only (checked after DNS
resolution and on every redirect), a size cap, and a timeout.
"""
from __future__ import annotations

import ipaddress
import re
import socket
from typing import Iterator
from urllib.parse import quote, urljoin, urlparse

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


_IA_GUESS = re.compile(r"^https://archive\.org/download/([^/]+)/\1\.pdf$")


def _archive_org_pdf(url: str) -> str | None:
    """Internet Archive search results link <id>/<id>.pdf. Some items name the scan
    differently; find the real PDF in the item's file list."""
    m = _IA_GUESS.match(url)
    if not m:
        return None
    try:
        r = requests.get(f"https://archive.org/metadata/{m.group(1)}/files", timeout=TIMEOUT,
                         headers={"User-Agent": "DSCVR/1.0 (research library)"})
        files = [f.get("name", "") for f in r.json().get("result") or []]
    except (requests.RequestException, ValueError):
        return None
    pdfs = sorted((f for f in files if f.lower().endswith(".pdf")), key=lambda f: ("_bw" in f, "_text" in f, len(f)))
    return f"https://archive.org/download/{m.group(1)}/{quote(pdfs[0])}" if pdfs else None


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
        if resp.status_code == 404 and current == url and (alt := _archive_org_pdf(url)):
            resp.close()
            current = alt
            continue
        if resp.status_code != 200:
            resp.close()
            raise ValueError(f"Source returned {resp.status_code}.")
        if int(resp.headers.get("Content-Length") or 0) > max_bytes:
            resp.close()
            raise ValueError("That PDF is too large.")
        return resp
    raise ValueError("Too many redirects.")


def archive_org_text_url(url: str) -> str | None:
    """The OCR text of an Internet Archive item, from one of its download links."""
    m = re.match(r"^https://archive\.org/download/([^/]+)/", url or "")
    return f"https://archive.org/download/{m.group(1)}/{m.group(1)}_djvu.txt" if m else None


def fetch_text(url: str, max_chars: int = 400_000) -> str:
    """Downloads a public plain-text file (with the same private-network guard)."""
    resp = _open(url, 20 * MB)
    out: list[bytes] = []
    total = 0
    for chunk in resp.iter_content(256 * 1024):
        out.append(chunk)
        total += len(chunk)
        if total > max_chars * 4:
            break
    resp.close()
    return b"".join(out).decode("utf-8", "replace")[:max_chars]


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
