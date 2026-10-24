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
import { getFirestore } from "firebase-admin/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import { onRequest } from "firebase-functions/v2/https";
import { defineInt, defineSecret, defineString } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import { searchArxiv, searchSemanticScholar } from "./discover";
import { FetchError } from "./net";
import { buildContext, buildMessages, checkQuota, PindaRequest, STYLE, SYSTEM } from "./pinda";
import { bodyTooLarge, checkRate, getUserTier, logAndDetectAbuse, requireTier, sanitize } from "./security";
import { unfurl as unfurlUrl } from "./unfurl";

initializeApp();
setGlobalOptions({ region: "us-central1", maxInstances: 20 });

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");
const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");
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
    // Security: request size cap (512KB)
    if (bodyTooLarge(req.rawBody, 512 * 1024)) {
      res.status(413).json({ error: "Request too large." });
      return;
    }
    const uid = await uidFrom(req.headers.authorization);
    if (!uid) {
      res.status(401).json({ error: "Sign in to use Pinda." });
      return;
    }
    // Security: rate limit
    const ratErr = checkRate(uid, "pinda");
    if (ratErr) { res.status(429).json({ error: ratErr }); return; }
    logAndDetectAbuse(uid, "pinda").catch(() => {});

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
  if (bodyTooLarge(req.rawBody, 8 * 1024)) {
    res.status(413).json({ error: "Request too large." });
    return;
  }
  // Rate limit unfurl by IP (no auth required)
  const ip = req.ip ?? "unknown";
  const ratErr = checkRate(ip, "unfurl");
  if (ratErr) { res.status(429).json({ error: ratErr }); return; }

  const url = sanitize((req.body as { url?: string } | undefined)?.url, 2048);
  if (!url) {
    res.status(400).json({ error: "Provide a url" });
    return;
  }
  // Block private/internal URLs
  if (/^https?:\/\/(localhost|127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/i.test(url)) {
    res.status(400).json({ error: "Cannot unfurl internal URLs." });
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
  // Rate limit by IP (discover is unauthenticated)
  const discoverIp = req.ip ?? "unknown";
  const discoverRatErr = checkRate(discoverIp, "discover");
  if (discoverRatErr) { res.status(429).json({ error: discoverRatErr }); return; }

  const q = sanitize(req.query.q, 300);
  const source = sanitize(req.query.source, 30) || "arxiv";
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

/* ------------------------------------------------------------------ */
/*  Stripe: checkout, webhook, customer portal                        */
/* ------------------------------------------------------------------ */

/** Price IDs — set these to your real Stripe price IDs. */
const STRIPE_PRICES: Record<string, { monthly: string; yearly: string }> = {
  pro: {
    monthly: process.env.STRIPE_PRO_MONTHLY || "price_pro_monthly",
    yearly: process.env.STRIPE_PRO_YEARLY || "price_pro_yearly",
  },
  team: {
    monthly: process.env.STRIPE_TEAM_MONTHLY || "price_team_monthly",
    yearly: process.env.STRIPE_TEAM_YEARLY || "price_team_yearly",
  },
};

/**
 * POST /checkout
 * Body: { tier: "pro"|"team", interval: "monthly"|"yearly" }
 * Returns: { url: string } — the Stripe Checkout Session URL.
 */
export const checkout = onRequest(
  { cors: ALLOWED_ORIGINS, secrets: [STRIPE_SECRET_KEY], timeoutSeconds: 30 },
  async (req, res) => {
    if (req.method !== "POST") { res.status(405).json({ error: "Use POST" }); return; }
    if (bodyTooLarge(req.rawBody, 4 * 1024)) {
      res.status(413).json({ error: "Request too large." }); return;
    }
    const uid = await uidFrom(req.headers.authorization);
    if (!uid) { res.status(401).json({ error: "Sign in first." }); return; }
    const checkoutRatErr = checkRate(uid, "checkout");
    if (checkoutRatErr) { res.status(429).json({ error: checkoutRatErr }); return; }
    logAndDetectAbuse(uid, "checkout").catch(() => {});

    const { tier, interval } = req.body as { tier?: string; interval?: string };
    if (!tier || !["pro", "team"].includes(tier)) {
      res.status(400).json({ error: "Invalid tier" }); return;
    }
    const billingInterval = interval === "yearly" ? "yearly" : "monthly";
    const priceId = STRIPE_PRICES[tier]?.[billingInterval];
    if (!priceId) { res.status(400).json({ error: "Price not configured" }); return; }

    const Stripe = (await import("stripe")).default;
    const stripe = new Stripe(STRIPE_SECRET_KEY.value(), { apiVersion: "2025-04-30.basil" });
    const db = getFirestore();

    // Get or create Stripe customer
    const userDoc = await db.doc(`users/${uid}`).get();
    const userData = userDoc.data() ?? {};
    let customerId = userData.subscription?.stripeCustomerId as string | undefined;

    if (!customerId) {
      const auth = getAuth();
      const userRecord = await auth.getUser(uid);
      const customer = await stripe.customers.create({
        email: userRecord.email ?? undefined,
        metadata: { firebaseUid: uid },
      });
      customerId = customer.id;
      await db.doc(`users/${uid}`).set(
        { subscription: { stripeCustomerId: customerId } },
        { merge: true },
      );
    }

    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      mode: "subscription",
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: `${req.headers.origin ?? "https://dscvr-9d362.web.app"}/settings?checkout=success`,
      cancel_url: `${req.headers.origin ?? "https://dscvr-9d362.web.app"}/settings?checkout=cancel`,
      subscription_data: { metadata: { firebaseUid: uid, tier } },
      metadata: { firebaseUid: uid, tier },
    });

    res.json({ url: session.url });
  },
);

/**
 * POST /stripeWebhook
 * Stripe sends events here. Verifies the signature and updates Firestore.
 */
export const stripeWebhook = onRequest(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET], timeoutSeconds: 60 },
  async (req, res) => {
    if (req.method !== "POST") { res.status(405).end(); return; }

    const Stripe = (await import("stripe")).default;
    const stripe = new Stripe(STRIPE_SECRET_KEY.value(), { apiVersion: "2025-04-30.basil" });
    const sig = req.headers["stripe-signature"] as string;

    let event;
    try {
      event = stripe.webhooks.constructEvent(req.rawBody, sig, STRIPE_WEBHOOK_SECRET.value());
    } catch (e) {
      logger.warn("Stripe webhook signature verification failed", e);
      res.status(400).send("Webhook signature verification failed");
      return;
    }

    const db = getFirestore();

    const syncSubscription = async (sub: { id: string; customer: string; metadata: Record<string, string>; status: string; items: { data: Array<{ price: { id: string; recurring?: { interval?: string } | null } }> }; current_period_end: number; cancel_at_period_end: boolean }) => {
      const uid = sub.metadata.firebaseUid;
      if (!uid) {
        logger.warn("Stripe subscription missing firebaseUid metadata", sub.id);
        return;
      }

      const tier = sub.metadata.tier ?? "pro";
      const isActive = ["active", "trialing"].includes(sub.status);
      const priceInterval = sub.items.data[0]?.price.recurring?.interval;

      await db.doc(`users/${uid}`).set(
        {
          subscription: {
            tier: isActive ? tier : "free",
            stripeCustomerId: typeof sub.customer === "string" ? sub.customer : (sub.customer as { id: string }).id,
            stripeSubscriptionId: sub.id,
            interval: priceInterval === "year" ? "yearly" : "monthly",
            currentPeriodEnd: new Date(sub.current_period_end * 1000).toISOString(),
            cancelAtPeriodEnd: sub.cancel_at_period_end,
          },
        },
        { merge: true },
      );
      logger.info(`Subscription synced for ${uid}: ${tier} (${sub.status})`);
    };

    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object;
        if (session.subscription) {
          const sub = await stripe.subscriptions.retrieve(session.subscription as string);
          // Copy metadata from session to subscription if missing
          if (!sub.metadata.firebaseUid && session.metadata?.firebaseUid) {
            await stripe.subscriptions.update(sub.id, {
              metadata: { firebaseUid: session.metadata.firebaseUid, tier: session.metadata.tier ?? "pro" },
            });
            sub.metadata = { ...sub.metadata, ...session.metadata };
          }
          await syncSubscription(sub as Parameters<typeof syncSubscription>[0]);
        }
        break;
      }
      case "customer.subscription.updated":
      case "customer.subscription.deleted":
        await syncSubscription(event.data.object as Parameters<typeof syncSubscription>[0]);
        break;
      default:
        logger.info(`Unhandled Stripe event: ${event.type}`);
    }

    res.json({ received: true });
  },
);

/* ------------------------------------------------------------------ */
/*  Parliament Fact-Check — multi-perspective claim analysis           */
/* ------------------------------------------------------------------ */

const PARLIAMENT_ROLES = [
  {
    role: "Advocate",
    system: `You are a research advocate. Your job is to find the strongest evidence SUPPORTING the claim. Look for studies, data, and logical arguments that back it up. Be thorough but honest — if the evidence is weak, say so.`,
  },
  {
    role: "Skeptic",
    system: `You are a research skeptic. Your job is to find the strongest evidence AGAINST the claim or identify weaknesses. Look for counter-evidence, methodological flaws, logical fallacies, and alternative explanations. Be rigorous but fair.`,
  },
  {
    role: "Analyst",
    system: `You are a neutral research analyst. Your job is to evaluate the claim objectively, weighing both supporting and opposing evidence. Consider the quality of evidence, potential biases, and what additional information would be needed for a definitive conclusion.`,
  },
];

const PARLIAMENT_SCHEMA = {
  type: "object" as const,
  properties: {
    verdict: { type: "string" as const, enum: ["supported", "partially_supported", "unsupported", "insufficient_evidence"] },
    confidence: { type: "number" as const, minimum: 0, maximum: 1 },
    reasoning: { type: "string" as const, description: "2-4 sentence reasoning for this verdict." },
  },
  required: ["verdict", "confidence", "reasoning"],
};

/**
 * POST /parliament
 * Body: { claim: string, context?: string }
 * Returns: { claim, votes[], consensus, summary, sources[] }
 */
export const parliament = onRequest(
  { cors: ALLOWED_ORIGINS, secrets: [ANTHROPIC_API_KEY], timeoutSeconds: 120, memory: "1GiB" },
  async (req, res) => {
    if (req.method !== "POST") { res.status(405).json({ error: "Use POST" }); return; }
    if (bodyTooLarge(req.rawBody, 32 * 1024)) {
      res.status(413).json({ error: "Request too large." }); return;
    }
    const uid = await uidFrom(req.headers.authorization);
    if (!uid) { res.status(401).json({ error: "Sign in to use Parliament." }); return; }
    const parlRatErr = checkRate(uid, "parliament");
    if (parlRatErr) { res.status(429).json({ error: parlRatErr }); return; }
    logAndDetectAbuse(uid, "parliament").catch(() => {});

    // Check subscription tier — Parliament is Pro+ only
    const userTier = await getUserTier(uid);
    const tierErr = requireTier(userTier, "pro");
    if (tierErr) {
      res.status(403).json({ error: tierErr });
      return;
    }

    const claim = sanitize((req.body as { claim?: string })?.claim, 2000);
    const ctx = sanitize((req.body as { context?: string })?.context, 5000);
    if (!claim || claim.length < 5) {
      res.status(400).json({ error: "Provide a claim (5-2000 characters)." });
      return;
    }

    const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });
    const userMessage = ctx
      ? `Claim to evaluate:\n"${claim}"\n\nContext from the source material:\n${ctx.slice(0, 3000)}`
      : `Claim to evaluate:\n"${claim}"`;


    try {
      // Run all three perspectives in parallel
      const votePromises = PARLIAMENT_ROLES.map(async ({ role, system }) => {
        const response = await client.messages.create({
          model: PINDA_MODEL.value(),
          max_tokens: 600,
          system,
          messages: [{ role: "user", content: userMessage }],
          tools: [{
            name: "submit_verdict",
            description: "Submit your verdict on this claim.",
            input_schema: PARLIAMENT_SCHEMA,
          }],
          tool_choice: { type: "tool", name: "submit_verdict" },
        });

        const toolBlock = response.content.find((b) => b.type === "tool_use");
        if (!toolBlock || toolBlock.type !== "tool_use") {
          return { role, verdict: "insufficient_evidence", confidence: 0, reasoning: "Could not evaluate this claim." };
        }
        const input = toolBlock.input as { verdict: string; confidence: number; reasoning: string };
        return { role, ...input };
      });

      const votes = await Promise.all(votePromises);

      // Derive consensus: majority verdict, or "partially_supported" on tie
      const verdictCounts: Record<string, number> = {};
      for (const v of votes) {
        verdictCounts[v.verdict] = (verdictCounts[v.verdict] ?? 0) + 1;
      }
      let consensus = "partially_supported";
      let maxCount = 0;
      for (const [verdict, count] of Object.entries(verdictCounts)) {
        if (count > maxCount) { maxCount = count; consensus = verdict; }
      }

      // Generate a brief synthesis
      const synthResponse = await client.messages.create({
        model: PINDA_MODEL.value(),
        max_tokens: 300,
        system: "You are a fact-check editor. Synthesize the three perspectives into a 2-3 sentence summary. Be direct and clear.",
        messages: [{
          role: "user",
          content: `Claim: "${claim}"\n\nVerdicts:\n${votes.map((v) => `- ${v.role} (${v.verdict}, ${Math.round(v.confidence * 100)}% confident): ${v.reasoning}`).join("\n")}\n\nWrite a 2-3 sentence synthesis.`,
        }],
      });
      const summaryBlock = synthResponse.content.find((b) => b.type === "text");
      const summary = summaryBlock && summaryBlock.type === "text" ? summaryBlock.text : "Multiple perspectives were considered.";

      res.json({ claim, votes, consensus, summary, sources: [] });
    } catch (e) {
      logger.error("parliament failed", e);
      res.status(500).json({ error: "Parliament could not evaluate that claim. Try again." });
    }
  },
);

/**
 * POST /customerPortal
 * Returns: { url: string } — the Stripe Customer Portal URL.
 */
export const customerPortal = onRequest(
  { cors: ALLOWED_ORIGINS, secrets: [STRIPE_SECRET_KEY], timeoutSeconds: 30 },
  async (req, res) => {
    if (req.method !== "POST") { res.status(405).json({ error: "Use POST" }); return; }
    const uid = await uidFrom(req.headers.authorization);
    if (!uid) { res.status(401).json({ error: "Sign in first." }); return; }
    const portalRatErr = checkRate(uid, "portal");
    if (portalRatErr) { res.status(429).json({ error: portalRatErr }); return; }

    const db = getFirestore();
    const userDoc = await db.doc(`users/${uid}`).get();
    const customerId = userDoc.data()?.subscription?.stripeCustomerId as string | undefined;
    if (!customerId) {
      res.status(400).json({ error: "No billing account found. Subscribe to a plan first." });
      return;
    }

    const Stripe = (await import("stripe")).default;
    const stripe = new Stripe(STRIPE_SECRET_KEY.value(), { apiVersion: "2025-04-30.basil" });
    const session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: `${req.headers.origin ?? "https://dscvr-9d362.web.app"}/settings`,
    });

    res.json({ url: session.url });
  },
);
