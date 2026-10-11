export function pageAction(command) {
  const allowedKeys = ['Enter', 'Tab', 'Escape', 'ArrowUp', 'ArrowDown', 'Space'];
  const visible = el => {
    if (!el.isConnected || !el.getClientRects().length) return false;
    const style = getComputedStyle(el);
    return style.visibility !== 'hidden' && style.display !== 'none' && Number(style.opacity) !== 0;
  };
  const uniqueSelector = el => {
    const unique = selector => {
      try { return document.querySelectorAll(selector).length === 1 && document.querySelector(selector) === el; }
      catch { return false; }
    };
    if (el.id) {
      const selector = `#${CSS.escape(el.id)}`;
      if (unique(selector)) return selector;
    }
    for (const attr of ['data-testid', 'data-test-id']) {
      const value = el.getAttribute(attr);
      if (value) {
        const selector = `[${attr}="${CSS.escape(value)}"]`;
        if (unique(selector)) return selector;
      }
    }
    const parts = [];
    for (let node = el; node && node.nodeType === 1; node = node.parentElement) {
      let part = node.localName;
      const siblings = node.parentElement ? [...node.parentElement.children].filter(child => child.localName === node.localName) : [];
      if (siblings.length > 1) part += `:nth-of-type(${siblings.indexOf(node) + 1})`;
      parts.unshift(part);
      const selector = parts.join(' > ');
      if (unique(selector)) return selector;
    }
    throw new Error('Could not construct a unique CSS selector');
  };
  if (command.action === 'snapshot') {
    const selector = 'a,button,input,textarea,select,[role="button"],[role="link"],[role="combobox"],[role="option"],[role="checkbox"],[role="radio"],[role="listbox"],[aria-haspopup="listbox"],[aria-haspopup="menu"],[contenteditable="true"]';
    const elements = [...document.querySelectorAll(selector)].slice(0, 500).map((el, index) => {
      const labelIds = (el.getAttribute('aria-labelledby') || '').split(/\s+/).filter(Boolean);
      const labelledBy = labelIds.map(id => document.getElementById(id)?.innerText || '').filter(Boolean).join(' ').trim();
      return {
        index, tag: el.localName, role: el.getAttribute('role') || undefined,
        text: (el.innerText || el.getAttribute('aria-label') || el.getAttribute('placeholder') || '').trim().slice(0, 180),
        selector: uniqueSelector(el), href: el.getAttribute('href') || undefined,
        type: el.getAttribute('type') || undefined,
        ariaLabel: el.getAttribute('aria-label') || undefined,
        label: labelledBy || el.labels?.[0]?.innerText?.trim() || undefined,
        checked: typeof el.checked === 'boolean' ? el.checked : el.getAttribute('aria-checked') === 'true' ? true : el.getAttribute('aria-checked') === 'false' ? false : undefined,
        disabled: Boolean(el.disabled || el.getAttribute('aria-disabled') === 'true'),
        visible: visible(el),
      };
    });
    return { url: location.href, title: document.title, text: (document.body?.innerText || '').slice(0, command.maxText || 30000), elements };
  }
  if (command.action === 'press' && !allowedKeys.includes(command.key)) throw new Error('Unsupported key');
  const el = command.selector ? document.querySelector(command.selector) : undefined;
  if (!el) throw new Error('Element not found; provide a CSS selector from the current page');
  if (command.action === 'click') { el.click(); return { clicked: command.selector }; }
  if (command.action === 'fill') {
    if (!('value' in el)) throw new Error('Element is not fillable');
    const setter = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(el), 'value')?.set;
    if (setter) setter.call(el, command.value); else el.value = command.value;
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
    return { filled: command.selector };
  }
  if (command.action === 'press') {
    if (!allowedKeys.includes(command.key)) throw new Error('Unsupported key');
    if (!(el instanceof HTMLElement) || !document.documentElement.contains(el)) throw new Error('Target must be an HTMLElement in this document');
    el.focus({ preventScroll: true });
    const key = command.key === 'Space' ? ' ' : command.key;
    const keyCode = ({ Enter: 13, Tab: 9, Escape: 27, ArrowUp: 38, ArrowDown: 40, Space: 32 })[command.key];
    const dispatchKeyboardEvent = (type, fields) => {
      const event = new KeyboardEvent(type, { key, code: command.key === 'Space' ? 'Space' : command.key, bubbles: true, cancelable: true, ...fields });
      for (const property of ['keyCode', 'which']) Object.defineProperty(event, property, { get: () => keyCode });
      if (type === 'keypress') Object.defineProperty(event, 'charCode', { get: () => keyCode });
      el.dispatchEvent(event);
      return event;
    };
    dispatchKeyboardEvent('keydown');
    if (['Enter', 'Space'].includes(command.key)) dispatchKeyboardEvent('keypress');
    dispatchKeyboardEvent('keyup');
    return { pressed: command.key, selector: command.selector };
  }
  throw new Error(`Unsupported page action: ${command.action}`);
}
