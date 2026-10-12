// Self-contained: Chrome serializes this function into the selected document.
export async function pageAction(command) {
  const visible = el => {
    if (!el?.isConnected || !el.getClientRects().length) return false;
    for (let node = el; node; node = node.parentElement) {
      const style = getComputedStyle(node);
      if (node.hidden || style.visibility === 'hidden' || style.visibility === 'collapse' || style.display === 'none' || parseFloat(style.opacity) === 0) return false;
    }
    return true;
  };
  const disabled = el => Boolean(el.matches(':disabled') || el.closest('[inert], [aria-disabled="true"]'));
  const select = selector => {
    if (typeof selector !== 'string' || !selector.trim()) throw new Error('A CSS selector is required');
    const matches = document.querySelectorAll(selector);
    if (matches.length !== 1) throw new Error(matches.length ? 'Ambiguous selector: multiple elements' : 'Element not found');
    return matches[0];
  };
  const uniqueSelector = el => {
    const unique = selector => document.querySelectorAll(selector).length === 1;
    if (el.id && unique(`#${CSS.escape(el.id)}`)) return `#${CSS.escape(el.id)}`;
    for (const attr of ['data-testid', 'data-test-id']) {
      const value = el.getAttribute(attr);
      const selector = value && `[${attr}="${CSS.escape(value)}"]`;
      if (selector && unique(selector)) return selector;
    }
    const parts = [];
    for (let node = el; node; node = node.parentElement) {
      let part = node.localName;
      const siblings = node.parentElement ? [...node.parentElement.children].filter(child => child.localName === node.localName) : [];
      if (siblings.length > 1) part += `:nth-of-type(${siblings.indexOf(node) + 1})`;
      parts.unshift(part);
      if (unique(parts.join(' > '))) return parts.join(' > ');
    }
    throw new Error('Could not construct a unique CSS selector');
  };
  if (command.action === 'snapshot') {
    const selector = 'a,button,input,textarea,select,[role="button"],[role="link"],[role="combobox"],[role="option"],[role="checkbox"],[role="radio"],[role="listbox"],[aria-haspopup="listbox"],[aria-haspopup="menu"],[contenteditable="true"]';
    const elements = [...document.querySelectorAll(selector)].slice(0, 500).map((el, index) => {
      const labelledBy = (el.getAttribute('aria-labelledby') || '').split(/\s+/).filter(Boolean).map(id => document.getElementById(id)?.innerText || '').filter(Boolean).join(' ').trim();
      return {
        index, tag: el.localName, role: el.getAttribute('role') || undefined,
        text: (el.innerText || el.getAttribute('aria-label') || el.getAttribute('placeholder') || '').trim().slice(0, 180),
        selector: uniqueSelector(el), href: el.getAttribute('href') || undefined,
        type: el.getAttribute('type') || undefined, ariaLabel: el.getAttribute('aria-label') || undefined,
        label: labelledBy || el.labels?.[0]?.innerText?.trim() || undefined,
        checked: typeof el.checked === 'boolean' ? el.checked : el.getAttribute('aria-checked') === 'true' ? true : el.getAttribute('aria-checked') === 'false' ? false : undefined,
        disabled: disabled(el), visible: visible(el),
      };
    });
    return { url: location.href, title: document.title, visibilityState: document.visibilityState, documentFocused: document.hasFocus(), text: (document.body?.innerText || '').slice(0, command.maxText || 30000), elements };
  }
  if (!['click', 'fill', 'press'].includes(command.action)) throw new Error('Unsupported page action');
  if (command.action === 'press' && !['Enter', 'Tab', 'Escape', 'ArrowUp', 'ArrowDown', 'Space'].includes(command.key)) throw new Error('Unsupported key');
  // Tab requires browser default focus traversal, unavailable through DOM dispatch.
  if (command.action === 'press' && command.key === 'Tab') throw new Error('Tab requires browser input; unsupported by this DOM backend');
  const el = select(command.selector);
  if (!(el instanceof HTMLElement)) throw new Error('Target must be an HTMLElement');
  if (disabled(el)) throw new Error('Target is disabled');
  if (!visible(el)) throw new Error('Target is hidden or not actionable');
  if (command.inputMode !== undefined && !['activation', 'pointer-sequence'].includes(command.inputMode)) throw new Error('Unsupported inputMode');
  if (command.inputMode === 'pointer-sequence' && command.action !== 'click') throw new Error('pointer-sequence is supported only for click');
  const timeoutMs = command.timeoutMs ?? 1500;
  if (!Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 5000) throw new Error('timeoutMs must be between 1 and 5000');
  const expectation = command.expect;
  if (expectation && (!['visible', 'hidden', 'checked', 'unchecked'].includes(expectation.state) || typeof expectation.selector !== 'string')) throw new Error('Invalid expectation');
  const observe = () => {
    if (!expectation) return false;
    const matches = document.querySelectorAll(expectation.selector);
    if (matches.length > 1) throw new Error('Ambiguous expectation selector');
    const target = matches[0];
    if (expectation.state === 'hidden') return !target || !visible(target);
    if (!target) return false;
    if (expectation.state === 'visible') return visible(target);
    const ariaChecked = target.getAttribute('aria-checked');
    if (typeof target.checked !== 'boolean' && !['true', 'false'].includes(ariaChecked)) return false;
    const checked = typeof target.checked === 'boolean' ? target.checked : ariaChecked === 'true';
    return expectation.state === 'checked' ? checked : !checked;
  };
  const initiallySatisfied = observe(); // Validates selectors before any mutation.
  if (initiallySatisfied) throw new Error('Expectation already satisfied; no action sent');
  const urlBefore = location.href;
  const started = Date.now();
  let method = 'dom-activation', canceled = false;
  const result = () => ({ action: command.action, selector: command.selector, method, canceled, verified: false, outcome: 'unverified', elapsedMs: Date.now() - started, visibilityState: document.visibilityState, documentFocused: document.hasFocus() });
  const dispatchKey = type => {
    const keyCode = ({ Enter: 13, Escape: 27, ArrowUp: 38, ArrowDown: 40, Space: 32 })[command.key];
    const event = new KeyboardEvent(type, { key: command.key === 'Space' ? ' ' : command.key, code: command.key, bubbles: true, cancelable: true });
    for (const property of ['keyCode', 'which']) Object.defineProperty(event, property, { get: () => keyCode });
    if (type === 'keypress') Object.defineProperty(event, 'charCode', { get: () => keyCode });
    return el.dispatchEvent(event);
  };
  try {
    if (command.action === 'click') {
      if (command.inputMode === 'pointer-sequence') {
        method = 'dom-pointer-sequence';
        // Explicit alternative, NOT a retry after activation. Events remain synthetic.
        const rect = el.getBoundingClientRect();
        const init = { bubbles: true, cancelable: true, composed: true, button: 0, clientX: rect.x + rect.width / 2, clientY: rect.y + rect.height / 2 };
        let allowed = true;
        let clicks = 0;
        const countClick = () => clicks++;
        el.addEventListener('click', countClick, true);
        try {
          for (const type of ['pointerdown', 'mousedown', 'pointerup', 'mouseup']) {
            if (!el.isConnected) throw new Error('Target detached during input');
            const event = type.startsWith('pointer') ? new PointerEvent(type, { ...init, pointerId: 1, pointerType: 'mouse', isPrimary: true, buttons: type.endsWith('down') ? 1 : 0 }) : new MouseEvent(type, { ...init, buttons: type.endsWith('down') ? 1 : 0 });
            allowed = el.dispatchEvent(event) && allowed;
          }
          canceled = !allowed;
          if (allowed && clicks === 0 && el.isConnected && !disabled(el)) el.click();
        } finally { el.removeEventListener('click', countClick, true); }
      } else el.click();
    } else if (command.action === 'fill') {
      method = 'dom-value-setter';
      if (!('value' in el) || el.readOnly || typeof command.value !== 'string') throw new Error('Target is not fillable');
      const setter = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(el), 'value')?.set;
      if (setter) setter.call(el, command.value); else el.value = command.value;
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    } else {
      method = 'dom-key-events';
      el.focus({ preventScroll: true });
      if (document.activeElement !== el) throw new Error('Target did not receive document focus');
      let clicks = 0;
      const countClick = () => clicks++;
      el.addEventListener('click', countClick, true);
      try {
        let allowed = dispatchKey('keydown');
        if (allowed && ['Enter', 'Space'].includes(command.key)) allowed = dispatchKey('keypress');
        canceled = !allowed;
        const button = el.localName === 'button' || el.localName === 'input' && ['button', 'submit', 'reset', 'checkbox', 'radio'].includes(el.type);
        const activate = () => {
          if (allowed && button && clicks === 0 && el.isConnected && !disabled(el)) { method = 'dom-key-events+activation'; el.click(); }
        };
        if (command.key === 'Enter') activate();
        const upAllowed = dispatchKey('keyup');
        if (command.key === 'Space') { allowed = allowed && upAllowed; canceled = !allowed; activate(); }
      } finally { el.removeEventListener('click', countClick, true); }
      // Input Enter is dispatch-only; never synthesize implicit form submission.
    }
  } catch (error) {
    // Once input has started, even exceptions can follow an applied side effect.
    return { ...result(), outcome: 'uncertain', uncertain: true, code: 'ACTION_EXCEPTION', error: String(error.message || error).slice(0, 300) };
  }
  if (!expectation) return result();
  const deadline = started + timeoutMs;
  while (true) {
    try {
      if (location.href !== urlBefore) return { ...result(), outcome: 'uncertain', uncertain: true, code: 'DOCUMENT_CHANGED' };
      if (observe()) return { ...result(), outcome: 'verified', verified: true, postcondition: { selector: expectation.selector, state: expectation.state, before: false, after: true } };
    } catch (error) { return { ...result(), outcome: 'uncertain', uncertain: true, code: 'OBSERVATION_FAILED', error: String(error.message).slice(0, 300) }; }
    if (Date.now() >= deadline) return { ...result(), outcome: 'uncertain', uncertain: true, code: 'POSTCONDITION_TIMEOUT' };
    // No requestAnimationFrame: hidden/background documents may not get frames.
    await new Promise(resolve => setTimeout(resolve, Math.min(25, deadline - Date.now())));
  }
}
