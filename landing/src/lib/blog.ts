import fs from "node:fs";
import path from "node:path";

export type Post = {
  slug: string;
  title: string;
  description: string;
  date: string;
  updated?: string;
  author: string;
  tags: string[];
  readingMinutes: number;
  body: string;
};

type Meta = Omit<Post, "body" | "readingMinutes"> & { readingMinutes?: number };

const DIR = path.join(process.cwd(), "content", "blog");
/** Posts written in the admin console come from the DSCVR server. */
const API = (process.env.BLOG_API_URL || "https://dscvr-server-production.up.railway.app").replace(/\/+$/, "");
export const BLOG_REVALIDATE = 300;

function minutes(body: string) {
  return Math.max(1, Math.round(body.split(/\s+/).length / 230));
}

/** Reads "key: value" front matter between --- lines. Lists are written [a, b]. */
function parse(slug: string, raw: string): Post {
  const m = /^---\n([\s\S]*?)\n---\n?([\s\S]*)$/.exec(raw.replace(/\r\n/g, "\n"));
  if (!m) throw new Error(`Post ${slug} has no front matter`);
  const meta: Record<string, string> = {};
  for (const line of m[1].split("\n")) {
    const kv = /^(\w+):\s*(.*)$/.exec(line);
    if (kv) meta[kv[1]] = kv[2].trim().replace(/^"(.*)"$/, "$1");
  }
  const body = m[2].trim();
  return {
    slug,
    title: meta.title ?? slug,
    description: meta.description ?? "",
    date: meta.date ?? "2026-01-01",
    updated: meta.updated || undefined,
    author: meta.author ?? "The DSCVR team",
    tags: (meta.tags ?? "").replace(/^\[|\]$/g, "").split(",").map((t) => t.trim()).filter(Boolean),
    readingMinutes: minutes(body),
    body,
  };
}

function filePosts(): Post[] {
  if (!fs.existsSync(DIR)) return [];
  return fs
    .readdirSync(DIR)
    .filter((f) => f.endsWith(".md"))
    .map((f) => parse(f.replace(/\.md$/, ""), fs.readFileSync(path.join(DIR, f), "utf8")));
}

async function api<T>(p: string): Promise<T | null> {
  try {
    const res = await fetch(`${API}${p}`, { next: { revalidate: BLOG_REVALIDATE, tags: ["blog"] }, signal: AbortSignal.timeout(6000) });
    return res.ok ? ((await res.json()) as T) : null;
  } catch {
    return null;
  }
}

/** Every published post: files in the repo plus posts from the console. A console post with the same slug wins. */
export async function allPosts(): Promise<Meta[]> {
  const bySlug = new Map<string, Meta>();
  for (const p of filePosts()) {
    const { body, ...meta } = p;
    bySlug.set(p.slug, { ...meta, readingMinutes: minutes(body) });
  }
  const remote = await api<{ posts: Meta[] }>("/blog/posts");
  for (const p of remote?.posts ?? []) bySlug.set(p.slug, { ...p, updated: p.updated || undefined });
  return Array.from(bySlug.values()).sort((a, b) => b.date.localeCompare(a.date));
}

export async function getPost(slug: string): Promise<Post | undefined> {
  if (!/^[a-z0-9-]{1,100}$/.test(slug)) return undefined;
  const remote = await api<Post>(`/blog/posts/${slug}`);
  if (remote?.body) return { ...remote, updated: remote.updated || undefined, readingMinutes: minutes(remote.body) };
  return filePosts().find((p) => p.slug === slug);
}

export function formatDate(d: string) {
  return new Date(d.slice(0, 10) + "T12:00:00Z").toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric" });
}
