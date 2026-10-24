/**
 * DSCVR Cloud Functions
 *
 *   pinda     POST  Streams Claude answers grounded in the user's library (SSE).
 *   unfurl    POST  Title, metadata and readable text for a link or YouTube video.
 *   discover  GET   arXiv / Semantic Scholar search proxy (the web app needs it
 *                   because those APIs do not send CORS headers).
 *
 * Setup:
 *   firebase functions:secrets:set ANTHROPIC_API_KEY
 *   cd functions && npm install && npm run deploy
 */
import Anthropic from "@anthropic-ai/sdk";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { setGlobalOptions } from "firebase-functions/v2";
import { onRequest } from "firebase-functions/v2/https";
import { defineInt, defineSecret, defineString } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import { searchArxiv, searchSemanticScholar } from "./discover";
import { FetchError } from "./net";
import { buildContext, buildMessages, checkQuota, PindaRequest, STYLE, SYSTEM } from "./pinda";
import { unfurl as unfurlUrl } from "./unfurl";

initializeApp();
setGlobalOptions({ region: "us-central1", maxInstances: 20 });

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");
const PINDA_MODEL = defineString("PINDA_MODEL", { default: "claude-sonnet-5-5" });
const PINDA_DAILY_LIMIT = defineInt("PINDA_DAILY_LIMIT", { default: 150 });

/** Origins allowed to call the functions from a browser. Mobile apps send no
 *  Origin header and are unaffected. Add your custom domain here. */
const ALLOWED_ORIGINS = [
  /^https:\/\/dscvr-9d362\.(web\.app|firebaseapp\.com)$/,
  /^http:\/\/localhost(:\d+)?$/,
  /^http:\/\/127\.0\.0\.1(:\d+)?$/,
];

async function uidFrom(authHeader: string | undefined): Promise<string | null> {
  const token = authHeader?.match(/^Bearer (.+)$/)?.[1];
  if (!token) return null;
  try {
    return (await getAuth().verifyIdToken(token)).uid;
  } catch {
    return null;
  }
}

export const pinda = onRequest(
  { cors: ALLOWED_ORIGINS, secrets: [ANTHROPIC_API_KEY], timeoutSeconds: 300, memory: "1GiB" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Use POST" });
      return;
    }
    const uid = await uidFrom(req.headers.authorization);
    if (!uid) {
      res.status(401).json({ error: "Sign in to use Pinda." });
      return;
    }
    if (!(await checkQuota(uid, PINDA_DAILY_LIMIT.value()))) {
      res.status(429).json({ error: "You have reached today's Pinda limit. It resets at midnight UTC." });
      return;
    }

    const body = (req.body ?? {}) as PindaRequest;
    const scope = body.context?.scope ?? "general";
    if (!["general", "category", "topic", "material"].includes(scope)) {
      res.status(400).json({ error: "Unknown context" });
      return;
    }

    let messages;
    try {
      const context = await buildContext(uid, scope, body.context?.id ?? null);
      messages = buildMessages(body, context);
    } catch (e) {
      logger.error("pinda context failed", e);
      res.status(500).json({ error: "Could not load your library for Pinda." });
      return;
    }
    if (!messages.length) {
      res.status(400).json({ error: "Ask a question first." });
      return;
    }

    res.status(200);
    res.setHeader("Content-Type", "text/event-stream; charset=utf-8");
    res.setHeader("Cache-Control", "no-cache, no-transform");
    res.setHeader("X-Accel-Buffering", "no");
    res.flushHeaders?.();
    const send = (event: object) => res.write(`data: ${JSON.stringify(event)}\n\n`);

    const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });
    const style = body.style === "concise" ? "concise" : "detailed";
    try {
      const stream = client.messages.stream({
        model: PINDA_MODEL.value(),
        max_tokens: style === "concise" ? 1500 : 4096,
        system: `${SYSTEM}\n\n${STYLE[style]}`,
        messages,
      });
      req.on("close", () => stream.abort());
      for await (const event of stream) {
        if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
          send({ type: "delta", text: event.delta.text });
        }
      }
      send({ type: "done" });
    } catch (e) {
      logger.error("pinda stream failed", e);
      const status = (e as { status?: number }).status;
      send({
        type: "error",
        message:
          status === 429 || status === 529
            ? "Pinda is busy right now. Try again in a moment."
            : "Pinda could not finish that answer. Please try again.",
      });
    } finally {
      res.end();
    }
  }
);

export const unfurl = onRequest({ cors: ALLOWED_ORIGINS, timeoutSeconds: 30, memory: "512MiB" }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Use POST" });
    return;
  }
  const url = (req.body as { url?: string } | undefined)?.url;
  if (!url || typeof url !== "string" || url.length > 2048) {
    res.status(400).json({ error: "Provide a url" });
    return;
  }
  try {
    res.json(await unfurlUrl(url));
  } catch (e) {
    const status = e instanceof FetchError ? e.status : 502;
    res.status(status).json({ error: e instanceof Error ? e.message : "Could not read that page" });
  }
});

export const discover = onRequest({ cors: ALLOWED_ORIGINS, timeoutSeconds: 30 }, async (req, res) => {
  const q = String(req.query.q ?? "").trim().slice(0, 300);
  const source = String(req.query.source ?? "arxiv");
  const sort = req.query.sort === "date" ? "date" : "relevance";
  const limit = Math.min(Math.max(Number(req.query.limit ?? 20) || 20, 1), 50);
  if (!q) {
    res.status(400).json({ error: "Provide q" });
    return;
  }
  try {
    const papers =
      source === "semantic_scholar"
        ? await searchSemanticScholar(q, limit, process.env.S2_API_KEY)
        : await searchArxiv(q, sort, limit);
    res.set("Cache-Control", "public, max-age=600, s-maxage=600");
    res.json({ papers });
  } catch (e) {
    logger.warn("discover failed", e);
    res.status(502).json({ error: "Search provider unavailable" });
  }
});
