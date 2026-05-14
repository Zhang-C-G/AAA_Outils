(function () {
  function normalize(text) {
    return String(text || '').trim().toLowerCase().replace(/\s+/g, '');
  }

  function wait(ms) {
    return new Promise((resolve) => window.setTimeout(resolve, ms));
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

  function setNativeValue(el, value) {
    const tag = String(el.tagName || '').toLowerCase();
    const proto = tag === 'textarea'
      ? window.HTMLTextAreaElement?.prototype
      : tag === 'select'
        ? window.HTMLSelectElement?.prototype
        : window.HTMLInputElement?.prototype;
    const setter = proto ? Object.getOwnPropertyDescriptor(proto, 'value')?.set : null;
    if (setter) {
      setter.call(el, value);
    } else {
      el.value = value;
    }
  }

  function dispatchFieldEvents(el) {
    ['input', 'change', 'blur'].forEach((type) => {
      el.dispatchEvent(new Event(type, { bubbles: true }));
    });
  }

  function isVisible(el) {
    if (!el || !el.isConnected) return false;
    const rect = el.getBoundingClientRect();
    const style = window.getComputedStyle(el);
    return style.display !== 'none'
      && style.visibility !== 'hidden'
      && style.opacity !== '0'
      && rect.width > 0
      && rect.height > 0;
  }

  function isEditable(el) {
    const type = String(el.type || '').toLowerCase();
    return !el.disabled
      && !el.readOnly
      && !['hidden', 'button', 'submit', 'reset', 'file', 'checkbox', 'radio'].includes(type)
      && isVisible(el);
  }

  function guessLabel(input) {
    const aria = input.getAttribute('aria-label') || '';
    const placeholder = input.getAttribute('placeholder') || '';
    const name = input.getAttribute('name') || '';
    const id = input.getAttribute('id') || '';
    const datasetLabel = input.dataset?.label || '';
    const labelEl = id ? document.querySelector(`label[for="${CSS.escape(id)}"]`) : null;
    const labelText = labelEl ? labelEl.textContent : '';
    const parentText = input.closest('label, .form-item, .el-form-item, .ivu-form-item, .ant-form-item, .form-group, .form-field')?.textContent || '';
    return [aria, placeholder, name, id, datasetLabel, labelText, parentText].filter(Boolean);
  }

  function findLookupValueByCandidates(candidates, lookup) {
    for (const text of candidates) {
      const norm = normalize(text);
      if (!norm) continue;

      if (lookup.has(norm)) {
        return lookup.get(norm) || '';
      }

      for (const [key, value] of lookup.entries()) {
        if (norm.includes(key) || key.includes(norm)) {
          return value;
        }
      }
    }
    return '';
  }

  function getLookupValue(lookup, keys) {
    for (const key of keys || []) {
      const norm = normalize(key);
      if (!norm) continue;
      if (lookup.has(norm)) {
        return lookup.get(norm) || '';
      }
      for (const [lookupKey, value] of lookup.entries()) {
        if (lookupKey.includes(norm) || norm.includes(lookupKey)) {
          return value;
        }
      }
    }
    return '';
  }

  function setSelectValue(el, value) {
    const target = normalize(value);
    const options = Array.from(el.options || []);
    const matched = options.find((opt) => {
      const optText = normalize(opt.textContent);
      const optValue = normalize(opt.value);
      return optValue === target || optText === target || optText.includes(target) || target.includes(optText);
    });
    if (!matched) return false;
    setNativeValue(el, matched.value);
    dispatchFieldEvents(el);
    return true;
  }

  function setElementValue(el, value) {
    if (!el || !isEditable(el)) return false;
    const tag = String(el.tagName || '').toLowerCase();
    if (tag === 'select') {
      return setSelectValue(el, value);
    }
    setNativeValue(el, value);
    dispatchFieldEvents(el);
    return true;
  }

  function clickElement(el) {
    if (!el || !isVisible(el) || el.disabled) return false;
    el.click();
    return true;
  }

  function findButtonByText(text, root = document) {
    const target = normalize(text);
    if (!target) return null;
    const nodes = Array.from(root.querySelectorAll('button, [role="button"], .btn, .button'));
    return nodes.find((node) => normalize(node.textContent).includes(target) && isVisible(node)) || null;
  }

  function collectEditableFields(root = document) {
    return Array.from(root.querySelectorAll('input, textarea, select')).filter(isEditable);
  }

  function buildHelpers(ctx) {
    return {
      wait,
      normalize,
      clickElement,
      isVisible,
      isEditable,
      collectEditableFields,
      findButtonByText: (text, root) => findButtonByText(text, root),
      setElementValue,
      getLookupValue: (...keys) => getLookupValue(ctx.lookup, keys.flat()),
      guessLabel
    };
  }

  async function runSiteStrategies(ctx) {
    const registry = Array.isArray(globalThis.ZCGResumeSiteStrategies)
      ? globalThis.ZCGResumeSiteStrategies
      : [];
    const matched = registry.filter((strategy) => {
      try {
        return typeof strategy?.matches === 'function' && strategy.matches(ctx);
      } catch {
        return false;
      }
    });

    const touched = new Set();
    const reports = [];
    let filled = 0;

    for (const strategy of matched) {
      if (typeof strategy.execute !== 'function') continue;
      const result = await strategy.execute({
        ...ctx,
        helpers: buildHelpers(ctx)
      }) || {};
      filled += Number(result.filled || 0);
      for (const el of result.touchedElements || []) {
        if (el) touched.add(el);
      }
      reports.push({
        id: strategy.id || 'unknown',
        label: strategy.label || strategy.id || 'unknown',
        filled: Number(result.filled || 0),
        notes: Array.isArray(result.notes) ? result.notes : [],
        actions: Array.isArray(result.actions) ? result.actions : []
      });
    }

    return { matched, touched, reports, filled };
  }

  function runGenericFill(ctx, touched) {
    const touchedSet = touched || new Set();
    let filled = 0;

    for (const input of collectEditableFields(document)) {
      if (touchedSet.has(input)) continue;
      const value = findLookupValueByCandidates(guessLabel(input), ctx.lookup);
      if (!value) continue;
      if (!setElementValue(input, value)) continue;
      touchedSet.add(input);
      filled += 1;
    }

    return { filled, touched: touchedSet };
  }

  chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    if (message?.type !== 'ZCG_RESUME_FILL') return;

    (async () => {
      const ctx = {
        profile: message.profile || {},
        flatMap: message.flatMap || {},
        lookup: buildLookup(message.flatMap || {}),
        location: {
          href: window.location.href,
          hostname: window.location.hostname
        }
      };

      const strategyResult = await runSiteStrategies(ctx);
      const genericResult = runGenericFill(ctx, strategyResult.touched);

      sendResponse({
        ok: true,
        filled: strategyResult.filled + genericResult.filled,
        strategyFilled: strategyResult.filled,
        genericFilled: genericResult.filled,
        matchedStrategies: strategyResult.reports
      });
    })().catch((error) => {
      sendResponse({
        ok: false,
        error: error?.message || String(error || 'resume fill failed')
      });
    });

    return true;
  });
})();
