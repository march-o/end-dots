import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import net from 'node:net';
import http from 'node:http';
import { spawn } from 'node:child_process';
import { startChromeControl } from '../server.mjs';

// Unpacked-extension loading requires an extension-capable Chromium build.
const chrome = process.env.CHROME_BIN;
const run = (socket, command) => new Promise((resolve, reject) => {
  const client = net.createConnection(socket); let body = '';
  client.on('data', chunk => { body += chunk; });
  client.on('error', reject); client.on('end', () => resolve(JSON.parse(body)));
  client.on('connect', () => client.end(`${JSON.stringify({ ...command, profile: 'personal' })}\n`));
});
const waitFor = async (fn, timeout = 15000) => { const end = Date.now() + timeout; while (Date.now() < end) { const value = await fn(); if (value) return value; await new Promise(resolve => setTimeout(resolve, 250)); } throw new Error('Timed out waiting for isolated Chrome'); };

test('isolated Chromium extension verifies a real synthetic page transition', { timeout: 30000 }, async t => {
  if (process.env.CHROME_CONTROL_LIVE_TEST !== '1') return t.skip('Opt in with CHROME_CONTROL_LIVE_TEST=1 and CHROME_BIN.');
  if (!chrome || !fs.existsSync(chrome)) throw new Error('CHROME_BIN must point to an extension-capable Chromium executable'); if (!process.env.DISPLAY && !process.env.WAYLAND_DISPLAY && !process.env.FORCE_WAYLAND) return t.skip('A headed display is required for extension integration; headless Chrome disables unpacked extensions.');
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'chrome-control-live-'));
  const pkg = path.join(root, 'pkg'); const extension = path.join(pkg, 'extension');
  fs.mkdirSync(path.join(extension, 'maintenance'), { recursive: true });
  for (const file of ['server.mjs', 'normalize-page-response.mjs', 'package.json', 'package-lock.json']) fs.copyFileSync(new URL(`../${file}`, import.meta.url), path.join(pkg, file));
  for (const file of ['background.js', 'page-action.js', 'reload-scheduler.js', 'manifest.json']) fs.copyFileSync(new URL(`../extension/${file}`, import.meta.url), path.join(extension, file));
  for (const file of ['reload.html', 'reload.js']) fs.copyFileSync(new URL(`../extension/maintenance/${file}`, import.meta.url), path.join(extension, 'maintenance', file));
  fs.cpSync(path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'node_modules'), path.join(pkg, 'node_modules'), { recursive: true });
  const page = '<!doctype html><button id="show" onclick="document.querySelector(\'#dialog\').hidden=false">Show dialog</button><div id="dialog" role="dialog" hidden>Ready</div>';
  const server = http.createServer((req, res) => { res.writeHead(200, { 'content-type': 'text/html' }); res.end(page); }); await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const bridge = startChromeControl({ runtimeDir: path.join(root, 'runtime'), packageDir: pkg, port: 0 }); await bridge.ready;
  let browser;
  t.after(async () => { browser?.kill('SIGTERM'); await bridge.close(); await new Promise(resolve => server.close(resolve)); fs.rmSync(root, { recursive: true, force: true }); });
  browser = spawn(chrome, ['--ozone-platform=wayland', '--start-minimized', '--disable-gpu', '--no-sandbox', `--user-data-dir=${path.join(root, 'profile')}`, `--load-extension=${extension}`, `--disable-extensions-except=${extension}`, 'about:blank'], { stdio: 'inherit' });
  const ready = await waitFor(async () => { const result = await run(bridge.socketPaths.personal, { action: 'status' }); return result.profiles?.personal?.implementationVersion === '1.2.0' ? result : null; });
  assert.deepEqual(ready.profiles.personal.capabilities.includes('verified-page-outcomes'), true);
  const opened = await run(bridge.socketPaths.personal, { action: 'open', url: `http://127.0.0.1:${server.address().port}/` });
  const clicked = await run(bridge.socketPaths.personal, { action: 'click', tabId: opened.result.tabId, selector: '#show', expect: { selector: '#dialog', state: 'visible' }, timeoutMs: 3000 });
  assert.equal(clicked.ok, true); assert.equal(clicked.result[0].result.outcome, 'verified');
  assert.equal((await run(bridge.socketPaths.personal, { action: 'snapshot', tabId: opened.result.tabId })).ok, true);
});
