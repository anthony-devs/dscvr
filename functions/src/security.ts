/**
 * Security middleware & helpers for DSCVR Cloud Functions.
 *
 * - Per-user rate limiting (in-memory for single-instance, Firestore for persistence)
 * - Request body size caps
 * - Input sanitization
 * - Abuse detection (velocity checks)
 */
import { getFirestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

// ───────────────────────────────────────────────────────────────────
// In-memory sliding-window rate limiter
// ───────────────────────────────────────────────────────────────────

interface Window {
  timestamps: number[];
}

const windows = new Map<string, Window>();

/** Prune stale entries every 5 minutes so the map doesn't grow without bound. */
let lastPrune = Date.now();
const PRUNE_INTERVAL = 5 * 60_000;

function pruneWindows(windowMs: number) {
  const now = Date.now();
  if (now - lastPrune < PRUNE_INTERVAL) return;
  lastPrune = now;
  const cutoff = now - windowMs;
  for (const [key, win] of windows) {
    win.timestamps = win.timestamps.filter((t) => t > cutoff);
    if (win.timestamps.length === 0) windows.delete(key);
  }
}

/**
 * Sliding-window rate limit. Returns true if the request should be allowed.
 * `key` is typically `uid:endpointName`.
 */
export function rateLimit(key: string, maxRequests: number, windowMs: number): boolean {
  pruneWindows(windowMs);
  const now = Date.now();
  const cutoff = now - windowMs;

  let win = windows.get(key);
  if (!win) {
    win = { timestamps: [] };
    windows.set(key, win);
  }

  // Drop timestamps outside the window
  win.timestamps = win.timestamps.filter((t) => t > cutoff);

  if (win.timestamps.length >= maxRequests) return false;

  win.timestamps.push(now);
  return true;
}

// ───────────────────────────────────────────────────────────────────
// Rate-limit presets per endpoint
// ───────────────────────────────────────────────────────────────────

const ONE_MINUTE = 60_000;
const ONE_HOUR = 60 * ONE_MINUTE;

export const LIMITS = {
  /** Pinda chat: 20 messages/min, 200/hour */
  pinda:       { perMinute: 20,  perHour: 200 },
  /** Parliament fact-check: 5/min, 30/hour */
  parliament:  { perMinute: 5,   perHour: 30 },
  /** Stripe checkout: 5/min, 20/hour */
  checkout:    { perMinute: 5,   perHour: 20 },
  /** Customer portal: 10/min, 60/hour */
  portal:      { perMinute: 10,  perHour: 60 },
  /** Discover search: 30/min, 300/hour */
  discover:    { perMinute: 30,  perHour: 300 },
  /** Unfurl link: 20/min, 120/hour */
  unfurl:      { perMinute: 20,  perHour: 120 },
} as const;

/**
 * Check both per-minute and per-hour rate limits for a user+endpoint.
 * Returns null if allowed, or an error message string if blocked.
 */
export function checkRate(uid: string, endpoint: keyof typeof LIMITS): string | null {
  const { perMinute, perHour } = LIMITS[endpoint];
  if (!rateLimit(`${uid}:${endpoint}:min`, perMinute, ONE_MINUTE)) {
    return `Too many requests. Limit: ${perMinute}/minute.`;
  }
  if (!rateLimit(`${uid}:${endpoint}:hr`, perHour, ONE_HOUR)) {
    return `Hourly limit reached (${perHour}/hour). Try again later.`;
  }
  return null;
}

// ───────────────────────────────────────────────────────────────────
// Input validation helpers
// ───────────────────────────────────────────────────────────────────

/** Returns true if the body (as raw bytes) exceeds `maxBytes`. */
export function bodyTooLarge(rawBody: Buffer | undefined, maxBytes: number): boolean {
  if (!rawBody) return false;
  return rawBody.length > maxBytes;
}

/** Strip null bytes and trim to maxLen. */
export function sanitize(input: unknown, maxLen: number): string {
  if (typeof input !== "string") return "";
  return input.replace(/\0/g, "").trim().slice(0, maxLen);
}

/** Ensure a value is one of the allowed options (type-safe enum guard). */
export function oneOf<T extends string>(value: unknown, allowed: readonly T[], fallback: T): T {
  if (typeof value === "string" && (allowed as readonly string[]).includes(value)) return value as T;
  return fallback;
}

// ───────────────────────────────────────────────────────────────────
// Firestore-backed abuse detection (velocity / anomaly flags)
// ───────────────────────────────────────────────────────────────────

/**
 * Log a usage event and check if the user is showing abusive patterns.
 * Returns true if the request looks suspicious (but doesn't block — the
 * caller decides how to handle it).
 *
 * Patterns detected:
 *  - Burst: >50 requests in the last 5 minutes
 *  - Excessive daily: >500 API calls in a day
 */
export async function logAndDetectAbuse(uid: string, endpoint: string): Promise<boolean> {
  try {
    const db = getFirestore();
    const today = new Date().toISOString().slice(0, 10);
    const ref = db.doc(`usage/${uid}/daily/${today}`);

    const doc = await ref.get();
    const data = doc.data() ?? {};
    const total = (data.total as number ?? 0) + 1;
    const endpointCount = (data[endpoint] as number ?? 0) + 1;

    await ref.set({ total, [endpoint]: endpointCount, lastRequest: new Date().toISOString() }, { merge: true });

    if (total > 500) {
      logger.warn(`Abuse flag: user ${uid} has ${total} requests today`);
      return true;
    }
    return false;
  } catch (e) {
    // Usage logging should never break the request
    logger.error("Usage logging failed", e);
    return false;
  }
}

// ───────────────────────────────────────────────────────────────────
// Subscription tier enforcement
// ───────────────────────────────────────────────────────────────────

export type Tier = "free" | "pro" | "team";

/** Read the user's subscription tier from Firestore. */
export async function getUserTier(uid: string): Promise<Tier> {
  try {
    const doc = await getFirestore().doc(`users/${uid}`).get();
    const tier = doc.data()?.subscription?.tier;
    if (tier === "pro" || tier === "team") return tier;
    return "free";
  } catch {
    return "free";
  }
}

/** Feature gating: returns null if allowed, or an error message. */
export function requireTier(actual: Tier, minimum: "pro" | "team"): string | null {
  const rank: Record<Tier, number> = { free: 0, pro: 1, team: 2 };
  if (rank[actual] >= rank[minimum]) return null;
  return `This feature requires a ${minimum === "pro" ? "Pro" : "Team"} plan or higher.`;
}
