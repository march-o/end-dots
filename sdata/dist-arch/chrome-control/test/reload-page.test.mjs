import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

test('maintenance reload page is local-only and schedules exactly one delayed extension reload', () => {
  const directory = new URL('../extension/maintenance/', import.meta.url);
  const html = fs.readFileSync(new URL('reload.html', directory), 'utf8');
  const script = fs.readFileSync(new URL('reload.js', directory), 'utf8');
  assert.match(html, /<script src="reload\.js"><\/script>/);
  assert.doesNotMatch(html, /https?:\/\//);
  assert.doesNotMatch(script, /fetch\s*\(|XMLHttpRequest|https?:\/\//);
  const timers = [];
  let reloads = 0;
  const context = { window: { setTimeout: (callback, delay) => timers.push({ callback, delay }) }, chrome: { runtime: { reload: () => reloads++ } } };
  vm.runInNewContext(script, context);
  vm.runInNewContext(script, context);
  assert.equal(timers.length, 1);
  assert.equal(timers[0].delay, 700);
  timers[0].callback();
  assert.equal(reloads, 1);
});
