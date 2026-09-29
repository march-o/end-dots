import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { WebSocketServer } from 'ws';

const runtimeDir = path.join(os.homedir(), '.local', 'share', 'end-dots-martins');
const socketPath = path.join(runtimeDir, 'chrome-control.sock');
const tokenPath = path.join(runtimeDir, 'chrome-control-token');
const port = 49376;
fs.mkdirSync(runtimeDir, { recursive: true, mode: 0o700 });
if (!fs.existsSync(tokenPath)) fs.writeFileSync(tokenPath, crypto.randomBytes(32).toString('hex'), { mode: 0o600 });
const token = fs.readFileSync(tokenPath, 'utf8').trim();
const extensionConfig = path.join(import.meta.dirname, 'extension', 'config.js');
fs.writeFileSync(extensionConfig, `export const BRIDGE_TOKEN = ${JSON.stringify(token)};\n`, { mode: 0o600 });
try { fs.unlinkSync(socketPath); } catch (e) { if (e.code !== 'ENOENT') throw e; }

let extension = null;
const pending = new Map();
const wss = new WebSocketServer({ port, host: '127.0.0.1', verifyClient(info, done) {
  const url = new URL(info.req.url, `ws://127.0.0.1:${port}`);
  const origin = info.origin || '';
  done(url.pathname === '/extension' && url.searchParams.get('token') === token && origin.startsWith('chrome-extension://'));
} });
wss.on('connection', ws => {
  extension?.close();
  extension = ws;
  ws.on('message', data => {
    let message;
    try { message = JSON.parse(data.toString()); } catch { return; }
    const resolve = pending.get(message.id);
    if (resolve) { pending.delete(message.id); resolve(message); }
  });
  ws.on('close', () => { if (extension === ws) extension = null; });
});
setInterval(() => {
  if (extension?.readyState === 1) extension.send(JSON.stringify({ id: 'keepalive', action: 'ping' }));
}, 20000).unref();

const unix = net.createServer(client => {
  let buffer = '';
  client.on('data', data => {
    buffer += data.toString();
    const newline = buffer.indexOf('\n');
    if (newline < 0) return;
    const line = buffer.slice(0, newline);
    buffer = '';
    let command;
    try { command = JSON.parse(line); } catch { client.end(JSON.stringify({ ok: false, error: 'Invalid JSON' }) + '\n'); return; }
    if (command.action === 'status') {
      client.end(JSON.stringify({ ok: true, connected: extension?.readyState === 1 }) + '\n');
      return;
    }
    if (extension?.readyState !== 1) { client.end(JSON.stringify({ ok: false, error: 'Chrome bridge extension is disconnected' }) + '\n'); return; }
    const id = crypto.randomUUID();
    const timeout = setTimeout(() => {
      pending.delete(id);
      client.end(JSON.stringify({ ok: false, error: 'Chrome action timed out' }) + '\n');
    }, 30000);
    pending.set(id, response => {
      clearTimeout(timeout);
      if (command.action === 'snapshot' && command.allFrames !== true && Array.isArray(response.result)) {
        response.result = response.result.filter(frame => frame.frameId === 0);
      }
      client.end(JSON.stringify(response) + '\n');
    });
    extension.send(JSON.stringify({ id, ...command }));
  });
});
unix.listen(socketPath, () => fs.chmodSync(socketPath, 0o600));
process.on('SIGTERM', () => {
  for (const client of wss.clients) client.terminate();
  try { fs.unlinkSync(socketPath); } catch {}
  process.exit(0);
});
console.error(`chrome control listening on ${socketPath}`);
