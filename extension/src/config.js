// Where the extension talks to. For local testing you can point it elsewhere
// from the panel's console:  chrome.storage.local.set({serverUrl: "http://localhost:8080"})
export const DEFAULTS = {
  serverUrl: "https://dscvr-server-production.up.railway.app",
  appUrl: "https://app.askpinda.com",
};

export async function config() {
  const o = await chrome.storage.local.get(["serverUrl", "appUrl"]);
  return { serverUrl: o.serverUrl || DEFAULTS.serverUrl, appUrl: o.appUrl || DEFAULTS.appUrl };
}
