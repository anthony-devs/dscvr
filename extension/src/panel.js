import { api, ApiError, getAuth, setAuth } from "./api.js";
import { config } from "./config.js";
import { extractPage } from "./extract.js";
import { STYLES, bibtex, format, plain } from "./cite.js";

const $ = (id) => document.getElementById(id);
const ICONS = {
  open: '<svg viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="18" stroke-linecap="round" stroke-linejoin="round"><path d="M216 100V40h-60M144 112l72-72M184 144v64a8 8 0 0 1-8 8H48a8 8 0 0 1-8-8V80a8 8 0 0 1 8-8h64"/></svg>',
  user: '<svg viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="18" stroke-linecap="round"><circle cx="128" cy="96" r="56"/><path d="M32 216c19-33 54-56 96-56s77 23 96 56"/></svg>',
};

const state = {
  auth: null,
  me: null,
  tab: null,
  page: null,
  pdf: null, // {pdfUrl, found}
  chats: new Map(), // url -> [{role, text}]
  streaming: null,
  tabName: "save",
};

// ── Helpers ─────────────────────────────────────────────────────────

function toast(text) {
  const t = $("toast");
  t.textContent = text;
  t.hidden = false;
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => (t.hidden = true), 2200);
}

const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

/** Small, safe Markdown: escapes everything, then adds headings, lists, bold, italics, code and https links. */
function markdown(src) {
  const inline = (s) =>
    esc(s)
      .replace(/`([^`]+)`/g, "<code>$1</code>")
      .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
      .replace(/(^|[^*])\*([^*\n]+)\*/g, "$1<em>$2</em>")
      .replace(/\[([^\]]+)\]\((https:\/\/[^)\s]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>');
  const out = [];
  let list = null;
  const close = () => { if (list) { out.push(`</${list}>`); list = null; } };
  for (const raw of String(src).split("\n")) {
    const line = raw.trimEnd();
    let m;
    if ((m = line.match(/^#{1,4}\s+(.*)/))) { close(); out.push(`<h3>${inline(m[1])}</h3>`); }
    else if ((m = line.match(/^\s*[-*•]\s+(.*)/))) { if (list !== "ul") { close(); out.push("<ul>"); list = "ul"; } out.push(`<li>${inline(m[1])}</li>`); }
    else if ((m = line.match(/^\s*\d+[.)]\s+(.*)/))) { if (list !== "ol") { close(); out.push("<ol>"); list = "ol"; } out.push(`<li>${inline(m[1])}</li>`); }
    else if (!line.trim()) { close(); }
    else { close(); out.push(`<p>${inline(line)}</p>`); }
  }
  close();
  return out.join("");
}

async function openApp(path = "") {
  const { appUrl } = await config();
  chrome.tabs.create({ url: appUrl + path });
}

// ── Auth ────────────────────────────────────────────────────────────

async function render() {
  state.auth = await getAuth();
  $("signedOut").hidden = !!state.auth;
  $("signedIn").hidden = !state.auth;
  $("account").hidden = $("openApp").hidden = !state.auth;
  $("menu").hidden = true;
  if (!state.auth) return;
  $("menuEmail").textContent = state.auth.email ? `Signed in as ${state.auth.email}` : "Signed in";
  await loadLibrary();
  await loadPage();
  await takePending();
}

async function loadLibrary() {
  try {
    state.me = await api.get("/extension/me");
  } catch (e) {
    if (e instanceof ApiError && e.status === 401) return; // storage listener re-renders as signed out
    state.me = state.me || { categories: [], topics: [] };
    showResult(e.message, true);
  }
  const { lastCategoryId, lastTopicId } = await chrome.storage.local.get(["lastCategoryId", "lastTopicId"]);
  const cats = state.me.categories || [];
  $("category").innerHTML = cats.length
    ? cats.map((c) => `<option value="${esc(c.id)}">${esc(c.name)}</option>`).join("")
    : '<option value="">Saved from the web (new)</option>';
  if (cats.some((c) => c.id === lastCategoryId)) $("category").value = lastCategoryId;
  fillTopics(lastTopicId);
}

function fillTopics(selected) {
  const cat = $("category").value;
  const topics = (state.me?.topics || []).filter((t) => t.categoryId === cat);
  $("topic").innerHTML = '<option value="">No topic</option>' +
    topics.map((t) => `<option value="${esc(t.id)}">${esc(t.name)}</option>`).join("");
  if (topics.some((t) => t.id === selected)) $("topic").value = selected;
  $("topic").disabled = !topics.length;
}

// ── The page in the current tab ─────────────────────────────────────

const READ_BLOCKED = /^(chrome|edge|about|devtools|chrome-extension|view-source):|^https:\/\/chromewebstore\.google\.com|^https:\/\/chrome\.google\.com\/webstore/;

async function loadPage() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab) return;
  const sameUrl = state.tab?.url === tab.url;
  state.tab = tab;
  let page = null;
  let notice = "";
  const url = tab.url || "";
  if (READ_BLOCKED.test(url)) {
    notice = "Open a web page or paper to save it or ask Pinda about it.";
  } else {
    try {
      const [res] = await chrome.scripting.executeScript({ target: { tabId: tab.id }, func: extractPage });
      page = res?.result || null;
    } catch {
      if (/\.pdf($|[?#])/i.test(url) || /\/pdf\//i.test(url)) {
        page = { url, title: (tab.title || url.split("/").pop() || "PDF").replace(/\.pdf$/i, ""), kind: "paper",
          pdfUrl: url, authors: [], siteName: new URL(url).hostname.replace(/^www\./, ""), isPdf: true };
        const doi = decodeURIComponent(url).match(/\b(10\.\d{4,9}\/[^\s"'<>?#]+?)(?:\.pdf)?(?:$|[?#])/i);
        if (doi) page.doi = doi[1];
      } else {
        notice = "permission";
        page = { url, title: tab.title || url, kind: "link", authors: [], siteName: safeHost(url) };
      }
    }
  }
  state.page = page;
  if (!sameUrl) state.pdf = null;
  renderPage(notice);
  if (!sameUrl) {
    $("saveResult").hidden = true;
    renderChat();
  }
  await checkPdf();
  renderCite();
}

function safeHost(url) {
  try { return new URL(url).hostname.replace(/^www\./, ""); } catch { return ""; }
}

function renderPage(notice) {
  const p = state.page;
  const kinds = { paper: "Paper", link: "Web page", youtube: "Video" };
  $("pageKind").textContent = p ? (p.isPdf ? "PDF" : kinds[p.kind] || "Web page") : "";
  $("pageTitle").textContent = p ? p.title : "Nothing to read here";
  const authors = p?.authors?.length ? (p.authors.length > 3 ? `${p.authors.slice(0, 3).join(", ")} and others` : p.authors.join(", ")) : "";
  $("pageMeta").textContent = p ? [authors, p.year, p.siteName].filter(Boolean).join(" · ") : "";
  const n = $("pageNotice");
  n.hidden = !notice;
  if (notice === "permission") {
    n.innerHTML = 'DSCVR can only read this page after you click its toolbar button on it, or allow it on all sites. <br><button class="btn" id="allow">Allow on all sites</button>';
    $("allow").onclick = async () => {
      const ok = await chrome.permissions.request({ origins: ["<all_urls>"] });
      if (ok) loadPage();
    };
  } else if (notice) {
    n.textContent = notice;
  }
  const usable = !!p;
  $("save").disabled = !usable;
  $("send").disabled = !usable;
}

// ── Free PDF ────────────────────────────────────────────────────────

async function checkPdf() {
  const box = $("pdfBox");
  const p = state.page;
  box.className = "pdf";
  if (!p || p.kind === "youtube") { box.hidden = true; return; }
  if (p.pdfUrl && !p.isPdf) {
    box.hidden = false;
    box.classList.add("found");
    box.innerHTML = `<strong>PDF available</strong><a href="${esc(p.pdfUrl)}" target="_blank" rel="noopener">Open the PDF</a> · saved with the paper so Pinda can read it in full.`;
    return;
  }
  if (!p.doi || p.isPdf) { box.hidden = true; return; }
  if (state.pdf?.doi === p.doi) return showPdf();
  box.hidden = false;
  box.innerHTML = "<strong>Looking for a free, legal PDF…</strong>";
  try {
    const hit = await api.get(`/pdf/find?doi=${encodeURIComponent(p.doi)}`);
    state.pdf = { doi: p.doi, pdfUrl: hit.pdfUrl, version: hit.version };
  } catch {
    state.pdf = { doi: p.doi, pdfUrl: null };
  }
  if (state.page === p) showPdf();
}

function showPdf() {
  const box = $("pdfBox");
  box.hidden = false;
  if (state.pdf?.pdfUrl) {
    const version = state.pdf.version === "acceptedVersion" ? " (author's accepted version)" : state.pdf.version === "submittedVersion" ? " (preprint)" : "";
    box.classList.add("found");
    box.innerHTML = `<strong>Free PDF found${esc(version)}</strong><a href="${esc(state.pdf.pdfUrl)}" target="_blank" rel="noopener">Open the free PDF</a> · it's added when you save.`;
  } else {
    box.innerHTML = "<strong>No free copy found</strong>This paper doesn't seem to have a legal open-access PDF. Your library may give you access.";
  }
}

// ── Save ────────────────────────────────────────────────────────────

function showResult(html, error = false) {
  const r = $("saveResult");
  r.hidden = false;
  r.className = "result" + (error ? " error" : "");
  r.innerHTML = error ? esc(html) : html;
}

async function save() {
  const p = state.page;
  if (!p) return;
  const btn = $("save");
  btn.disabled = true;
  btn.textContent = "Saving…";
  const categoryId = $("category").value;
  const topicId = $("topic").value;
  await chrome.storage.local.set({ lastCategoryId: categoryId, lastTopicId: topicId });
  try {
    const out = await api.post("/extension/save", {
      title: p.title, url: p.url, kind: p.kind, authors: p.authors, year: p.year, doi: p.doi,
      pdfUrl: p.pdfUrl || state.pdf?.pdfUrl || null, siteName: p.siteName, summary: p.summary,
      source: p.source, externalId: p.externalId, thumbnailUrl: p.thumbnailUrl,
      content: p.kind === "link" ? p.text : "", categoryId, topicId, readingList: $("readingList").checked,
    });
    showResult(`${out.existing ? "Already in your library." : "Saved to your library."} <a href="${esc(out.open)}" target="_blank" rel="noopener">Open in DSCVR</a>`);
    if (!out.existing && !(state.me?.categories || []).length) loadLibrary();
  } catch (e) {
    showResult(e.message, true);
  } finally {
    btn.disabled = false;
    btn.textContent = "Save to DSCVR";
  }
}

// ── Ask Pinda ───────────────────────────────────────────────────────

function history() {
  const key = state.page?.url || "";
  if (!state.chats.has(key)) state.chats.set(key, []);
  return state.chats.get(key);
}

function renderChat() {
  const chat = $("chat");
  chat.querySelectorAll(".msg").forEach((n) => n.remove());
  const msgs = history();
  for (const m of msgs) chat.appendChild(bubble(m));
  const chips = $("chips");
  chips.hidden = msgs.length > 0;
  const p = state.page;
  const prompts = !p ? [] : p.kind === "youtube"
    ? ["Summarise this video", "What are the key points?"]
    : p.kind === "paper"
      ? ["Summarise this paper", "What are the methods and key findings?", "What are the limitations?", "Explain it simply"]
      : ["Summarise this page", "What are the main claims?", "Is this a reliable source?"];
  if (p?.selection) prompts.unshift("Explain the highlighted text");
  chips.innerHTML = prompts.map((q) => `<button class="chip" type="button">${esc(q)}</button>`).join("");
  chips.querySelectorAll(".chip").forEach((b) => (b.onclick = () => ask(b.textContent)));
}

function bubble(m) {
  const d = document.createElement("div");
  d.className = `msg ${m.role === "user" ? "user" : m.error ? "error" : "pinda"}`;
  if (m.role === "user") d.textContent = m.text;
  else d.innerHTML = m.error ? m.html : markdown(m.text);
  return d;
}

async function ask(question) {
  const q = (question || "").trim();
  if (!q || state.streaming || !state.page) return;
  const p = state.page;
  try { // pick up text highlighted since the panel last read the page
    const [r] = await chrome.scripting.executeScript({ target: { tabId: state.tab.id }, func: () => String(getSelection() || "") });
    if (r?.result?.trim()) p.selection = r.result.trim().slice(0, 8000);
  } catch {}
  const msgs = history();
  msgs.push({ role: "user", text: q });
  const answer = { role: "assistant", text: "" };
  renderChat();
  const chat = $("chat");
  const live = bubble(answer);
  live.classList.add("typing");
  chat.appendChild(live);
  live.scrollIntoView({ block: "end" });
  $("question").value = "";
  const ctrl = new AbortController();
  state.streaming = ctrl;
  $("send").disabled = true;
  try {
    await api.stream("/pinda", {
      style: "concise",
      context: { scope: "page", page: { title: p.title, url: p.url, text: p.text || p.summary || "", selection: p.selection || "",
        pdfUrl: p.isPdf ? p.pdfUrl : null } },
      messages: msgs.filter((m) => !m.error).map((m) => ({ role: m.role, text: m.text })),
    }, (delta) => {
      answer.text += delta;
      live.innerHTML = markdown(answer.text);
      live.scrollIntoView({ block: "end" });
    }, ctrl.signal);
    live.classList.remove("typing");
    msgs.push(answer);
  } catch (e) {
    live.remove();
    msgs.pop(); // drop the question so it can be asked again
    const { appUrl } = await config();
    const limit = e instanceof ApiError && e.status === 429 && e.body?.code === "usage_limit";
    const html = esc(e.message) + (limit ? ` <a href="${esc(appUrl)}/plans" target="_blank" rel="noopener">See plans</a>` : "");
    chat.appendChild(bubble({ role: "assistant", error: true, html }));
  } finally {
    state.streaming = null;
    $("send").disabled = !state.page;
  }
}

// ── Cite ────────────────────────────────────────────────────────────

function citeSource() {
  const p = state.page || {};
  return { title: p.title || "", authors: p.kind === "youtube" ? [] : p.authors || [], year: p.year, venue: p.kind === "paper" ? p.siteName : null,
    url: p.url, doi: p.doi || null, pmid: p.pmid || null };
}

function renderCite() {
  const s = citeSource();
  const text = format(s, $("style").value);
  $("citation").innerHTML = esc(text).replace(/\*([^*]+)\*/g, "<em>$1</em>");
  $("citeHint").textContent = !state.page ? "" : s.authors.length && s.year ? "Check the details against the source before you submit."
    : "Some details (authors or year) weren't on this page. Add them by hand before you submit.";
}

async function copy(text, label) {
  await navigator.clipboard.writeText(text);
  toast(label);
}

// ── Pending actions from the right-click menu ───────────────────────

async function takePending() {
  const { pending } = await chrome.storage.session.get("pending");
  if (!pending || Date.now() - pending.at > 60_000 || pending.tabId !== state.tab?.id) return;
  await chrome.storage.session.remove("pending");
  if (pending.action === "ask" && pending.text) {
    if (state.page) state.page.selection = pending.text;
    switchTab("ask");
    ask(`Explain this: "${pending.text.slice(0, 600)}"`);
  }
}

// ── Wiring ──────────────────────────────────────────────────────────

function switchTab(name) {
  state.tabName = name;
  document.querySelectorAll(".tab").forEach((t) => t.classList.toggle("active", t.dataset.tab === name));
  for (const n of ["save", "ask", "cite"]) $(`pane-${n}`).hidden = n !== name;
  if (name === "ask") $("question").focus();
}

function init() {
  $("openApp").innerHTML = ICONS.open;
  $("account").innerHTML = ICONS.user;
  $("style").innerHTML = STYLES.map(([v, l]) => `<option value="${v}">${esc(l)}</option>`).join("");
  chrome.storage.local.get("citeStyle").then(({ citeStyle }) => { if (citeStyle) { $("style").value = citeStyle; renderCite(); } });

  $("connect").onclick = () => openApp("/connect-extension");
  $("openApp").onclick = () => openApp("/recent");
  $("account").onclick = (e) => { e.stopPropagation(); $("menu").hidden = !$("menu").hidden; };
  document.addEventListener("click", (e) => { if (!$("menu").contains(e.target)) $("menu").hidden = true; });
  $("signOut").onclick = async () => {
    try { await api.post("/extension/signout"); } catch {}
    await setAuth(null);
  };
  document.querySelectorAll(".tab").forEach((t) => (t.onclick = () => switchTab(t.dataset.tab)));
  $("category").onchange = () => fillTopics();
  $("save").onclick = save;
  $("askForm").onsubmit = (e) => { e.preventDefault(); ask($("question").value); };
  $("question").addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); ask($("question").value); }
  });
  $("question").addEventListener("input", (e) => { e.target.style.height = "auto"; e.target.style.height = `${e.target.scrollHeight}px`; });
  $("style").onchange = () => { chrome.storage.local.set({ citeStyle: $("style").value }); renderCite(); };
  $("copyCite").onclick = () => copy(plain(format(citeSource(), $("style").value)), "Citation copied");
  $("copyBib").onclick = () => copy(bibtex(citeSource()), "BibTeX copied");

  chrome.storage.onChanged.addListener((changes, area) => {
    if (area === "local" && "token" in changes) render();
    if (area === "session" && changes.pending?.newValue) takePending();
  });
  let t;
  const refresh = () => { clearTimeout(t); t = setTimeout(() => state.auth && loadPage(), 250); };
  chrome.tabs.onActivated.addListener(refresh);
  chrome.tabs.onUpdated.addListener((id, info) => { if (id === state.tab?.id && (info.status === "complete" || info.url)) refresh(); });
  render();
}

init();
