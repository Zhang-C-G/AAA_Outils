(function () {
  function normalize(text) {
    return String(text || '').trim().toLowerCase().replace(/\s+/g, '');
  }

  function buildLookup(flatMap) {
    const lookup = new Map();
    for (const [key, value] of Object.entries(flatMap || {})) {
      const norm = normalize(key);
      if (!norm || lookup.has(norm)) continue;
      lookup.set(norm, String(value || ''));
    }
    return lookup;
  }

  function guessLabel(input) {
    const aria = input.getAttribute('aria-label') || '';
    const placeholder = input.getAttribute('placeholder') || '';
    const name = input.getAttribute('name') || '';
    const id = input.getAttribute('id') || '';
    const labelEl = id ? document.querySelector(`label[for="${CSS.escape(id)}"]`) : null;
    const labelText = labelEl ? labelEl.textContent : '';
    const parentText = input.closest('label, .form-item, .el-form-item, .ivu-form-item, .ant-form-item')?.textContent || '';
    return [aria, placeholder, name, id, labelText, parentText].filter(Boolean);
  }

  function matchValue(input, lookup) {
    const candidates = guessLabel(input);
    for (const text of candidates) {
      const norm = normalize(text);
      if (!norm) continue;

      for (const [key, value] of lookup.entries()) {
        if (norm.includes(key) || key.includes(norm)) {
          return value;
        }
      }
    }
    return '';
  }

  function setInputValue(el, value) {
    const tag = el.tagName.toLowerCase();
    if (tag === 'select') {
      const options = Array.from(el.options || []);
      const matched = options.find((opt) => normalize(opt.textContent).includes(normalize(value)) || normalize(opt.value) === normalize(value));
      if (matched) {
        el.value = matched.value;
      }
    } else {
      el.value = value;
    }
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }

  chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    if (message?.type !== 'ZCG_RESUME_FILL') return;

    const lookup = buildLookup(message.flatMap || {});
    const inputs = Array.from(document.querySelectorAll('input, textarea, select'))
      .filter((el) => !el.disabled && !el.readOnly && ['hidden', 'button', 'submit', 'reset', 'file', 'checkbox', 'radio'].indexOf(String(el.type || '').toLowerCase()) === -1);

    let filled = 0;
    for (const input of inputs) {
      const value = matchValue(input, lookup);
      if (!value) continue;
      setInputValue(input, value);
      filled += 1;
    }

    sendResponse({ ok: true, filled });
    return true;
  });
})();
