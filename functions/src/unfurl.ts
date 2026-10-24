import { Readability } from "@mozilla/readability";
import { parseHTML } from "linkedom";
import { safeFetch } from "./net";

export interface Unfurled {
  title?: string;
  description?: string;
  siteName?: string;
  image?: string;
  authors: string[];
  year?: number;
  text: string;
  isPdf: boolean;
}

const MAX_TEXT = 60000;

function youtubeId(raw: string): string | null {
  try {
    const u = new URL(raw);
    if (u.hostname.includes("youtu.be")) return u.pathname.split("/")[1] || null;
    if (u.hostname.includes("youtube.com")) {
      if (u.searchParams.get("v")) return u.searchParams.get("v");
      const seg = u.pathname.split("/").filter(Boolean);
      const i = seg.findIndex((s) => ["shorts", "embed", "live"].includes(s));
      if (i >= 0 && seg[i + 1]) return seg[i + 1];
    }
  } catch {
    // not a URL
  }
  return null;
}

async function unfurlYouTube(id: string): Promise<Unfurled> {
  const oembed = `https://www.youtube.com/oembed?format=json&url=${encodeURIComponent(
    `https://www.youtube.com/watch?v=${id}`
  )}`;
  try {
    const res = await fetch(oembed, { signal: AbortSignal.timeout(8000) });
    if (res.ok) {
      const data = (await res.json()) as { title?: string; author_name?: string; thumbnail_url?: string };
      return {
        title: data.title,
        siteName: "YouTube",
        image: data.thumbnail_url ?? `https://i.ytimg.com/vi/${id}/hqdefault.jpg`,
        authors: data.author_name ? [data.author_name] : [],
        text: "",
        isPdf: false,
      };
    }
  } catch {
    // fall through
  }
  return { title: "YouTube video", siteName: "YouTube", image: `https://i.ytimg.com/vi/${id}/hqdefault.jpg`, authors: [], text: "", isPdf: false };
}

/** Turns Readability's cleaned HTML into lightweight markdown. */
function htmlToMarkdown(html: string): string {
  const { document } = parseHTML(`<!doctype html><html><body>${html}</body></html>`);
  const out: string[] = [];
  const clean = (s: string | null) => (s ?? "").replace(/\s+/g, " ").trim();
  document.querySelectorAll("h1, h2, h3, h4, p, li, blockquote, pre").forEach((el: Element) => {
    const tag = el.tagName.toLowerCase();
    if (tag !== "pre" && el.closest("pre")) return;
    if ((tag === "p" || tag === "li") && el.closest("blockquote")) return;
    const text = tag === "pre" ? (el.textContent ?? "").trimEnd() : clean(el.textContent);
    if (!text) return;
    switch (tag) {
      case "h1":
      case "h2":
        out.push(`## ${text}`);
        break;
      case "h3":
      case "h4":
        out.push(`### ${text}`);
        break;
      case "li":
        out.push(`- ${text}`);
        break;
      case "blockquote":
        out.push(`> ${text}`);
        break;
      case "pre":
        out.push("```\n" + text + "\n```");
        break;
      default:
        out.push(text);
    }
  });
  return out.join("\n\n").replace(/\n(- [^\n]+)\n\n(?=- )/g, "\n$1\n").slice(0, MAX_TEXT);
}

export async function unfurl(rawUrl: string): Promise<Unfurled> {
  const yt = youtubeId(rawUrl);
  if (yt) return unfurlYouTube(yt);

  const res = await safeFetch(rawUrl, { maxBytes: 8 * 1024 * 1024 });
  const finalUrl = new URL(res.url);

  if (res.contentType.includes("pdf") || finalUrl.pathname.toLowerCase().endsWith(".pdf")) {
    const name = decodeURIComponent(finalUrl.pathname.split("/").pop() ?? "Document").replace(/\.pdf$/i, "");
    return { title: name.replace(/[_-]+/g, " "), siteName: finalUrl.hostname.replace(/^www\./, ""), authors: [], text: "", isPdf: true };
  }

  const html = res.bytes.toString("utf8");
  const { document } = parseHTML(html);
  const meta = (key: string): string | undefined => {
    const el =
      document.querySelector(`meta[property="${key}"]`) ?? document.querySelector(`meta[name="${key}"]`);
    const v = el?.getAttribute("content")?.trim();
    return v ? v : undefined;
  };

  const authors = Array.from(
    new Set(
      Array.from(document.querySelectorAll('meta[name="citation_author"], meta[name="author"]'))
        .map((e: Element) => e.getAttribute("content")?.trim() ?? "")
        .filter(Boolean)
    )
  ).slice(0, 30);
  const dateStr = meta("citation_publication_date") ?? meta("article:published_time") ?? meta("citation_date");
  const yearMatch = dateStr?.match(/(19|20)\d{2}/);

  let text = "";
  let readableTitle: string | undefined;
  try {
    // Readability mutates the document, so it runs on its own copy.
    const article = new Readability(parseHTML(html).document as unknown as Document).parse();
    if (article?.content) text = htmlToMarkdown(article.content);
    readableTitle = article?.title ?? undefined;
  } catch {
    text = "";
  }

  const image = meta("og:image");
  return {
    title: meta("citation_title") ?? meta("og:title") ?? readableTitle ?? document.querySelector("title")?.textContent?.trim(),
    description: meta("og:description") ?? meta("description"),
    siteName: meta("og:site_name") ?? finalUrl.hostname.replace(/^www\./, ""),
    image: image ? new URL(image, finalUrl).toString() : undefined,
    authors,
    year: yearMatch ? Number(yearMatch[0]) : undefined,
    text,
    isPdf: false,
  };
}
