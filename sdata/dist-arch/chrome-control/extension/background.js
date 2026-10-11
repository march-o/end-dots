import * as bridgeConfig from './config.js';
import { pageAction } from './page-action.js';
import { scheduleRuntimeReload } from './reload-scheduler.js';

const BRIDGE_TOKEN = bridgeConfig.BRIDGE_TOKEN;
const bridgeProfile = bridgeConfig.BRIDGE_PROFILE || 'personal';
const bridgePort = bridgeConfig.BRIDGE_PORT || 49376;

let socket;
function connect() {
  if (socket && (socket.readyState === WebSocket.CONNECTING || socket.readyState === WebSocket.OPEN)) return;
  const profile = bridgeProfile;
  socket = new WebSocket(`ws://127.0.0.1:${bridgePort}/extension?token=${encodeURIComponent(BRIDGE_TOKEN)}${profile === 'personal' ? '' : `&profile=${encodeURIComponent(profile)}`}`);
  socket.onmessage = async event => {
    let command;
    try { command = JSON.parse(event.data); } catch { return; }
    if (command.action === 'reload') {
      try {
        scheduleRuntimeReload({ id: command.id, send: response => socket.send(JSON.stringify(response)), reload: () => chrome.runtime.reload() });
      } catch (error) {
        socket.send(JSON.stringify({ id: command.id, ok: false, error: String(error.message || error) }));
      }
      return;
    }
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
    case 'fill':
    case 'press': {
      const results = await chrome.scripting.executeScript({
        target: { tabId: command.tabId, allFrames: command.action === 'snapshot' },
        func: pageAction,
        args: [command],
      });
      if (!Array.isArray(results) || results.length === 0) throw new Error('Chrome returned no page execution results');
      return results.map(r => {
        if (r.error) throw new Error(String(r.error.message || r.error));
        if (r.result === null || r.result === undefined) throw new Error(`Page ${command.action} returned no result`);
        return { frameId: r.frameId, result: r.result };
      });
    }
    default: throw new Error(`Unknown action: ${command.action}`);
  }
}
