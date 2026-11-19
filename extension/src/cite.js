// Citation styles, ported from the app (lib/models/citation.dart) so a page
// cited here matches the same item cited in DSCVR.
export const STYLES = [
  ["apa", "APA 7"],
  ["harvard", "Harvard"],
  ["vancouver", "Vancouver"],
  ["mla", "MLA 9"],
  ["chicago", "Chicago (author-date)"],
  ["oscola", "OSCOLA"],
  ["nigerian", "Nigerian legal"],
];

function parseName(raw) {
  const n = raw.trim().replace(/\s+/g, " ");
  if (n.includes(",")) {
    const [family, ...rest] = n.split(",");
    return { family: family.trim(), given: rest.join(" ").trim().split(" ").filter(Boolean) };
  }
  const words = n.split(" ");
  if (words.length > 1 && /^[A-Z]{1,3}$/.test(words[words.length - 1])) {
    return { family: words.slice(0, -1).join(" "), given: words[words.length - 1].split("") };
  }
  if (words.length === 1) return { family: n, given: [] };
  return { family: words[words.length - 1], given: words.slice(0, -1) };
}
const isOrg = (n) => n.given.length === 0;
const dotted = (n) => n.given.map((g) => `${g[0].toUpperCase()}.`).join(" ");
const tight = (n) => n.given.map((g) => g[0].toUpperCase()).join("");
const givenFull = (n) => n.given.join(" ");
const mlaName = (n) => (isOrg(n) ? n.family : `${n.family}, ${givenFull(n)}`);

function join(parts, and) {
  if (!parts.length) return "";
  if (parts.length === 1) return parts[0];
  const sep = and === "&" ? ", & " : ` ${and} `;
  return `${parts.slice(0, -1).join(", ")}${parts.length > 2 && and !== "&" ? "," : ""}${sep}${parts[parts.length - 1]}`;
}
const sentence = (t) => t.trim().replace(/[.\s]+$/, "");
const clean = (s) => s.replace(/\s+/g, " ").replace(/ \./g, ".").replace(/\.\./g, ".").trim();
const today = () => new Date().toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric" });

/** s: {title, authors, year, venue, url, doi, pmid}. Returns text with *italics* markers. */
export function format(s, style) {
  const names = (s.authors || []).filter((a) => a.trim()).map(parseName);
  const year = s.year ? String(s.year) : "n.d.";
  const title = sentence(s.title || "Untitled");
  const venue = s.venue || null;
  const link = s.doi ? `https://doi.org/${s.doi}` : s.url || null;
  switch (style) {
    case "apa": {
      const a = join(names.slice(0, 20).map((n) => (isOrg(n) ? n.family : `${n.family}, ${dotted(n)}`)), "&");
      return clean(`${a ? a + " " : ""}(${year}). ${title}.${venue ? ` *${venue}*.` : ""}${link ? ` ${link}` : ""}`);
    }
    case "harvard": {
      const a = join(names.slice(0, 3).map((n) => (isOrg(n) ? n.family : `${n.family}, ${dotted(n).replace(/ /g, "")}`)), "and");
      const who = names.length > 3 ? `${names[0].family} et al.` : a;
      return clean(`${who ? who + " " : ""}(${year}) '${title}',${venue ? ` *${venue}*.` : ""}${s.url ? ` Available at: ${link || s.url} (Accessed: ${today()}).` : ""}`);
    }
    case "vancouver": {
      const list = names.slice(0, 6).map((n) => (isOrg(n) ? n.family : `${n.family} ${tight(n)}`));
      const a = list.join(", ") + (names.length > 6 ? ", et al" : "");
      return clean(`${a ? a + ". " : ""}${title}.${venue ? ` ${venue}.` : ""} ${year}.` +
        `${s.doi ? ` doi:${s.doi}` : ""}${s.pmid ? ` PMID: ${s.pmid}.` : ""}${!s.doi && !s.pmid && s.url ? ` Available from: ${s.url}` : ""}`);
    }
    case "mla": {
      const a = !names.length ? "" : names.length === 1 ? mlaName(names[0])
        : names.length === 2 ? `${mlaName(names[0])}, and ${givenFull(names[1])} ${names[1].family}` : `${mlaName(names[0])}, et al`;
      return clean(`${a ? a + ". " : ""}"${title}."${venue ? ` *${venue}*,` : ""} ${year}${link ? `, ${link}` : ""}.`);
    }
    case "chicago": {
      const a = !names.length ? "" : join([mlaName(names[0]), ...names.slice(1, 10).map((n) => (isOrg(n) ? n.family : `${givenFull(n)} ${n.family}`))], "and");
      return clean(`${a ? a + ". " : ""}${year}. "${title}."${venue ? ` *${venue}*.` : ""}${link ? ` ${link}.` : ""}`);
    }
    case "oscola": {
      const a = join(names.slice(0, 3).map((n) => (isOrg(n) ? n.family : `${givenFull(n)} ${n.family}`)), "and") + (names.length > 3 ? " and others" : "");
      return clean(`${a ? a + ", " : ""}'${title}' (${year})${venue ? ` ${venue}` : ""}${link ? ` <${link}> accessed ${today()}` : ""}`);
    }
    case "nigerian": {
      const a = join(names.slice(0, 3).map((n) => (isOrg(n) ? n.family : `${givenFull(n)} ${n.family}`)), "&");
      return clean(`${a ? a + ", " : ""}"${title}"${venue ? ` (${year}) ${venue}` : ` (${year})`}${link ? `, available at ${link}` : ""}`);
    }
  }
  return title;
}

export const plain = (s) => s.replace(/\*/g, "");

export function bibtex(s) {
  const first = s.authors?.length ? parseName(s.authors[0]).family : "anon";
  const key = (first.toLowerCase().replace(/[^a-z]/g, "") + (s.year || "")) || "item";
  const esc = (v) => String(v).replace(/[{}]/g, (c) => "\\" + c);
  const lines = [`@${s.venue ? "article" : "misc"}{${key},`, `  title = {${esc(s.title)}},`];
  if (s.authors?.length) {
    lines.push(`  author = {${s.authors.map((a) => { const n = parseName(a); return isOrg(n) ? `{${esc(n.family)}}` : `${esc(n.family)}, ${esc(givenFull(n))}`; }).join(" and ")}},`);
  }
  if (s.year) lines.push(`  year = {${s.year}},`);
  if (s.venue) lines.push(`  journal = {${esc(s.venue)}},`);
  if (s.doi) lines.push(`  doi = {${s.doi}},`);
  if (s.url) lines.push(`  url = {${s.url}},`);
  lines.push("}");
  return lines.join("\n");
}
