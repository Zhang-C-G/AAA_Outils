const selectInstances = new Map();

let hostEl = null;
let openInstance = null;

function getHost() {
  if (hostEl && document.body.contains(hostEl)) {
    return hostEl;
  }
  hostEl = document.createElement('div');
  hostEl.className = 'top-layer-select-host';
  document.body.appendChild(hostEl);
  return hostEl;
}

function getSelectedOption(select) {
  const options = Array.from(select.options || []);
  const selected = options.find((opt) => opt.value === select.value);
  return selected || options[0] || null;
}

function syncButtonLabel(instance) {
  const { select, button, placeholder } = instance;
  const selected = getSelectedOption(select);
  const text = String(selected?.textContent || '').trim() || placeholder;
  button.textContent = text;
  button.classList.toggle('is-placeholder', !selected);
  button.title = text;
}

function closeTopLayerSelect(instance = openInstance) {
  if (!instance) {
    return;
  }
  instance.menu.hidden = true;
  instance.button.classList.remove('open');
  instance.button.setAttribute('aria-expanded', 'false');
  if (openInstance === instance) {
    openInstance = null;
  }
}

function positionMenu(instance) {
  const rect = instance.button.getBoundingClientRect();
  const menu = instance.menu;
  const host = getHost();

  menu.style.minWidth = `${Math.max(rect.width, 220)}px`;
  menu.style.maxWidth = `${Math.max(rect.width, 220)}px`;
  menu.hidden = false;

  const menuRect = menu.getBoundingClientRect();
  const gap = 6;
  const fitsBelow = rect.bottom + gap + menuRect.height <= window.innerHeight - 10;
  const top = fitsBelow
    ? Math.min(window.innerHeight - menuRect.height - 10, rect.bottom + gap)
    : Math.max(10, rect.top - gap - menuRect.height);
  const left = Math.min(
    window.innerWidth - menuRect.width - 10,
    Math.max(10, rect.left)
  );

  host.style.pointerEvents = 'none';
  menu.style.top = `${top}px`;
  menu.style.left = `${left}px`;
}

function rebuildMenu(instance) {
  const { select, menu } = instance;
  menu.innerHTML = '';

  const options = Array.from(select.options || []);
  if (!options.length) {
    const empty = document.createElement('div');
    empty.className = 'top-layer-select-empty';
    empty.textContent = '暂无可选项';
    menu.appendChild(empty);
    return;
  }

  for (const option of options) {
    const item = document.createElement('button');
    item.type = 'button';
    item.className = 'top-layer-select-option';
    item.textContent = String(option.textContent || '').trim();
    item.dataset.value = option.value;
    item.classList.toggle('selected', option.value === select.value);
    item.disabled = option.disabled;
    item.onclick = () => {
      if (option.disabled) {
        return;
      }
      select.value = option.value;
      select.dispatchEvent(new Event('change', { bubbles: true }));
      select.dispatchEvent(new Event('input', { bubbles: true }));
      syncButtonLabel(instance);
      closeTopLayerSelect(instance);
      instance.button.focus();
    };
    menu.appendChild(item);
  }
}

function openTopLayerSelect(instance) {
  if (openInstance && openInstance !== instance) {
    closeTopLayerSelect(openInstance);
  }

  rebuildMenu(instance);
  syncButtonLabel(instance);
  positionMenu(instance);
  instance.button.classList.add('open');
  instance.button.setAttribute('aria-expanded', 'true');
  openInstance = instance;
}

function bindGlobalCloseHandlers() {
  if (window.__topLayerSelectBound === true) {
    return;
  }
  window.__topLayerSelectBound = true;

  document.addEventListener('pointerdown', (event) => {
    if (!openInstance) return;
    const target = event.target;
    if (openInstance.button.contains(target) || openInstance.menu.contains(target)) {
      return;
    }
    closeTopLayerSelect(openInstance);
  }, true);

  document.addEventListener('keydown', (event) => {
    if (!openInstance) return;
    if (event.key === 'Escape') {
      event.preventDefault();
      const current = openInstance;
      closeTopLayerSelect(current);
      current.button.focus();
    }
  }, true);

  window.addEventListener('resize', () => {
    if (openInstance) {
      positionMenu(openInstance);
    }
  });

  window.addEventListener('scroll', () => {
    if (openInstance) {
      positionMenu(openInstance);
    }
  }, true);
}

export function refreshTopLayerSelect(selectOrId) {
  const select = typeof selectOrId === 'string'
    ? document.getElementById(selectOrId)
    : selectOrId;
  if (!select) {
    return;
  }
  const instance = selectInstances.get(select);
  if (!instance) {
    return;
  }
  syncButtonLabel(instance);
  if (openInstance === instance) {
    rebuildMenu(instance);
    positionMenu(instance);
  }
}

export function enhanceTopLayerSelect(selectOrId, options = {}) {
  const select = typeof selectOrId === 'string'
    ? document.getElementById(selectOrId)
    : selectOrId;
  if (!select) {
    return null;
  }
  if (selectInstances.has(select)) {
    refreshTopLayerSelect(select);
    return selectInstances.get(select);
  }

  bindGlobalCloseHandlers();

  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'top-layer-select-button';
  button.setAttribute('aria-haspopup', 'listbox');
  button.setAttribute('aria-expanded', 'false');

  const menu = document.createElement('div');
  menu.className = 'top-layer-select-menu';
  menu.hidden = true;

  getHost().appendChild(menu);
  select.classList.add('top-layer-select-native');
  select.tabIndex = -1;
  select.setAttribute('aria-hidden', 'true');
  select.insertAdjacentElement('afterend', button);

  const instance = {
    select,
    button,
    menu,
    placeholder: String(options.placeholder || '请选择')
  };
  selectInstances.set(select, instance);

  button.onclick = () => {
    if (openInstance === instance) {
      closeTopLayerSelect(instance);
      return;
    }
    openTopLayerSelect(instance);
  };

  button.onkeydown = (event) => {
    if (event.key === 'Enter' || event.key === ' ' || event.key === 'ArrowDown') {
      event.preventDefault();
      openTopLayerSelect(instance);
    }
  };

  select.addEventListener('change', () => syncButtonLabel(instance));

  const observer = new MutationObserver(() => refreshTopLayerSelect(select));
  observer.observe(select, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ['value', 'label', 'disabled', 'selected']
  });

  syncButtonLabel(instance);
  return instance;
}
