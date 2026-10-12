import { test } from 'node:test';
import assert from 'node:assert/strict';
import { normalizePageResponse } from '../normalize-page-response.mjs';
const command = { action: 'click', selector: '#open', expect: { selector: '#menu', state: 'visible' } };
const confirmed = () => ({ ok: true, result: [{ frameId: 0, result: { action: 'click', selector: '#open', verified: true, outcome: 'verified', postcondition: { selector: '#menu', state: 'visible', before: false, after: true } } }] });
test('only matching confirmed transitions report mutation success', () => {
  assert.equal(normalizePageResponse(command, confirmed(), 'personal').ok, true);
  for (const mutate of [r => r.result[0].result.verified = false, r => r.result[0].result.selector = '#other', r => r.result[0].result.postcondition.before = true, r => r.result[0].result.postcondition.state = 'hidden']) {
    const r = confirmed(); mutate(r);
    assert.equal(normalizePageResponse(command, r, 'personal').ok, false);
  }
  assert.equal(normalizePageResponse({ ...command, expect: undefined }, confirmed(), 'personal').ok, false);
});
test('wrong frames fail for snapshots and mutations', () => {
  const r = confirmed(); r.result[0].frameId = 3;
  assert.equal(normalizePageResponse(command, r, 'personal').code, 'WRONG_FRAME');
  assert.equal(normalizePageResponse({ action: 'snapshot' }, r, 'personal').code, 'WRONG_FRAME');
  assert.equal(normalizePageResponse({ action: 'snapshot', frameId: 3 }, r, 'personal').ok, true);
  assert.equal(normalizePageResponse({ action: 'snapshot', allFrames: true }, r, 'personal').ok, true);
});
