import { test } from 'node:test';
import assert from 'node:assert/strict';
import { pageAction } from '../extension/page-action.js';

class FakeKeyboardEvent {
  constructor(type, init) { this.type = type; this.defaultPrevented = false; Object.assign(this, init); }
  preventDefault() { this.defaultPrevented = true; }
}

function installDocument(elements) {
  const old = { document: globalThis.document, CSS: globalThis.CSS, getComputedStyle: globalThis.getComputedStyle, HTMLElement: globalThis.HTMLElement, KeyboardEvent: globalThis.KeyboardEvent };
  class HTMLElement {}
  Object.assign(globalThis, {
    HTMLElement, KeyboardEvent: FakeKeyboardEvent, CSS: { escape: value => value },
    getComputedStyle: () => ({ visibility: 'visible', display: 'block', opacity: '1' }),
    document: {
      documentElement: { contains: element => elements.includes(element) },
      querySelectorAll: selector => selector.includes(',') ? elements : elements.filter(el => selector === el.uniqueSelector || selector === `#${el.id}` || selector === `[data-testid="${el.testid}"]`),
      querySelector: selector => { const found = globalThis.document.querySelectorAll(selector); return found.length === 1 ? found[0] : null; },
      getElementById: id => elements.find(el => el.id === id) || null,
      body: { innerText: 'safe text' },
    },
    location: { href: 'https://example.test' },
  });
  for (const element of elements) Object.setPrototypeOf(element, HTMLElement.prototype);
  return () => { for (const [key, value] of Object.entries(old)) value === undefined ? delete globalThis[key] : globalThis[key] = value; delete globalThis.location; };
}

test('snapshot returns unique selectors and accessible visible state without values', () => {
  const combobox = { localName: 'div', id: 'choice', testid: '', uniqueSelector: '#choice', isConnected: true, getClientRects: () => [1], getAttribute: name => ({ role: 'combobox', 'aria-label': 'Support email', 'aria-checked': null, 'aria-disabled': 'false' })[name] || null, innerText: 'Choose email', labels: [], disabled: false };
  const checkbox = { ...combobox, localName: 'input', id: '', testid: 'accept', uniqueSelector: '[data-testid="accept"]', checked: true, value: 'MUST NOT APPEAR', type: 'checkbox', getAttribute: name => ({ role: 'checkbox', 'data-testid': 'accept', 'aria-checked': 'true', 'aria-label': 'Policy checkbox' })[name] || null };
  const restore = installDocument([combobox, checkbox]);
  try {
    const result = pageAction({ action: 'snapshot' });
    assert.deepEqual(result.elements.map(el => el.selector), ['#choice', '[data-testid="accept"]']);
    assert.equal(result.elements[0].ariaLabel, 'Support email');
    assert.equal(result.elements[0].visible, true);
    assert.equal(result.elements[1].checked, true);
    assert.equal(JSON.stringify(result).includes('MUST NOT APPEAR'), false);
  } finally { restore(); }
});

test('Enter focuses only the target and dispatches keypress with legacy chip-handler fields', () => {
  let focused = false;
  const events = [];
  const target = { localName: 'input', id: 'chip', uniqueSelector: '#chip', isConnected: true, focus: options => { assert.deepEqual(options, { preventScroll: true }); focused = true; }, dispatchEvent: event => { events.push(event); return !event.defaultPrevented; } };
  const restore = installDocument([target]);
  try {
    assert.deepEqual(pageAction({ action: 'press', selector: '#chip', key: 'Enter' }), { pressed: 'Enter', selector: '#chip' });
    assert.equal(focused, true);
    assert.deepEqual(events.map(event => event.type), ['keydown', 'keypress', 'keyup']);
    assert.equal(events[0].key, 'Enter');
    assert.equal(events[0].keyCode, 13);
    assert.equal(events[0].which, 13);
    assert.equal(events[1].charCode, 13);
    assert.equal(events[1].keyCode, 13);
    assert.equal(events[1].which, 13);
    assert.equal(events[2].type, 'keyup');
  } finally { restore(); }
});

test('preventDefault on keydown stays on that event and preserves the later keypress/keyup sequence', () => {
  const events = [];
  const target = { localName: 'input', id: 'chip', uniqueSelector: '#chip', isConnected: true, focus() {}, dispatchEvent: event => { events.push(event); if (event.type === 'keydown') event.preventDefault(); return !event.defaultPrevented; } };
  const restore = installDocument([target]);
  try {
    pageAction({ action: 'press', selector: '#chip', key: 'Enter' });
    assert.deepEqual(events.map(event => event.type), ['keydown', 'keypress', 'keyup']);
    assert.equal(events[0].defaultPrevented, true);
    assert.equal(events[1].defaultPrevented, false);
  } finally { restore(); }
});

test('Space emits keypress with its space character code', () => {
  const events = [];
  const target = { localName: 'button', id: 'space', uniqueSelector: '#space', isConnected: true, focus() {}, dispatchEvent: event => { events.push(event); return true; } };
  const restore = installDocument([target]);
  try {
    pageAction({ action: 'press', selector: '#space', key: 'Space' });
    const keypress = events.find(event => event.type === 'keypress');
    assert.equal(keypress.key, ' ');
    assert.equal(keypress.charCode, 32);
    assert.equal(keypress.keyCode, 32);
    assert.equal(keypress.which, 32);
  } finally { restore(); }
});

test('press rejects keys outside the strict enumeration', () => {
  const restore = installDocument([]);
  try { assert.throws(() => pageAction({ action: 'press', key: 'a' }), /Unsupported key/); }
  finally { restore(); }
});
