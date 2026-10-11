import { test } from 'node:test';
import assert from 'node:assert/strict';
import { scheduleRuntimeReload } from '../extension/reload-scheduler.js';

test('native reload acknowledges before scheduling one delayed extension-only reload', () => {
  const events = [];
  let callback;
  let delay;
  scheduleRuntimeReload({
    id: 'request-1',
    send: response => events.push(['ack', response]),
    reload: () => events.push(['reload']),
    setTimer: (fn, ms) => { callback = fn; delay = ms; },
  });
  assert.deepEqual(events, [['ack', { id: 'request-1', ok: true, result: { reloading: true } }]]);
  assert.equal(delay, 500);
  assert.throws(() => scheduleRuntimeReload({ id: 'request-2', send: () => {}, reload: () => {}, setTimer: () => {} }), /already scheduled/);
  assert.deepEqual(events.map(([type]) => type), ['ack']);
  callback();
  assert.deepEqual(events.map(([type]) => type), ['ack', 'reload']);
});
