import { api, getAuth, setAuth } from "./api.js";
import { config } from "./config.js";
import { extractPage } from "./extract.js";

chrome.runtime.onInstalled.addListener(async ({ reason }) => {
  await chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true });
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({ id: "save-page", title: "Save page to DSCVR", contexts: ["page"] });
    chrome.contextMenus.create({ id: "ask-selection", title: "Ask Pinda about “%s”", contexts: ["selection"] });
  });
  if (reason === "install") {
    const { appUrl } = await config();
    chrome.tabs.create({ url: `${appUrl}/connect-extension` });
  }
});

// Sign-in token from app.askpinda.com/connect-extension (via connect.js).
chrome.runtime.onMessage.addListener((msg, sender, reply) => {
  if (msg?.type !== "connect") return false;
  (async () => {
    const { appUrl } = await config();
    const from = sender.url ? new URL(sender.url).origin : "";
    const trusted = [new URL(appUrl).origin, "https://app.askpinda.com", "https://dscvr.askpinda.com"].includes(from) ||
      from.startsWith("http://localhost");
    if (!trusted || !/^dx_[\w-]{20,}$/.test(msg.token || "")) return reply({ ok: false });
    try {
      const me = await api.get("/extension/me", { token: msg.token });
      await setAuth({ token: msg.token, email: me.email || "", name: me.name || "" });
      reply({ ok: true });
    } catch {
      reply({ ok: false });
    }
  })();
  return true;
});

async function flash(tabId, text, color) {
  await chrome.action.setBadgeBackgroundColor({ color, tabId });
  await chrome.action.setBadgeText({ text, tabId });
  setTimeout(() => chrome.action.setBadgeText({ text: "", tabId }).catch(() => {}), 4000);
}

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (!tab?.id) return;
  if (info.menuItemId === "ask-selection") {
    await chrome.storage.session.set({ pending: { action: "ask", text: info.selectionText || "", tabId: tab.id, at: Date.now() } });
    await chrome.sidePanel.open({ tabId: tab.id });
    return;
  }
  if (info.menuItemId === "save-page") {
    if (!(await getAuth())) {
      await chrome.sidePanel.open({ tabId: tab.id });
      return;
    }
    try {
      let page;
      try {
        [{ result: page }] = await chrome.scripting.executeScript({ target: { tabId: tab.id }, func: extractPage });
      } catch {
        page = { title: tab.title, url: tab.url, kind: "link" }; // PDFs and pages we can't read
        if (/\.pdf($|\?)/i.test(tab.url || "")) Object.assign(page, { kind: "paper", pdfUrl: tab.url });
      }
      const { lastCategoryId, lastTopicId } = await chrome.storage.local.get(["lastCategoryId", "lastTopicId"]);
      await api.post("/extension/save", { ...page, text: undefined, content: page.kind === "link" ? page.text : "",
        venue: undefined, categoryId: lastCategoryId, topicId: lastTopicId });
      await flash(tab.id, "✓", "#2D7D46");
    } catch {
      await flash(tab.id, "!", "#C2410C");
    }
  }
});
