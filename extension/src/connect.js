// Runs on app.askpinda.com. Tells the web app the extension is installed and
// passes the sign-in token from /connect-extension to the extension.
(() => {
  document.documentElement.setAttribute("data-dscvr-extension", chrome.runtime.getManifest().version);
  window.addEventListener("message", (e) => {
    if (e.source !== window || e.origin !== location.origin) return;
    const d = e.data;
    if (!d || d.type !== "dscvr-extension-token" || typeof d.token !== "string") return;
    chrome.runtime.sendMessage({ type: "connect", token: d.token }, (res) => {
      window.postMessage({ type: "dscvr-extension-connected", ok: !!(res && res.ok) }, location.origin);
    });
  });
})();
