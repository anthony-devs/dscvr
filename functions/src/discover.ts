import { XMLParser } from "fast-xml-parser";

export interface Paper {
  id: string;
  title: string;
  source: "arxiv" | "semantic_scholar";
  authors: string[];
  year?: number;
  summary: string;
  url?: string;
  pdfUrl?: string;
  venue?: string;
  citations?: number;
  subjects: string[];
}

const clean = (s: unknown) => String(s ?? "").replace(/\s+/g, " ").trim();
const asArray = <T>(v: T | T[] | undefined): T[] => (v === undefined ? [] : Array.isArray(v) ? v : [v]);

export async function searchArxiv(query: string, sort: "relevance" | "date", limit: number): Promise<Paper[]> {
  const params = new URLSearchParams({
    search_query: query,
    start: "0",
    max_results: String(limit),
    sortBy: sort === "date" ? "submittedDate" : "relevance",
    sortOrder: "descending",
  });
  const res = await fetch(`https://export.arxiv.org/api/query?${params}`, {
    signal: AbortSignal.timeout(15000),
    headers: { "User-Agent": "DSCVR/1.0 (research library)" },
  });
  if (!res.ok) throw new Error(`arXiv responded ${res.status}`);
  const xml = await res.text();
  const parser = new XMLParser({ ignoreAttributes: false, attributeNamePrefix: "" });
  const feed = parser.parse(xml)?.feed;
  type Entry = {
    id: string;
    title: string;
    summary: string;
    published?: string;
    author?: { name: string } | { name: string }[];
    link?: { href: string; title?: string } | { href: string; title?: string }[];
    category?: { term: string } | { term: string }[];
  };
  return asArray<Entry>(feed?.entry).map((e) => {
    const id = String(e.id ?? "");
    const pdf = asArray(e.link).find((l) => l.title === "pdf")?.href;
    return {
      id: id.split("/abs/").pop() ?? id,
      title: clean(e.title),
      source: "arxiv",
      authors: asArray(e.author).map((a) => clean(a.name)),
      year: e.published ? Number(String(e.published).slice(0, 4)) : undefined,
      summary: clean(e.summary),
      url: id.replace("http://", "https://"),
      pdfUrl: pdf?.replace("http://", "https://"),
      subjects: asArray(e.category).map((c) => c.term),
    };
  });
}

export async function searchSemanticScholar(query: string, limit: number, apiKey?: string): Promise<Paper[]> {
  const params = new URLSearchParams({
    query,
    limit: String(limit),
    fields: "title,authors,year,abstract,url,openAccessPdf,venue,citationCount,externalIds",
  });
  const res = await fetch(`https://api.semanticscholar.org/graph/v1/paper/search?${params}`, {
    signal: AbortSignal.timeout(15000),
    headers: apiKey ? { "x-api-key": apiKey } : {},
  });
  if (!res.ok) throw new Error(`Semantic Scholar responded ${res.status}`);
  type S2 = {
    paperId: string;
    title?: string;
    abstract?: string;
    year?: number;
    url?: string;
    venue?: string;
    citationCount?: number;
    authors?: { name?: string }[];
    openAccessPdf?: { url?: string } | null;
  };
  const data = (await res.json()) as { data?: S2[] };
  return (data.data ?? []).map((p) => ({
    id: p.paperId,
    title: clean(p.title),
    source: "semantic_scholar",
    authors: (p.authors ?? []).map((a) => clean(a.name)).filter(Boolean),
    year: p.year ?? undefined,
    summary: clean(p.abstract),
    url: p.url,
    pdfUrl: p.openAccessPdf?.url || undefined,
    venue: p.venue || undefined,
    citations: p.citationCount ?? undefined,
    subjects: [],
  }));
}
