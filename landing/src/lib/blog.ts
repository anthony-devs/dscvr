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

const DIR = path.join(process.cwd(), "content", "blog");

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
  const words = body.split(/\s+/).length;
  return {
    slug,
    title: meta.title ?? slug,
    description: meta.description ?? "",
    date: meta.date ?? "2026-01-01",
    updated: meta.updated || undefined,
    author: meta.author ?? "The DSCVR team",
    tags: (meta.tags ?? "").replace(/^\[|\]$/g, "").split(",").map((t) => t.trim()).filter(Boolean),
    readingMinutes: Math.max(1, Math.round(words / 230)),
    body,
  };
}

export function allPosts(): Post[] {
  if (!fs.existsSync(DIR)) return [];
  return fs
    .readdirSync(DIR)
    .filter((f) => f.endsWith(".md"))
    .map((f) => parse(f.replace(/\.md$/, ""), fs.readFileSync(path.join(DIR, f), "utf8")))
    .sort((a, b) => b.date.localeCompare(a.date));
}

export function getPost(slug: string): Post | undefined {
  return allPosts().find((p) => p.slug === slug);
}

export function formatDate(d: string) {
  return new Date(d + "T12:00:00Z").toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric" });
}
