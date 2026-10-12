import { test } from 'node:test';
import assert from 'node:assert/strict';
import { pageAction } from '../extension/page-action.js';

class FakeKeyboardEvent { constructor(type, init) { this.type = type; this.defaultPrevented = false; Object.assign(this, init); } preventDefault() { this.defaultPrevented = true; } }
function installDocument(elements, state = {}) {
  const old = { document: globalThis.document, CSS: globalThis.CSS, getComputedStyle: globalThis.getComputedStyle, HTMLElement: globalThis.HTMLElement, KeyboardEvent: globalThis.KeyboardEvent, PointerEvent: globalThis.PointerEvent, MouseEvent: globalThis.MouseEvent, location: globalThis.location };
  class HTMLElement {}
  Object.assign(globalThis, { HTMLElement, KeyboardEvent: FakeKeyboardEvent, PointerEvent: class { constructor(type, init) { this.type = type; Object.assign(this, init); } }, MouseEvent: class extends FakeKeyboardEvent {}, CSS: { escape: value => value }, getComputedStyle: () => ({ visibility: 'visible', display: 'block', opacity: '1' }), location: { href: 'https://example.test' } });
  const all = selector => selector.includes(',') ? elements : elements.filter(el => selector === el.uniqueSelector || selector === `#${el.id}` || selector === `[data-testid="${el.testid}"]` || selector === state.expectationSelector);
  Object.assign(globalThis, { document: { visibilityState: 'visible', hasFocus: () => true, documentElement: { contains: el => elements.includes(el) }, querySelectorAll: all, querySelector: selector => { const found = all(selector); return found.length === 1 ? found[0] : null; }, getElementById: id => elements.find(el => el.id === id) || null, body: { innerText: 'safe text' } } });
  for (const element of elements) { Object.setPrototypeOf(element, HTMLElement.prototype); element.matches = selector => selector === ':disabled' ? Boolean(element.disabled) : false; element.closest = () => null; element.parentElement = null; element.hidden = false; }
  return () => { for (const [key, value] of Object.entries(old)) value === undefined ? delete globalThis[key] : globalThis[key] = value; };
}
const target = (extra = {}) => ({ localName: 'button', id: 'action', testid: '', uniqueSelector: '#action', isConnected: true, getClientRects: () => [1], getAttribute: name => ({ 'aria-label': 'Action' })[name] || null, innerText: 'Action', labels: [], disabled: false, addEventListener() {}, removeEventListener() {}, focus() {}, dispatchEvent() { return true; }, click() {}, ...extra });

test('snapshot reports accessible state without values', async () => {
  const input = target({ localName: 'input', id: 'field', uniqueSelector: '#field', value: 'SECRET', type: 'text' });
  const restore = installDocument([input]);
  try { const result = await pageAction({ action: 'snapshot' }); assert.equal(result.elements[0].selector, '#field'); assert.equal(JSON.stringify(result).includes('SECRET'), false); } finally { restore(); }
});

test('press emits keyboard sequence and remains explicitly unverified without expect', async () => {
  const events = []; const button = target({ focus() { document.activeElement = button; }, dispatchEvent: event => { events.push(event); return true; } });
  const restore = installDocument([button]);
  try { const result = await pageAction({ action: 'press', selector: '#action', key: 'Enter' }); assert.equal(result.outcome, 'unverified'); assert.equal(result.canceled, false); assert.deepEqual(events.map(e => e.type), ['keydown', 'keypress', 'keyup']); assert.equal(events[0].keyCode, 13); } finally { restore(); }
});

test('already satisfied expectation rejects before mutation', async () => {
  const button = target(); const restore = installDocument([button], { expectationSelector: '#action' });
  try { await assert.rejects(() => pageAction({ action: 'click', selector: '#action', expect: { selector: '#action', state: 'visible' } }), /already satisfied/); } finally { restore(); }
});

test('unsupported Tab and invalid key are rejected', async () => {
  const button = target(); const restore = installDocument([button]);
  try { await assert.rejects(() => pageAction({ action: 'press', selector: '#action', key: 'Tab' }), /unsupported/); await assert.rejects(() => pageAction({ action: 'press', selector: '#action', key: 'a' }), /Unsupported key/); } finally { restore(); }
});


test('cancelled key does not synthesize button activation', async () => {
  let clicks = 0;
  const events = [];
  const button = target({ focus() { document.activeElement = button; }, click() { clicks++; }, dispatchEvent(event) { events.push(event.type); return event.type !== 'keydown'; } });
  const restore = installDocument([button]);
  try {
    const result = await pageAction({ action: 'press', selector: '#action', key: 'Enter' });
    assert.equal(result.canceled, true); assert.equal(clicks, 0);
    assert.deepEqual(events, ['keydown', 'keyup']);
  } finally { restore(); }
});

test('click verifies a changed checkbox exactly once', async () => {
  let clicks = 0;
  const button = target({ checked: false, click() { clicks++; this.checked = true; } });
  const restore = installDocument([button]);
  try {
    const result = await pageAction({ action: 'click', selector: '#action', expect: { selector: '#action', state: 'checked' } });
    assert.equal(clicks, 1); assert.equal(result.verified, true);
    assert.deepEqual(result.postcondition, { selector: '#action', state: 'checked', before: false, after: true });
  } finally { restore(); }
});

test('failed postcondition times out without retrying input', async () => {
  let clicks = 0;
  const button = target({ checked: false, click() { clicks++; } });
  const restore = installDocument([button]);
  try {
    const result = await pageAction({ action: 'click', selector: '#action', timeoutMs: 1, expect: { selector: '#action', state: 'checked' } });
    assert.equal(clicks, 1); assert.equal(result.code, 'POSTCONDITION_TIMEOUT'); assert.equal(result.verified, false);
  } finally { restore(); }
});

test('unchecked is not satisfied by an arbitrary element', async () => {
  const button = target(); const restore = installDocument([button]);
  try {
    const result = await pageAction({ action: 'click', selector: '#action', timeoutMs: 1, expect: { selector: '#action', state: 'unchecked' } });
    assert.equal(result.code, 'POSTCONDITION_TIMEOUT');
  } finally { restore(); }
});
