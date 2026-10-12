import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { WebSocketServer } from 'ws';
import { normalizePageResponse } from './normalize-page-response.mjs';

const sourceDir = path.dirname(fileURLToPath(import.meta.url));
const profiles = ['personal', 'work'];
const MAX_MESSAGE = 64 * 1024;
const MAX_WS_MESSAGE = 4 * 1024 * 1024;
const ACTIONS = new Set(['status', 'list', 'open', 'navigate', 'close_tab', 'snapshot', 'click', 'fill', 'press', 'reload']);

export function startChromeControl({ runtimeDir = path.join(os.homedir(), '.local', 'share', 'end-dots-martins'), port = 49376, packageDir = sourceDir, actionTimeoutMs = 30000, requestTimeoutMs = 10000 } = {}) {
  fs.mkdirSync(runtimeDir, { recursive: true, mode: 0o700 });
  const socketPaths = { personal: path.join(runtimeDir, 'chrome-control.sock'), work: path.join(runtimeDir, 'chrome-control-work.sock') };
  const tokens = Object.fromEntries(profiles.map(profile => {
    const tokenPath = path.join(runtimeDir, profile === 'personal' ? 'chrome-control-token' : 'chrome-control-work-token');
    if (!fs.existsSync(tokenPath)) fs.writeFileSync(tokenPath, crypto.randomBytes(32).toString('hex'), { mode: 0o600 });
    fs.chmodSync(tokenPath, 0o600);
    return [profile, fs.readFileSync(tokenPath, 'utf8').trim()];
  }));
  const personalExtension = path.join(packageDir, 'extension');
  const workExtension = path.join(runtimeDir, 'work-extension');
  fs.mkdirSync(workExtension, { recursive: true, mode: 0o700 });
  copyExtensionAssets(personalExtension, workExtension);
  const manifest = JSON.parse(fs.readFileSync(path.join(workExtension, 'manifest.json'), 'utf8'));
  manifest.name = 'Chrome Control (Work)';
  fs.writeFileSync(path.join(workExtension, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);

  const connections = { personal: null, work: null };
  const connectionInfo = { personal: null, work: null };
  const pending = new Map();
  const clients = new Set();
  const keepaliveTimers = new Map();
  const wsServer = new WebSocketServer({ host: '127.0.0.1', port, maxPayload: MAX_WS_MESSAGE, verifyClient(info, done) {
    let url;
    try { url = new URL(info.req.url, 'ws://127.0.0.1'); } catch { done(false); return; }
    const profile = url.searchParams.get('profile') || 'personal';
    done(url.pathname === '/extension' && profiles.includes(profile) && url.searchParams.get('token') === tokens[profile] && (info.origin || '').startsWith('chrome-extension://') && !connections[profile]);
  } });

  wsServer.on('connection', (ws, req) => {
    const url = new URL(req.url, 'ws://127.0.0.1');
    const profile = url.searchParams.get('profile') || 'personal';
    connections[profile] = ws;
    const keepalive = setInterval(() => {
      if (ws.readyState === 1) ws.send(JSON.stringify({ id: 'keepalive', action: 'ping' }), error => { if (error) ws.terminate(); });
    }, 20000).unref();
    keepaliveTimers.set(profile, keepalive);
    ws.on('message', data => {
      let message;
      try { message = JSON.parse(data.toString()); } catch { ws.close(1007, 'Invalid JSON'); return; }
      if (!message || typeof message !== 'object' || Array.isArray(message) || typeof message.id !== 'string' || message.id.length > 128) { ws.close(1008, 'Invalid response'); return; }
      if (message.action === 'handshake' && message.id === 'handshake') {
        if (message.protocol !== 'chrome-control' || message.protocolVersion !== 2 || message.implementationVersion !== '1.2.0' || !Array.isArray(message.capabilities)) { ws.close(1008, 'Invalid handshake'); return; }
        connectionInfo[profile] = { protocol: message.protocol, protocolVersion: message.protocolVersion, implementationVersion: message.implementationVersion, capabilities: message.capabilities.filter(value => typeof value === 'string').slice(0, 64) };
        ws.send(JSON.stringify({ id: 'handshake', ok: true, result: { accepted: true } })); return;
      }
      const item = pending.get(message.id);
      if (!item || item.profile !== profile || item.socket !== ws) return;
      pending.delete(message.id);
      clearTimeout(item.timeout);
      item.finish({ ...message, profile });
    });
    ws.on('close', () => {
      clearInterval(keepalive);
      if (keepaliveTimers.get(profile) === keepalive) keepaliveTimers.delete(profile);
      if (connections[profile] === ws) { connections[profile] = null; connectionInfo[profile] = null; }
      for (const [id, item] of pending) if (item.profile === profile && item.socket === ws) {
        pending.delete(id); clearTimeout(item.timeout);
        item.finish({ ok: false, profile, code: 'BRIDGE_DISCONNECTED', uncertain: true, error: 'Chrome bridge disconnected; action outcome is uncertain' });
      }
    });
  });

  const servers = profiles.map(profile => net.createServer(client => {
    clients.add(client);
    let buffer = Buffer.alloc(0);
    let finished = false;
    let dispatched = false;
    const frameTimeout = setTimeout(() => {
      if (!dispatched && !finished) finish({ ok: false, profile, code: 'REQUEST_TIMEOUT', error: 'Request framing timed out' });
    }, requestTimeoutMs);
    const finish = response => { if (finished) return; finished = true; client.end(`${JSON.stringify(response)}\n`); };
    client.on('close', () => {
      clearTimeout(frameTimeout);
      clients.delete(client);
      for (const [id, item] of pending) if (item.client === client) { pending.delete(id); clearTimeout(item.timeout); }
    });
    client.on('data', chunk => {
      if (finished || dispatched) { if (dispatched) client.destroy(); return; }
      buffer = Buffer.concat([buffer, chunk]);
      if (buffer.length > MAX_MESSAGE) { finish({ ok: false, profile, code: 'REQUEST_TOO_LARGE', error: 'Request too large' }); return; }
      const newline = buffer.indexOf(10);
      if (newline < 0) return;
      if (buffer.indexOf(10, newline + 1) !== -1 || buffer.subarray(newline + 1).some(byte => byte !== 13 && byte !== 32 && byte !== 9)) {
        finish({ ok: false, profile, code: 'INVALID_FRAMING', error: 'Expected exactly one newline-delimited request' }); return;
      }
      clearTimeout(frameTimeout);
      let command;
      try { command = JSON.parse(buffer.subarray(0, newline).toString('utf8')); } catch { finish({ ok: false, profile, code: 'INVALID_JSON', error: 'Invalid JSON' }); return; }
      if (!command || typeof command !== 'object' || Array.isArray(command)) { finish({ ok: false, profile, code: 'INVALID_COMMAND', error: 'Command must be a JSON object' }); return; }
      if (typeof command.action !== 'string' || command.action.length < 1 || command.action.length > 64 || !ACTIONS.has(command.action)) { finish({ ok: false, profile, code: 'INVALID_ACTION', error: 'Invalid action' }); return; }
      if (command.action === 'press' && !['Enter', 'Tab', 'Escape', 'ArrowUp', 'ArrowDown', 'Space'].includes(command.key)) { finish({ ok: false, profile, code: 'INVALID_KEY', error: 'Unsupported key; allowed keys are Enter, Tab, Escape, ArrowUp, ArrowDown, and Space' }); return; }
      if (command.frameId !== undefined && (!Number.isInteger(command.frameId) || command.frameId < 0)) { finish({ ok: false, profile, code: 'INVALID_FRAME', error: 'frameId must be a non-negative integer' }); return; }
      if (command.allFrames !== undefined && typeof command.allFrames !== 'boolean') { finish({ ok: false, profile, code: 'INVALID_FRAMES', error: 'allFrames must be boolean' }); return; }
      if (command.allFrames === true && command.action !== 'snapshot') { finish({ ok: false, profile, code: 'INVALID_FRAMES', error: 'Mutations require a single frame' }); return; }
      if (command.allFrames === true && command.frameId !== undefined) { finish({ ok: false, profile, code: 'INVALID_FRAMES', error: 'Cannot combine frameId and allFrames' }); return; }
      if (command.timeoutMs !== undefined && (!Number.isInteger(command.timeoutMs) || command.timeoutMs < 1 || command.timeoutMs > 5000)) { finish({ ok: false, profile, code: 'INVALID_TIMEOUT', error: 'timeoutMs must be between 1 and 5000' }); return; }
      if (command.inputMode !== undefined && !['activation', 'pointer-sequence'].includes(command.inputMode)) { finish({ ok: false, profile, code: 'INVALID_INPUT_MODE', error: 'Unsupported inputMode' }); return; }
      if (command.inputMode === 'pointer-sequence' && command.action !== 'click') { finish({ ok: false, profile, code: 'INVALID_INPUT_MODE', error: 'pointer-sequence is supported only for click' }); return; }
      if (command.expect !== undefined && (!command.expect || typeof command.expect !== 'object' || typeof command.expect.selector !== 'string' || !['visible', 'hidden', 'checked', 'unchecked'].includes(command.expect.state))) { finish({ ok: false, profile, code: 'INVALID_EXPECTATION', error: 'expect must include selector and a supported state' }); return; }
      if (command.id !== undefined && (typeof command.id !== 'string' || command.id.length > 128)) { finish({ ok: false, profile, code: 'INVALID_ID', error: 'Invalid request id' }); return; }
      const selected = command.profile === undefined ? 'personal' : command.profile;
      if (typeof selected !== 'string' || !profiles.includes(selected)) { finish({ ok: false, profile: selected, code: 'UNKNOWN_PROFILE', error: 'Unknown profile' }); return; }
      if (selected !== profile) { finish({ ok: false, profile: selected, code: 'WRONG_SOCKET', error: 'Request sent to wrong profile socket' }); return; }
      if (command.action === 'status') {
        const state = Object.fromEntries(profiles.map(p => [p, { connected: connections[p]?.readyState === 1, ...(connectionInfo[p] || {}) }]));
        finish({ ok: true, profile, connected: state[profile].connected, profiles: state }); return;
      }
      const ws = connections[profile];
      if (ws?.readyState !== 1) { finish({ ok: false, profile, code: 'BRIDGE_DISCONNECTED', error: 'Chrome bridge extension is disconnected' }); return; }
      dispatched = true;
      const id = crypto.randomUUID();
      const timeout = setTimeout(() => {
        pending.delete(id);
        finish({ ok: false, profile, code: 'ACTION_TIMEOUT', uncertain: true, error: 'Chrome action timed out; action outcome is uncertain' });
      }, actionTimeoutMs);
      pending.set(id, { profile, socket: ws, client, timeout, finish: response => {
        if (['snapshot', 'click', 'fill', 'press'].includes(command.action)) { finish(normalizePageResponse(command, response, profile)); return; }
        finish(response);
      } });
      const { id: _ignored, profile: _profile, ...fields } = command;
      try {
        ws.send(JSON.stringify({ ...fields, id }), error => {
          if (!error) return;
          const item = pending.get(id);
          if (!item) return;
          pending.delete(id); clearTimeout(timeout);
          item.finish({ ok: false, profile, code: 'SEND_FAILED', uncertain: true, error: 'Bridge send failed; action outcome is uncertain' });
        });
      } catch {
        pending.delete(id); clearTimeout(timeout);
        finish({ ok: false, profile, code: 'SEND_FAILED', uncertain: true, error: 'Bridge send failed; action outcome is uncertain' });
      }
    });
  }));

  let actualPort = port;
  const ready = (async () => {
    try {
      await new Promise((resolve, reject) => {
        wsServer.once('listening', resolve);
        wsServer.once('error', reject);
      });
      actualPort = wsServer.address().port;
      const outcomes = await Promise.allSettled(servers.map((server, index) => listenUnix(server, socketPaths[profiles[index]])));
      const failure = outcomes.find(outcome => outcome.status === 'rejected');
      if (failure) throw failure.reason;
      for (const socketPath of Object.values(socketPaths)) fs.chmodSync(socketPath, 0o600);

      fs.mkdirSync(workExtension, { recursive: true, mode: 0o700 });
      copyExtensionAssets(personalExtension, workExtension);
      const manifest = JSON.parse(fs.readFileSync(path.join(workExtension, 'manifest.json'), 'utf8'));
      manifest.name = 'Chrome Control (Work)';
      fs.writeFileSync(path.join(workExtension, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
      for (const [profile, token] of Object.entries(tokens)) {
        const directory = profile === 'personal' ? personalExtension : workExtension;
        const config = `export const BRIDGE_TOKEN = ${JSON.stringify(token)};\nexport const BRIDGE_PROFILE = '${profile}';\nexport const BRIDGE_PORT = ${actualPort};\n`;
        fs.writeFileSync(path.join(directory, 'config.js'), config, { mode: 0o600 });
        fs.chmodSync(path.join(directory, 'config.js'), 0o600);
      }
    } catch (error) {
      for (const client of clients) client.destroy();
      await Promise.all(servers.map(server => server.listening ? new Promise(resolve => server.close(resolve)) : Promise.resolve()));
      for (const ws of wsServer.clients) ws.terminate();
      if (wsServer._server?.listening) await new Promise(resolve => wsServer.close(resolve));
      throw error;
    }
  })();

  let closed = false;
  return {
    runtimeDir, socketPaths, workExtension, ready,
    get port() { return actualPort; },
    close: async () => {
      if (closed) return;
      closed = true;
      try { await ready; } catch {}
      for (const [id, item] of pending) {
        pending.delete(id); clearTimeout(item.timeout);
        item.finish({ ok: false, profile: item.profile, code: 'SERVER_STOPPED', uncertain: true, error: 'Chrome bridge stopped; action outcome is uncertain' });
      }
      for (const client of clients) client.destroy();
      for (const ws of Object.values(connections)) ws?.terminate();
      await Promise.all(servers.map(server => server.listening ? new Promise(resolve => server.close(resolve)) : Promise.resolve()));
      if (wsServer.clients.size) for (const ws of wsServer.clients) ws.terminate();
      if (wsServer._server?.listening) await new Promise(resolve => wsServer.close(resolve));
    },
  };
}

function copyExtensionAssets(source, destination) {
  for (const name of ['background.js', 'page-action.js', 'reload-scheduler.js', 'manifest.json']) {
    fs.copyFileSync(path.join(source, name), path.join(destination, name));
  }
  const maintenance = path.join(destination, 'maintenance');
  fs.mkdirSync(maintenance, { recursive: true, mode: 0o700 });
  for (const name of ['reload.html', 'reload.js']) {
    fs.copyFileSync(path.join(source, 'maintenance', name), path.join(maintenance, name));
  }
}

async function listenUnix(server, socketPath) {
  const listen = () => new Promise((resolve, reject) => {
    const onError = error => { server.removeListener('listening', onListening); reject(error); };
    const onListening = () => { server.removeListener('error', onError); resolve(); };
    server.once('error', onError);
    server.once('listening', onListening);
    server.listen(socketPath);
  });
  try { await listen(); return; } catch (error) {
    if (error.code !== 'EADDRINUSE') throw error;
  }
  const before = fs.lstatSync(socketPath, { throwIfNoEntry: false });
  if (!before?.isSocket()) throw Object.assign(new Error(`Refusing to remove non-socket path: ${socketPath}`), { code: 'EADDRINUSE' });
  const probe = await new Promise(resolve => {
    const client = net.createConnection({ path: socketPath });
    const timer = setTimeout(() => { client.destroy(); resolve('timeout'); }, 300);
    client.once('connect', () => { clearTimeout(timer); client.destroy(); resolve('connected'); });
    client.once('error', error => { clearTimeout(timer); resolve(error.code === 'ECONNREFUSED' ? 'refused' : 'error'); });
  });
  if (probe !== 'refused') throw Object.assign(new Error(`Unix socket is not proven stale (${probe}): ${socketPath}`), { code: 'EADDRINUSE' });
  const after = fs.lstatSync(socketPath, { throwIfNoEntry: false });
  if (!after?.isSocket() || before.dev !== after.dev || before.ino !== after.ino) throw Object.assign(new Error(`Unix socket changed during stale check: ${socketPath}`), { code: 'EADDRINUSE' });
  fs.unlinkSync(socketPath);
  await listen();
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const bridge = startChromeControl();
  await bridge.ready;
  console.error(`chrome control listening on ${bridge.socketPaths.personal} and ${bridge.socketPaths.work}`);
  process.on('SIGTERM', () => bridge.close().finally(() => process.exit(0)));
}
