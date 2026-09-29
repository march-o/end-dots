import { BRIDGE_TOKEN } from './config.js';

let socket;
function connect() {
  if (socket && (socket.readyState === WebSocket.CONNECTING || socket.readyState === WebSocket.OPEN)) return;
  socket = new WebSocket(`ws://127.0.0.1:49376/extension?token=${encodeURIComponent(BRIDGE_TOKEN)}`);
  socket.onmessage = async event => {
    let command;
    try { command = JSON.parse(event.data); } catch { return; }
    try {
      const result = await run(command);
      socket.send(JSON.stringify({ id: command.id, ok: true, result }));
    } catch (error) {
      socket.send(JSON.stringify({ id: command.id, ok: false, error: String(error.message || error) }));
    }
  };
  socket.onclose = () => { socket = undefined; setTimeout(connect, 1000); };
  socket.onerror = () => {};
}
chrome.runtime.onStartup.addListener(connect);
chrome.runtime.onInstalled.addListener(connect);
chrome.alarms.create('bridge-reconnect', { periodInMinutes: 0.5 });
chrome.alarms.onAlarm.addListener(connect);
connect();

async function run(command) {
  switch (command.action) {
    case 'ping': return { alive: true };
    case 'list': {
      const windows = await chrome.windows.getAll({ populate: true });
      return windows.map(w => ({ id: w.id, focused: w.focused, tabs: (w.tabs || []).map(t => ({ id: t.id, title: t.title, url: t.url, active: t.active })) }));
    }
    case 'open': {
      if (!/^https?:\/\//.test(command.url || '')) throw new Error('Open requires an HTTP(S) URL');
      const w = await chrome.windows.create({ url: command.url, focused: false, type: 'normal' });
      return { windowId: w.id, tabId: w.tabs?.[0]?.id };
    }
    case 'navigate': {
      const tab = await chrome.tabs.update(command.tabId, { url: command.url });
      return { tabId: tab.id, url: tab.url };
    }
    case 'close_tab': {
      await chrome.tabs.remove(command.tabId);
      return { tabId: command.tabId };
    }
    case 'snapshot':
    case 'click':
    case 'fill': {
      const results = await chrome.scripting.executeScript({
        target: { tabId: command.tabId, allFrames: command.action === 'snapshot' },
        func: pageAction,
        args: [command],
      });
      return results.map(r => ({ frameId: r.frameId, result: r.result }));
    }
    default: throw new Error(`Unknown action: ${command.action}`);
  }
}

function pageAction(command) {
  if (command.action === 'snapshot') {
    const elements = [...document.querySelectorAll('a,button,input,textarea,select,[role="button"],[role="link"]')]
      .slice(0, 500).map((el, index) => ({
        index,
        tag: el.tagName.toLowerCase(),
        role: el.getAttribute('role') || undefined,
        text: (el.innerText || el.getAttribute('aria-label') || el.getAttribute('placeholder') || '').trim().slice(0, 180),
        selector: el.id ? `#${CSS.escape(el.id)}` : el.getAttribute('data-testid') ? `[data-testid="${CSS.escape(el.getAttribute('data-testid'))}"]` : undefined,
        href: el.getAttribute('href') || undefined,
        type: el.getAttribute('type') || undefined,
      }));
    return { url: location.href, title: document.title, text: (document.body?.innerText || '').slice(0, command.maxText || 30000), elements };
  }
  const el = command.selector ? document.querySelector(command.selector) : undefined;
  if (!el) throw new Error('Element not found; provide a CSS selector from the current page');
  if (command.action === 'click') { el.click(); return { clicked: command.selector }; }
  if (command.action === 'fill') {
    if (!('value' in el)) throw new Error('Element is not fillable');
    const setter = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(el), 'value')?.set;
    if (setter) setter.call(el, command.value); else el.value = command.value;
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
    return { filled: command.selector };
  }
}
