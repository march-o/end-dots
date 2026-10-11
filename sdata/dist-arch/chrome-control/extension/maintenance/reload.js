(() => {
  if (window.__chromeControlReloadScheduled) return;
  window.__chromeControlReloadScheduled = true;
  window.setTimeout(() => chrome.runtime.reload(), 700);
})();
