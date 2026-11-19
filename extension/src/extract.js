// Injected into the page (chrome.scripting.executeScript). Must be
// self-contained: it can't use anything from the extension's own modules.
export function extractPage() {
  const meta = (name) =>
    Array.from(document.querySelectorAll(`meta[name="${name}" i], meta[property="${name}" i]`))
      .map((m) => (m.getAttribute("content") || "").trim())
      .filter(Boolean);
  const first = (...names) => {
    for (const n of names) {
      const v = meta(n)[0];
      if (v) return v;
    }
    return "";
  };
  const clean = (s) => (s || "").replace(/\s+/g, " ").trim();
  const url = location.href.split("#")[0];
  const host = location.hostname.replace(/^www\./, "");

  const out = {
    url,
    title: clean(first("citation_title", "dc.title", "DC.title", "og:title", "twitter:title")) || clean(document.title),
    authors: [],
    year: null,
    doi: "",
    pdfUrl: "",
    siteName: clean(first("citation_journal_title", "citation_conference_title", "og:site_name")) || host,
    summary: clean(first("citation_abstract", "dc.description", "description", "og:description")).slice(0, 4000),
    kind: "link",
    source: null,
    externalId: null,
    pmid: "",
    thumbnailUrl: first("og:image") || null,
    text: "",
    selection: clean(String(window.getSelection() || "")).slice(0, 8000),
    scholarly: false,
  };

  const authors = meta("citation_author");
  out.authors = (authors.length ? authors : meta("dc.creator").concat(meta("DC.creator"))).map(clean).slice(0, 40);
  if (!out.authors.length) {
    const a = first("author", "article:author");
    if (a && !/^https?:/.test(a)) out.authors = [clean(a)];
  }
  const date = first("citation_publication_date", "citation_date", "citation_online_date", "dc.date", "DC.date",
    "prism.publicationDate", "article:published_time");
  const y = date.match(/\b(1[4-9]\d\d|20\d\d)\b/);
  out.year = y ? Number(y[1]) : null;

  const doiRe = /\b(10\.\d{4,9}\/[^\s"'<>?#]+)/i;
  const doiMeta = [first("citation_doi", "prism.doi", "dc.identifier", "DC.identifier", "bepress_citation_doi")].find((v) => doiRe.test(v));
  const doiMatch = (doiMeta || decodeURIComponent(url)).match(doiRe);
  out.doi = doiMatch ? doiMatch[1].replace(/[.,;)]+$/, "") : "";
  out.pdfUrl = first("citation_pdf_url", "bepress_citation_pdf_url", "eprints.document_url");
  out.pmid = first("citation_pmid");

  // Known sites.
  const arxiv = url.match(/arxiv\.org\/(?:abs|pdf|html)\/([\w.\-\/]+?)(?:v\d+)?(?:\.pdf)?$/i);
  if (arxiv) {
    out.source = "arxiv";
    out.externalId = arxiv[1];
    out.pdfUrl = out.pdfUrl || `https://arxiv.org/pdf/${arxiv[1]}`;
    out.siteName = "arXiv";
  }
  const pubmed = url.match(/pubmed\.ncbi\.nlm\.nih\.gov\/(\d+)/);
  if (pubmed) out.pmid = out.pmid || pubmed[1];
  const yt = location.hostname.endsWith("youtube.com") && new URLSearchParams(location.search).get("v");
  const ytShort = location.hostname === "youtu.be" && location.pathname.slice(1);
  const video = yt || ytShort;
  if (video) {
    out.kind = "youtube";
    out.title = clean(document.title.replace(/\s*-\s*YouTube\s*$/, "")) || out.title;
    out.thumbnailUrl = `https://i.ytimg.com/vi/${video}/hqdefault.jpg`;
    out.siteName = "YouTube";
    const channel = document.querySelector("#owner #channel-name a, ytd-channel-name a");
    if (channel) out.authors = [clean(channel.textContent)];
    out.summary = clean(first("og:description", "description")).slice(0, 4000);
  }

  out.scholarly = !!(meta("citation_title").length || out.doi || out.source === "arxiv" || out.pmid);
  if (!video && out.scholarly) out.kind = "paper";

  // Readable text for Pinda: the article if there is one, else the page.
  const root = document.querySelector("article, main, [role=main], #content, .content") || document.body;
  if (root) {
    out.text = (root.innerText || root.textContent || "").replace(/\n{3,}/g, "\n\n").replace(/[ \t]{2,}/g, " ").trim().slice(0, 60000);
    if (out.text.length < 400 && root !== document.body) {
      out.text = (document.body.innerText || "").trim().slice(0, 60000);
    }
  }
  return out;
}
