import * as bridgeConfig from './config.js';
import { pageAction } from './page-action.js';
import { scheduleRuntimeReload } from './reload-scheduler.js';

const bridgeProfile = bridgeConfig.BRIDGE_PROFILE || 'personal';
const bridgePort = bridgeConfig.BRIDGE_PORT || 49376;
let socket;
function connect() {
  if (socket && (socket.readyState === WebSocket.CONNECTING || socket.readyState === WebSocket.OPEN)) return;
  socket = new WebSocket(`ws://127.0.0.1:${bridgePort}/extension?token=${encodeURIComponent(bridgeConfig.BRIDGE_TOKEN)}${bridgeProfile === 'personal' ? '' : `&profile=${encodeURIComponent(bridgeProfile)}`}`);
  const connection = socket;
  connection.onopen = () => connection.send(JSON.stringify({ id: 'handshake', action: 'handshake', protocol: 'chrome-control', protocolVersion: 2, implementationVersion: '1.2.0', capabilities: ['profiles', 'status', 'list', 'open', 'navigate', 'close_tab', 'snapshot', 'click', 'fill', 'press', 'reload', 'verified-page-outcomes', 'frame-targeting', 'pointer-sequence'] }));
  connection.onmessage = async event => {
    let command;
    try { command = JSON.parse(event.data); } catch { return; }
    if (command.id === 'handshake' && command.ok === true) return;
    if (command.action === 'reload') {
      try { scheduleRuntimeReload({ id: command.id, send: response => connection.send(JSON.stringify(response)), reload: () => chrome.runtime.reload() }); }
      catch (error) { connection.send(JSON.stringify({ id: command.id, ok: false, error: String(error.message || error) })); }
      return;
    }
    try { connection.send(JSON.stringify({ id: command.id, ok: true, result: await run(command) })); }
    catch (error) {
      connection.send(JSON.stringify({ id: command.id, ok: false, error: String(error.message || error), code: error.code || 'PAGE_EXCEPTION', uncertain: error.uncertain === true || ['click', 'fill', 'press'].includes(command.action) }));
    }
  };
  connection.onclose = () => { if (socket === connection) socket = undefined; setTimeout(connect, 1000); };
  connection.onerror = () => {};
}
chrome.runtime.onStartup.addListener(connect);
chrome.runtime.onInstalled.addListener(connect);
chrome.alarms.create('bridge-reconnect', { periodInMinutes: 0.5 });
chrome.alarms.onAlarm.addListener(connect);
connect();

async function run(command) {
  switch (command.action) {
    case 'ping': return { alive: true, protocol: 'chrome-control', protocolVersion: 2, implementationVersion: '1.2.0', capabilities: ['profiles', 'status', 'list', 'open', 'navigate', 'close_tab', 'snapshot', 'click', 'fill', 'press', 'reload', 'verified-page-outcomes', 'frame-targeting', 'pointer-sequence'] };
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
    case 'close_tab': await chrome.tabs.remove(command.tabId); return { tabId: command.tabId };
    case 'snapshot':
    case 'click':
    case 'fill':
    case 'press': {
      if (command.frameId !== undefined && (!Number.isInteger(command.frameId) || command.frameId < 0)) throw new Error('Invalid frameId');
      if (command.allFrames !== undefined && typeof command.allFrames !== 'boolean') throw new Error('Invalid allFrames');
      if (command.allFrames === true && command.action !== 'snapshot') throw new Error('Mutations require a single frame');
      if (command.allFrames === true && command.frameId !== undefined) throw new Error('Cannot combine frameId and allFrames');
      const target = command.action === 'snapshot' && command.allFrames === true
        ? { tabId: command.tabId, allFrames: true }
        : { tabId: command.tabId, frameIds: [command.frameId ?? 0] };
      const results = await chrome.scripting.executeScript({ target, func: pageAction, args: [command] });
      if (!Array.isArray(results) || results.length === 0) throw new Error('Chrome returned no page execution results');
      return results.map(r => {
        if (r.error) throw new Error(String(r.error.message || r.error));
        if (r.result === null || r.result === undefined) throw new Error(`Page ${command.action} returned no result`);
        return { frameId: r.frameId, documentId: r.documentId, result: r.result };
      });
    }
    default: throw new Error(`Unknown action: ${command.action}`);
  }
}
