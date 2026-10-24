import { lookup } from "node:dns/promises";
import { isIP } from "node:net";

/**
 * Fetch helper for user-supplied URLs.
 *
 * Blocks requests to private, loopback and link-local addresses so the
 * unfurl endpoint cannot be used to probe Google's internal network (SSRF),
 * enforces a timeout and caps the response size.
 */
export class FetchError extends Error {
  constructor(message: string, public status = 400) {
    super(message);
  }
}

const MAX_BYTES = 30 * 1024 * 1024;

function isPrivateAddress(ip: string): boolean {
  if (isIP(ip) === 4) {
    const [a, b] = ip.split(".").map(Number);
    return (
      a === 10 ||
      a === 127 ||
      a === 0 ||
      (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 168) ||
      (a === 100 && b >= 64 && b <= 127)
    );
  }
  const v6 = ip.toLowerCase();
  return (
    v6 === "::1" ||
    v6 === "::" ||
    v6.startsWith("fc") ||
    v6.startsWith("fd") ||
    v6.startsWith("fe80") ||
    v6.startsWith("::ffff:10.") ||
    v6.startsWith("::ffff:127.") ||
    v6.startsWith("::ffff:192.168.") ||
    v6.startsWith("::ffff:169.254.")
  );
}

export async function assertPublicUrl(raw: string): Promise<URL> {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new FetchError("Invalid URL");
  }
  if (url.protocol !== "https:" && url.protocol !== "http:") {
    throw new FetchError("Only http and https links are supported");
  }
  if (url.username || url.password) throw new FetchError("URLs with credentials are not allowed");
  const host = url.hostname.replace(/^\[|\]$/g, "");
  if (host === "localhost" || host.endsWith(".internal") || host.endsWith(".local")) {
    throw new FetchError("That address is not reachable");
  }
  const addresses = isIP(host) ? [{ address: host }] : await lookup(host, { all: true });
  if (addresses.length === 0 || addresses.some((a) => isPrivateAddress(a.address))) {
    throw new FetchError("That address is not reachable");
  }
  return url;
}

export interface FetchedBody {
  url: string;
  contentType: string;
  bytes: Buffer;
}

/** Fetches a public URL, following up to 5 redirects with re-validation. */
export async function safeFetch(
  raw: string,
  opts: { timeoutMs?: number; maxBytes?: number; accept?: string } = {}
): Promise<FetchedBody> {
  let current = raw;
  for (let hop = 0; hop < 6; hop++) {
    const url = await assertPublicUrl(current);
    const res = await fetch(url, {
      redirect: "manual",
      signal: AbortSignal.timeout(opts.timeoutMs ?? 15000),
      headers: {
        "User-Agent": "Mozilla/5.0 (compatible; DSCVR/1.0; +https://dscvr.app)",
        Accept: opts.accept ?? "text/html,application/xhtml+xml,application/pdf;q=0.9,*/*;q=0.8",
      },
    });
    if (res.status >= 300 && res.status < 400 && res.headers.get("location")) {
      current = new URL(res.headers.get("location")!, url).toString();
      continue;
    }
    if (!res.ok) throw new FetchError(`The site responded with ${res.status}`, 502);
    const limit = opts.maxBytes ?? MAX_BYTES;
    const declared = Number(res.headers.get("content-length") ?? 0);
    if (declared > limit) throw new FetchError("That file is too large", 413);
    const reader = res.body?.getReader();
    const chunks: Uint8Array[] = [];
    let total = 0;
    if (reader) {
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        total += value.byteLength;
        if (total > limit) {
          await reader.cancel();
          throw new FetchError("That file is too large", 413);
        }
        chunks.push(value);
      }
    }
    return {
      url: url.toString(),
      contentType: res.headers.get("content-type") ?? "",
      bytes: Buffer.concat(chunks),
    };
  }
  throw new FetchError("Too many redirects", 502);
}
