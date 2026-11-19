import { config } from "./config.js";

export class ApiError extends Error {
  constructor(message, status, body) {
    super(message);
    this.status = status;
    this.body = body || {};
  }
}

export async function getAuth() {
  const { token, email, name } = await chrome.storage.local.get(["token", "email", "name"]);
  return token ? { token, email, name } : null;
}

export async function setAuth(auth) {
  if (auth) await chrome.storage.local.set(auth);
  else await chrome.storage.local.remove(["token", "email", "name"]);
}

async function request(path, { method = "GET", body, token, signal } = {}) {
  const { serverUrl } = await config();
  const auth = token || (await getAuth())?.token;
  let res;
  try {
    res = await fetch(serverUrl + path, {
      method,
      signal,
      headers: {
        ...(auth ? { Authorization: `Bearer ${auth}` } : {}),
        ...(body ? { "Content-Type": "application/json" } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch (e) {
    if (e.name === "AbortError") throw e;
    throw new ApiError("Couldn't reach DSCVR. Check your connection and try again.", 0);
  }
  if (res.status === 401 && !token) await setAuth(null); // token revoked or expired
  return res;
}

async function json(res) {
  let data = {};
  try {
    data = await res.json();
  } catch {}
  if (!res.ok) throw new ApiError(data.error || `Something went wrong (${res.status}).`, res.status, data);
  return data;
}

export const api = {
  get: async (path, opts) => json(await request(path, opts)),
  post: async (path, body, opts = {}) => json(await request(path, { ...opts, method: "POST", body: body || {} })),

  /** Streams Pinda's reply. Calls onDelta(text) as it arrives. */
  async stream(path, body, onDelta, signal) {
    const res = await request(path, { method: "POST", body, signal });
    if (!res.ok) await json(res);
    const reader = res.body.getReader();
    const dec = new TextDecoder();
    let buf = "";
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      buf += dec.decode(value, { stream: true });
      let i;
      while ((i = buf.indexOf("\n\n")) >= 0) {
        const chunk = buf.slice(0, i);
        buf = buf.slice(i + 2);
        for (const line of chunk.split("\n")) {
          if (!line.startsWith("data:")) continue;
          let ev;
          try {
            ev = JSON.parse(line.slice(5).trim());
          } catch {
            continue;
          }
          if (ev.type === "delta") onDelta(ev.text || "");
          else if (ev.type === "error") throw new ApiError(ev.message || "Pinda couldn't answer.", 500);
        }
      }
    }
  },
};
