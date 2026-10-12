import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import net from 'node:net';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { WebSocket } from 'ws';
import { startChromeControl } from '../server.mjs';

const run = (name, fn) => test(name, { timeout: 2000 }, fn);

async function fixture(t, options = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'chrome-control-'));
  const pkg = path.join(root, 'package');
  fs.mkdirSync(path.join(pkg, 'extension'), { recursive: true });
  for (const file of ['background.js', 'page-action.js', 'reload-scheduler.js', 'manifest.json']) fs.copyFileSync(new URL(`../extension/${file}`, import.meta.url), path.join(pkg, 'extension', file));
  fs.mkdirSync(path.join(pkg, 'extension', 'maintenance'));
  for (const file of ['reload.html', 'reload.js']) fs.copyFileSync(new URL(`../extension/maintenance/${file}`, import.meta.url), path.join(pkg, 'extension', 'maintenance', file));
  const bridge = startChromeControl({ runtimeDir: path.join(root, 'runtime'), packageDir: pkg, port: 0, ...options });
  t.after(async () => { await bridge.close(); fs.rmSync(root, { recursive: true, force: true }); });
  await bridge.ready;
  const token = profile => fs.readFileSync(path.join(root, 'runtime', profile === 'personal' ? 'chrome-control-token' : 'chrome-control-work-token'), 'utf8');
  const connect = (profile, overrideToken = token(profile), omitProfile = false) => new WebSocket(`ws://127.0.0.1:${bridge.port}/extension?token=${overrideToken}${omitProfile ? '' : `&profile=${profile}`}`, { origin: 'chrome-extension://testid' });
  const rawRequest = (profile, writes, socketPath = bridge.socketPaths[profile]) => new Promise(resolve => {
    const client = net.connect(socketPath);
    let data = '';
    client.on('data', chunk => data += chunk.toString());
    client.on('end', () => { try { resolve(JSON.parse(data)); } catch { resolve(data); } });
    client.on('connect', () => { for (const write of writes) client.write(write); });
  });
  const request = (profile, command, socketPath = bridge.socketPaths[profile]) => rawRequest(profile, [`${JSON.stringify({ ...command, profile: command.profile ?? profile })}\n`], socketPath);
  return { root, bridge, token, connect, request, rawRequest };
}

run('ready waits for both Unix sockets and port zero publishes its actual port', async t => {
  const f = await fixture(t);
  assert.ok(f.bridge.port > 0);
  for (const socketPath of Object.values(f.bridge.socketPaths)) assert.equal(fs.statSync(socketPath).isSocket(), true);
  assert.equal((await f.request('personal', { action: 'status' })).ok, true);
  assert.equal((await f.request('work', { action: 'status' })).ok, true);
});

run('startup removes only a proven stale Unix socket', async t => {
  const f = await fixture(t);
  await f.bridge.close();
  const runtimeDir = path.join(path.dirname(f.bridge.socketPaths.personal), 'stale-runtime');
  fs.mkdirSync(runtimeDir);
  const socketPath = path.join(runtimeDir, 'chrome-control.sock');
  const child = spawn(process.execPath, ['-e', `require('node:net').createServer().listen(${JSON.stringify(socketPath)}, () => { console.log('ready'); setInterval(() => {}, 1000); });`]);
  await new Promise((resolve, reject) => {
    child.stdout.once('data', resolve);
    child.once('error', reject);
  });
  child.kill('SIGKILL');
  await once(child, 'exit');
  assert.equal(fs.lstatSync(socketPath).isSocket(), true);
  const recovered = startChromeControl({ runtimeDir, packageDir: path.join(f.root, 'package'), port: 0 });
  t.after(() => recovered.close());
  await recovered.ready;
  assert.equal(fs.statSync(socketPath).isSocket(), true);
});

run('live competing instance and non-socket paths are never unlinked', async t => {
  const f = await fixture(t);
  const configPath = path.join(f.root, 'package', 'extension', 'config.js');
  const before = fs.readFileSync(configPath, 'utf8');
  const contender = startChromeControl({ runtimeDir: path.dirname(f.bridge.socketPaths.personal), packageDir: path.join(f.root, 'package'), port: 0 });
  await assert.rejects(contender.ready, /not proven stale/);
  await contender.close();
  assert.equal(fs.readFileSync(configPath, 'utf8'), before);
  assert.equal((await f.request('personal', { action: 'status' })).ok, true);

  const runtimeDir = path.join(f.root, 'non-socket'); fs.mkdirSync(runtimeDir);
  const filePath = path.join(runtimeDir, 'chrome-control.sock'); fs.writeFileSync(filePath, 'keep');
  const blocked = startChromeControl({ runtimeDir, packageDir: path.join(f.root, 'package'), port: 0 });
  await assert.rejects(blocked.ready, /non-socket path/);
  await blocked.close();
  assert.equal(fs.readFileSync(filePath, 'utf8'), 'keep');
});

run('incomplete Unix requests time out and shutdown destroys idle clients', async t => {
  const f = await fixture(t, { requestTimeoutMs: 25 });
  const idle = net.connect(f.bridge.socketPaths.personal);
  await once(idle, 'connect');
  idle.write('{"action":');
  let body = '';
  idle.on('data', chunk => body += chunk.toString());
  await once(idle, 'end');
  assert.equal(JSON.parse(body).code, 'REQUEST_TIMEOUT');

  const held = net.connect(f.bridge.socketPaths.work);
  await once(held, 'connect');
  const closed = once(held, 'close');
  await f.bridge.close();
  await closed;
});

run('profiles connect independently, legacy URL is personal, and statuses are profile-aware', async t => {
  const f = await fixture(t);
  const personal = f.connect('personal', f.token('personal'), true); await once(personal, 'open');
  const work = f.connect('work'); await once(work, 'open');
  assert.equal((await f.request('personal', { action: 'status' })).profile, 'personal');
  assert.deepEqual((await f.request('work', { action: 'status' })).profiles, { personal: { connected: true }, work: { connected: true } });
  assert.equal((await f.request('personal', { action: 'status', profile: 'bogus' })).ok, false);
  const duplicate = f.connect('personal');
  await assert.rejects(once(duplicate, 'open'));
  personal.close(); work.close();
});

run('wrong credentials and disconnected profiles fail closed', async t => {
  const f = await fixture(t);
  const wrong = f.connect('work', f.token('personal'));
  await assert.rejects(once(wrong, 'open'));
  const response = await f.request('work', { action: 'list' });
  assert.equal(response.ok, false); assert.match(response.error, /disconnected/);
  assert.equal((await f.request('personal', { action: 'list', profile: 'unknown' })).ok, false);
});

run('overlapping tab ids route only to the matching profile and incoming ids cannot override server ids', async t => {
  const f = await fixture(t);
  const personal = f.connect('personal'); const work = f.connect('work');
  await Promise.all([once(personal, 'open'), once(work, 'open')]);
  const pCmd = new Promise(resolve => personal.once('message', data => resolve(JSON.parse(data))));
  const wCmd = new Promise(resolve => work.once('message', data => resolve(JSON.parse(data))));
  const pResult = f.request('personal', { action: 'navigate', tabId: 7, id: 'forged', profile: 'personal' });
  const wResult = f.request('work', { action: 'navigate', tabId: 7 });
  const [pc, wc] = await Promise.all([pCmd, wCmd]);
  assert.notEqual(pc.id, 'forged'); assert.notEqual(pc.id, wc.id);
  personal.send(JSON.stringify({ id: wc.id, ok: true, result: 'cross-profile' }));
  work.send(JSON.stringify({ id: pc.id, ok: true, result: 'cross-profile' }));
  personal.send(JSON.stringify({ id: pc.id, ok: true, result: { profile: 'personal-result' } }));
  work.send(JSON.stringify({ id: wc.id, ok: true, result: { profile: 'work-result' } }));
  assert.equal((await pResult).result.profile, 'personal-result');
  assert.equal((await wResult).result.profile, 'work-result');
  personal.close(); work.close();
});

run('disconnect returns explicit uncertain outcome to pending caller', async t => {
  const f = await fixture(t); const work = f.connect('work'); await once(work, 'open');
  const result = f.request('work', { action: 'close_tab', tabId: 42 });
  await once(work, 'message'); work.terminate();
  const response = await result;
  assert.equal(response.ok, false); assert.equal(response.profile, 'work'); assert.equal(response.code, 'BRIDGE_DISCONNECTED'); assert.equal(response.uncertain, true);
});

run('malformed JSON, non-object commands, invalid action/id, and bad framing are rejected', async t => {
  const f = await fixture(t);
  for (const [payload, code] of [
    ['{nope}\n', 'INVALID_JSON'], ['null\n', 'INVALID_COMMAND'], ['[]\n', 'INVALID_COMMAND'],
    ['{}\n', 'INVALID_ACTION'], ['{"action":"list","id":4}\n', 'INVALID_ID'],
    ['{"action":"status"}\n{"action":"status"}\n', 'INVALID_FRAMING'],
  ]) {
    const result = await f.rawRequest('personal', [payload]);
    assert.equal(result.code, code, payload);
  }
  const badWs = f.connect('personal'); await once(badWs, 'open');
  badWs.send('null');
  await once(badWs, 'close');
});

run('large snapshot responses are accepted and repeated client payload dispatches once only', async t => {
  const f = await fixture(t); const work = f.connect('work'); await once(work, 'open');
  let messageCount = 0;
  work.on('message', () => messageCount++);
  const command = new Promise(resolve => work.once('message', data => resolve(JSON.parse(data))));
  const client = net.connect(f.bridge.socketPaths.work);
  await once(client, 'connect');
  client.write('{"action":"snapshot","tabId":1,"profile":"work"}\n');
  const dispatched = await command;
  assert.equal(messageCount, 1);
  const closed = once(client, 'close');
  client.write('{"action":"snapshot","tabId":1,"profile":"work"}\n');
  await closed;
  await new Promise(resolve => setTimeout(resolve, 20));
  assert.equal(messageCount, 1);
  work.send(JSON.stringify({ id: dispatched.id, ok: true, result: [{ frameId: 0, result: { text: 'x'.repeat(100000) } }] }));
  await new Promise(resolve => setTimeout(resolve, 20));
  const repeated = new Promise(resolve => work.once('message', data => resolve(JSON.parse(data))));
  const result = f.request('work', { action: 'snapshot', tabId: 2 });
  const next = await repeated;
  assert.equal(next.action, 'snapshot');
  work.send(JSON.stringify({ id: next.id, ok: true, result: [{ frameId: 0, result: { text: 'y'.repeat(100000) } }] }));
  const response = await result;
  assert.equal(response.result[0].result.text.length, 100000);
  work.close();
});

run('action timeout is structured and explicitly uncertain', async t => {
  const f = await fixture(t, { actionTimeoutMs: 25 }); const work = f.connect('work'); await once(work, 'open');
  const command = new Promise(resolve => work.once('message', data => resolve(JSON.parse(data))));
  const result = f.request('work', { action: 'list' });
  await command;
  const response = await result;
  assert.equal(response.code, 'ACTION_TIMEOUT');
  assert.equal(response.uncertain, true);
  work.close();
});

run('null page results and page exceptions never become successful actions', async t => {
  const f = await fixture(t); const personal = f.connect('personal'); await once(personal, 'open');
  const command = new Promise(resolve => personal.once('message', data => resolve(JSON.parse(data))));
  const nullResult = f.request('personal', { action: 'click', tabId: 22, selector: '#missing' });
  const sent = await command;
  personal.send(JSON.stringify({ id: sent.id, ok: true, result: [{ frameId: 0, result: null }] }));
  const rejected = await nullResult;
  assert.equal(rejected.ok, false);
  assert.equal(rejected.code, 'INVALID_PAGE_RESULT');

  const thrownCommand = new Promise(resolve => personal.once('message', data => resolve(JSON.parse(data))));
  const thrownResult = f.request('personal', { action: 'fill', tabId: 22, selector: '#readonly', value: 'x' });
  const thrown = await thrownCommand;
  personal.send(JSON.stringify({ id: thrown.id, ok: false, error: 'Element is not fillable' }));
  const failure = await thrownResult;
  assert.equal(failure.ok, false);
  assert.match(failure.error, /Element is not fillable/);
  personal.close();
});

run('press accepts only its enumerated keys before dispatch', async t => {
  const f = await fixture(t);
  const response = await f.request('personal', { action: 'press', tabId: 1, selector: '#field', key: 'a' });
  assert.equal(response.ok, false);
  assert.equal(response.code, 'INVALID_KEY');
});

run('reload is forwarded as a native action and resolves from its acknowledgement', async t => {
  const f = await fixture(t); const personal = f.connect('personal'); await once(personal, 'open');
  const command = new Promise(resolve => personal.once('message', data => resolve(JSON.parse(data))));
  const result = f.request('personal', { action: 'reload' });
  const dispatched = await command;
  assert.equal(dispatched.action, 'reload');
  personal.send(JSON.stringify({ id: dispatched.id, ok: true, result: { reloading: true } }));
  assert.deepEqual((await result).result, { reloading: true });
  personal.close();
});

run('handshake exposes implementation metadata and rejects incompatible versions', async t => {
  const f = await fixture(t);
  const ws = f.connect('personal'); await once(ws, 'open');
  const acknowledgement = once(ws, 'message');
  ws.send(JSON.stringify({ id: 'handshake', action: 'handshake', protocol: 'chrome-control', protocolVersion: 2, implementationVersion: '1.2.0', capabilities: ['verified-page-outcomes'] }));
  assert.equal(JSON.parse((await acknowledgement)[0]).ok, true);
  const status = await f.request('personal', { action: 'status' });
  assert.equal(status.profiles.personal.implementationVersion, '1.2.0');
  const work = f.connect('work'); await once(work, 'open');
  const closed = once(work, 'close');
  work.send(JSON.stringify({ id: 'handshake', action: 'handshake', protocol: 'chrome-control', protocolVersion: 99, implementationVersion: '1.2.0', capabilities: [] }));
  assert.equal((await closed)[0], 1008);
});
