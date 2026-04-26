import { state, fallbackHotkeyDefs, byId, setDirty, escapeHtml, toInt, isTruthy, validateHotkeyText, toast, api } from './app-common.js';

const KEY_TO_AHK = {
  escape: 'Esc', esc: 'Esc',
  enter: 'Enter', return: 'Enter',
  tab: 'Tab',
  space: 'Space',
  up: 'Up', down: 'Down', left: 'Left', right: 'Right',
  home: 'Home', end: 'End',
  pageup: 'PgUp', pgup: 'PgUp',
  pagedown: 'PgDn', pgdn: 'PgDn',
  insert: 'Ins', ins: 'Ins',
  delete: 'Del', del: 'Del'
};

const AHK_TO_KEY = {
  esc: 'Esc',
  enter: 'Enter',
  tab: 'Tab',
  space: 'Space',
  up: 'Up', down: 'Down', left: 'Left', right: 'Right',
  home: 'Home', end: 'End',
  pgup: 'PgUp', pgdn: 'PgDn',
  ins: 'Ins', del: 'Del'
};

let autoSaveTimer = 0;
let autoSaveInFlight = false;
let autoSaveQueued = false;
let activeHotkeyRecorder = null;
let tabClickTimer = 0;
let draggingShortcutRowIndex = -1;
const HIDDEN_SHORTCUT_CATEGORY_IDS = new Set(['prompts', 'quick_fields']);

function saveShortcutsNowOnStructureChange(message) {
  return saveShortcuts({ silent: true }).catch((error) => {
    toast(message || `保存失败: ${error.message}`);
  });
}

async function persistSelectedCategory(categoryId) {
  const nextId = String(categoryId || '').trim() || 'fields';
  state.app ||= {};
  if (state.app.shortcuts_selected_category === nextId) {
    return;
  }
  state.app.shortcuts_selected_category = nextId;
  await api('/api/app/shortcuts-category', {
    method: 'POST',
    body: JSON.stringify({ shortcuts_selected_category: nextId })
  });
}

function ahkToFriendly(hk) {
  const raw = String(hk || '').trim();
  if (!raw) return '';

  let i = 0;
  const mods = [];
  while (i < raw.length) {
    const ch = raw[i];
    if (ch === '!') mods.push('Alt');
    else if (ch === '^') mods.push('Ctrl');
    else if (ch === '+') mods.push('Shift');
    else if (ch === '#') mods.push('Win');
    else break;
    i += 1;
  }

  const keyRaw = raw.slice(i);
  if (!keyRaw) return raw;
  let key = AHK_TO_KEY[keyRaw.toLowerCase()] || keyRaw;
  if (/^[a-z0-9]$/i.test(key)) key = key.toUpperCase();
  return [...mods, key].join('+');
}

function friendlyToAhk(hk) {
  const txt = String(hk || '').trim();
  if (!txt) return '';
  const noSpace = txt.replace(/\s+/g, '');

  if (/^[!^+#]/.test(noSpace)) {
    return validateHotkeyText(noSpace) ? noSpace : '';
  }

  const parts = noSpace.split('+').filter(Boolean);
  if (!parts.length) return '';

  let mods = '';
  let key = '';
  for (const part of parts) {
    const low = part.toLowerCase();
    if (low === 'alt' || low === 'option') {
      if (!mods.includes('!')) mods += '!';
      continue;
    }
    if (low === 'ctrl' || low === 'control') {
      if (!mods.includes('^')) mods += '^';
      continue;
    }
    if (low === 'shift') {
      if (!mods.includes('+')) mods += '+';
      continue;
    }
    if (low === 'win' || low === 'windows' || low === 'meta') {
      if (!mods.includes('#')) mods += '#';
      continue;
    }
    key = part;
  }

  if (!key) return '';

  const mapped = KEY_TO_AHK[key.toLowerCase()];
  if (mapped) {
    key = mapped;
  } else if (/^f([1-9]|1[0-9]|2[0-4])$/i.test(key)) {
    key = key.toUpperCase();
  } else if (/^[a-z0-9]$/i.test(key)) {
    key = key.toLowerCase();
  } else {
    return '';
  }

  const ahk = mods + key;
  return validateHotkeyText(ahk) ? ahk : '';
}

function eventKeyToFriendly(event) {
  const raw = String(event?.key || '').trim();
  if (!raw) return '';
  const low = raw.toLowerCase();
  if (low === 'control' || low === 'shift' || low === 'alt' || low === 'meta') {
    return '';
  }
  if (/^f([1-9]|1[0-9]|2[0-4])$/i.test(raw)) {
    return raw.toUpperCase();
  }
  if (KEY_TO_AHK[low]) {
    return AHK_TO_KEY[KEY_TO_AHK[low].toLowerCase()] || KEY_TO_AHK[low];
  }
  if (/^[a-z0-9]$/i.test(raw)) {
    return raw.toUpperCase();
  }
  return '';
}

function isAllowedSingleHotkeyKey(key) {
  const txt = String(key || '').trim();
  if (!txt) return false;
  return /^(F([1-9]|1[0-9]|2[0-4])|Esc|Enter|Tab|Space|Up|Down|Left|Right|Home|End|PgUp|PgDn|Ins|Del)$/i.test(txt);
}

function buildAhkFromKeyboardEvent(event) {
  const key = eventKeyToFriendly(event);
  if (!key) {
    return '';
  }

  const mods = [];
  if (event.ctrlKey) mods.push('Ctrl');
  if (event.altKey) mods.push('Alt');
  if (event.shiftKey) mods.push('Shift');
  if (event.metaKey) mods.push('Win');

  if (!mods.length && !isAllowedSingleHotkeyKey(key)) {
    return '';
  }

  return friendlyToAhk([...mods, key].join('+'));
}

function stopHotkeyRecording(commit = false, nextValue = '') {
  if (!activeHotkeyRecorder) return;
  const { input, hotkeyId, previousValue } = activeHotkeyRecorder;
  input.classList.remove('hotkey-recording', 'hotkey-recorded');

  if (commit && nextValue) {
    const displayValue = ahkToFriendly(nextValue);
    state.hotkeys[hotkeyId] = nextValue;
    input.value = displayValue;
    input.dataset.value = displayValue;
    input.classList.add('hotkey-recorded');
    window.setTimeout(() => input.classList.remove('hotkey-recorded'), 900);
    setDirty(true, 'shortcuts');
    scheduleAutoSave(true);
    toast(`录入成功：${displayValue}`);
  } else {
    input.value = input.dataset.value || ahkToFriendly(previousValue);
  }

  activeHotkeyRecorder = null;
}

function startHotkeyRecording(input, hotkeyId) {
  if (!input) return;
  if (activeHotkeyRecorder?.input === input) return;
  stopHotkeyRecording(false);

  activeHotkeyRecorder = {
    input,
    hotkeyId,
    previousValue: state.hotkeys[hotkeyId] ?? ''
  };

  input.classList.remove('hotkey-recorded');
  input.classList.add('hotkey-recording');
  input.value = '录入中...';
  input.focus();
  input.select();
}

function scheduleAutoSave(immediate = false) {
  if (autoSaveTimer) {
    clearTimeout(autoSaveTimer);
    autoSaveTimer = 0;
  }
  autoSaveTimer = window.setTimeout(() => {
    void runAutoSave();
  }, immediate ? 80 : 700);
}

async function runAutoSave() {
  if (autoSaveInFlight) {
    autoSaveQueued = true;
    return;
  }

  autoSaveInFlight = true;
  try {
    await saveShortcuts({ silent: true });
  } catch {
    // Keep UI editable; user can still click manual save for explicit feedback.
  } finally {
    autoSaveInFlight = false;
    if (autoSaveQueued) {
      autoSaveQueued = false;
      scheduleAutoSave(true);
    }
  }
}

function buildSanitizedData() {
  const out = {};
  for (const cat of state.categories) {
    const catId = String(cat.id || '').trim();
    if (!catId) continue;
    const rows = Array.isArray(state.data[catId]) ? state.data[catId] : [];
    out[catId] = rows
      .map((r) => ({
        key: String(r?.key || '').trim(),
        value: String(r?.value || ''),
        usage: Number.isFinite(Number(r?.usage)) ? Math.max(0, Math.trunc(Number(r.usage))) : 0
      }))
      .filter((r) => r.key !== '');
  }
  return out;
}

function getVisibleShortcutCategories() {
  return state.categories.filter((cat) => !HIDDEN_SHORTCUT_CATEGORY_IDS.has(String(cat?.id || '').trim()));
}

function ensureVisibleSelectedCategory() {
  const visible = getVisibleShortcutCategories();
  if (!visible.length) {
    state.selectedCategoryId = null;
    return;
  }

  if (!visible.find((cat) => cat.id === state.selectedCategoryId)) {
    state.selectedCategoryId = visible[0].id;
  }
}

function renderTabs() {
  const tabsEl = byId('tabs');
  tabsEl.innerHTML = '';
  ensureVisibleSelectedCategory();

  for (const cat of getVisibleShortcutCategories()) {
    const tab = document.createElement('div');
    tab.className = `tab ${cat.id === state.selectedCategoryId ? 'active' : ''}`;
    tab.textContent = cat.name;
    tab.draggable = true;

    tab.onclick = () => {
      if (tab.classList.contains('editing')) {
        return;
      }
      if (tabClickTimer) {
        clearTimeout(tabClickTimer);
      }
      tabClickTimer = window.setTimeout(() => {
        tabClickTimer = 0;
        if (state.selectedCategoryId === cat.id) {
          return;
        }
        state.selectedCategoryId = cat.id;
        void persistSelectedCategory(state.selectedCategoryId);
        renderTabs();
        renderRows();
      }, 220);
    };

    tab.ondblclick = () => {
      if (tabClickTimer) {
        clearTimeout(tabClickTimer);
        tabClickTimer = 0;
      }
      state.selectedCategoryId = cat.id;
      void persistSelectedCategory(state.selectedCategoryId);
      tab.classList.add('active');
      renderRows();
      const rect = tab.getBoundingClientRect();
      const input = document.createElement('input');
      let canceled = false;
      tab.classList.add('editing');
      tab.style.width = `${Math.ceil(rect.width)}px`;
      tab.style.height = `${Math.ceil(rect.height)}px`;
      input.value = cat.name;
      input.className = 'tab-inline-input';
      tab.innerHTML = '';
      tab.appendChild(input);
      input.focus();
      input.setSelectionRange(input.value.length, input.value.length);
      const commit = () => {
        if (canceled) {
          return;
        }
        const name = input.value.trim();
        tab.classList.remove('editing');
        tab.style.width = '';
        tab.style.height = '';
        if (name && name !== cat.name) {
          cat.name = name;
          setDirty(true, 'shortcuts');
          void saveShortcutsNowOnStructureChange('栏目改名保存失败');
        }
        renderTabs();
      };
      input.onblur = commit;
      input.onkeydown = (e) => {
        if (e.key === 'Enter') {
          e.preventDefault();
          commit();
          return;
        }
        if (e.key === 'Escape') {
          e.preventDefault();
          canceled = true;
          tab.classList.remove('editing');
          tab.style.width = '';
          tab.style.height = '';
          renderTabs();
        }
      };
    };

    tab.ondragstart = (e) => {
      tab.classList.add('dragging');
      e.dataTransfer.effectAllowed = 'move';
      e.dataTransfer.setData('text/plain', cat.id);
    };
    tab.ondragend = () => tab.classList.remove('dragging');
    tab.ondragover = (e) => e.preventDefault();
    tab.ondrop = (e) => {
      e.preventDefault();
      const fromId = e.dataTransfer.getData('text/plain');
      if (!fromId || fromId === cat.id) return;
      const from = state.categories.findIndex(c => c.id === fromId);
      const to = state.categories.findIndex(c => c.id === cat.id);
      if (from < 0 || to < 0) return;
      const [moving] = state.categories.splice(from, 1);
      state.categories.splice(to, 0, moving);
      setDirty(true, 'shortcuts');
      renderTabs();
      void saveShortcutsNowOnStructureChange('栏目排序保存失败');
    };

    tabsEl.appendChild(tab);
  }
}

function renderRows() {
  const rowsEl = byId('rows');
  rowsEl.innerHTML = '';
  const catId = state.selectedCategoryId;
  const rows = state.data[catId] || [];
  const allowDragReorder = catId === 'quick_fields';

  rows.forEach((row, idx) => {
    const tr = document.createElement('tr');
    tr.className = allowDragReorder ? 'sortable-row' : '';
    tr.draggable = allowDragReorder;
    tr.innerHTML = `
      <td><input type="text" value="${escapeHtml(row.key || '')}" data-k="key" /></td>
      <td><textarea data-k="value">${escapeHtml(row.value || '')}</textarea></td>
      <td>${row.usage ?? 0}</td>
      <td><button class="btn danger" data-act="delete">删</button></td>
    `;
    tr.querySelector('[data-k="key"]').oninput = (e) => {
      row.key = e.target.value;
      setDirty(true, 'shortcuts');
      scheduleAutoSave();
    };
    tr.querySelector('[data-k="value"]').oninput = (e) => {
      row.value = e.target.value;
      setDirty(true, 'shortcuts');
      scheduleAutoSave();
    };
    tr.querySelector('[data-act="delete"]').onclick = () => {
      rows.splice(idx, 1);
      setDirty(true, 'shortcuts');
      renderRows();
      scheduleAutoSave(true);
    };
    if (allowDragReorder) {
      tr.addEventListener('dragstart', (event) => {
        draggingShortcutRowIndex = idx;
        tr.classList.add('dragging');
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', String(idx));
      });
      tr.addEventListener('dragend', () => {
        draggingShortcutRowIndex = -1;
        tr.classList.remove('dragging');
        for (const node of rowsEl.querySelectorAll('.drag-target')) {
          node.classList.remove('drag-target');
        }
      });
      tr.addEventListener('dragover', (event) => {
        event.preventDefault();
        if (draggingShortcutRowIndex < 0 || draggingShortcutRowIndex === idx) return;
        tr.classList.add('drag-target');
      });
      tr.addEventListener('dragleave', () => {
        tr.classList.remove('drag-target');
      });
      tr.addEventListener('drop', (event) => {
        event.preventDefault();
        tr.classList.remove('drag-target');
        const from = Number.parseInt(event.dataTransfer.getData('text/plain'), 10);
        const to = idx;
        if (!Number.isInteger(from) || from < 0 || from === to || from >= rows.length) return;
        const [moving] = rows.splice(from, 1);
        rows.splice(to, 0, moving);
        setDirty(true, 'shortcuts');
        renderRows();
        scheduleAutoSave(true);
      });
    }
    rowsEl.appendChild(tr);
  });
}

function renderHotkeys() {
  const hotkeysEl = byId('hotkeys');
  hotkeysEl.innerHTML = '';
  const defs = state.hotkeyDefs.length ? state.hotkeyDefs : fallbackHotkeyDefs;

  const grouped = new Map();
  for (const def of defs) {
    const group = String(def.group || 'shared');
    const groupLabel = String(def.group_label || (group === 'assistant' ? '截图问答特有' : '公共快捷键'));
    if (!grouped.has(group)) {
      grouped.set(group, { label: groupLabel, items: [] });
    }
    grouped.get(group).items.push(def);
  }

  const groupOrder = ['shared', 'assistant', 'notes_display'];
  const entries = [...grouped.entries()].sort((a, b) => {
    const ia = groupOrder.indexOf(a[0]);
    const ib = groupOrder.indexOf(b[0]);
    const wa = ia < 0 ? 999 : ia;
    const wb = ib < 0 ? 999 : ib;
    return wa - wb;
  });

  for (const [groupId, groupData] of entries) {
    const block = document.createElement('div');
    block.className = 'hotkey-group';

    const title = document.createElement('h3');
    title.className = 'hotkey-group-title';
    title.textContent = groupData.label;
    block.appendChild(title);

    const desc = document.createElement('div');
    desc.className = 'hotkey-group-desc';
    desc.textContent = groupId === 'assistant'
      ? '只作用于截图问答模块'
      : groupId === 'notes_display'
        ? '只作用于笔记显示模块'
      : '所有模块共享可用';
    block.appendChild(desc);

    const grid = document.createElement('div');
    grid.className = 'grid';
    for (const def of groupData.items) {
      const id = def.id;
      const rawValue = state.hotkeys[id] ?? def.default ?? '';
      const displayValue = ahkToFriendly(rawValue);
      const displayPlaceholder = ahkToFriendly(def.default || '');
      const wrap = document.createElement('label');
      wrap.innerHTML = `
        <span>${escapeHtml(def.label || id)}</span>
        <input type="text" value="${escapeHtml(displayValue)}" placeholder="${escapeHtml(displayPlaceholder)}" readonly />
      `;
      const input = wrap.querySelector('input');
      input.dataset.value = displayValue;
      input.title = '点击后直接按组合键录入';
      input.onfocus = () => startHotkeyRecording(input, id);
      input.onclick = () => startHotkeyRecording(input, id);
      input.onblur = () => {
        window.setTimeout(() => {
          if (activeHotkeyRecorder?.input === input) {
            stopHotkeyRecording(false);
          }
        }, 30);
      };
      input.onkeydown = (e) => {
        if (activeHotkeyRecorder?.input !== input) {
          startHotkeyRecording(input, id);
        }
        e.preventDefault();
        e.stopPropagation();

        if (e.key === 'Escape') {
          stopHotkeyRecording(false);
          return;
        }

        const ahk = buildAhkFromKeyboardEvent(e);
        if (!ahk) {
          input.value = '请按组合键';
          window.setTimeout(() => {
            if (activeHotkeyRecorder?.input === input) {
              input.value = '录入中...';
            }
          }, 500);
          return;
        }
        stopHotkeyRecording(true, ahk);
      };
      grid.appendChild(wrap);
    }
    block.appendChild(grid);
    hotkeysEl.appendChild(block);
  }
}

export function applyShortcutsState(payload) {
  state.categories = payload.categories || [];
  state.data = payload.data || {};
  state.hotkeys = payload.hotkeys || {};
  state.hotkeyDefs = payload.hotkey_defs || fallbackHotkeyDefs;
  state.behavior = payload.behavior || state.behavior;
  state.app = payload.app || state.app;
  state.assistant = payload.assistant || state.assistant;

  for (const cat of state.categories) {
    if (cat.id === 'fields') {
      cat.name = '字段';
    } else if (cat.id === 'prompts') {
      cat.name = '提示词';
    } else if (cat.id === 'quick_fields') {
      cat.name = '快捷字段';
    } else if (String(cat.name || '').trim() === '快捷键') {
      cat.name = '快捷字段';
    } else if (String(cat.name || '').trim().toLowerCase() === 'new tab') {
      cat.name = '新栏目';
    }
  }
  if (!state.categories.find(c => c.id === 'quick_fields')) {
    state.categories.splice(Math.min(2, state.categories.length), 0, { id: 'quick_fields', name: '快捷字段', builtin: 1 });
    state.data.quick_fields ||= [];
  }

  const persistedSelectedCategory = String(state.app?.shortcuts_selected_category || '').trim();
  if (persistedSelectedCategory && state.categories.find((c) => c.id === persistedSelectedCategory)) {
    state.selectedCategoryId = persistedSelectedCategory;
  } else if (!state.selectedCategoryId || !state.categories.find(c => c.id === state.selectedCategoryId)) {
    state.selectedCategoryId = state.categories[0]?.id || null;
  }
  ensureVisibleSelectedCategory();
  state.app.shortcuts_selected_category = state.selectedCategoryId || 'fields';

  state.behavior.auto_refresh_enabled = isTruthy(state.behavior.auto_refresh_enabled) ? 1 : 0;
  state.behavior.refresh_every_uses = toInt(state.behavior.refresh_every_uses, 3, 1, 1000);
  state.behavior.refresh_every_minutes = toInt(state.behavior.refresh_every_minutes, 5, 1, 1440);

  renderTabs();
  renderRows();
  renderHotkeys();
  setDirty(false, 'shortcuts');
}

function validateBeforeSave() {
  if (!state.categories.length) {
    throw new Error('至少保留一个栏目');
  }

  for (const cat of state.categories) {
    let name = (cat.name || '').trim();
    if (cat.id === 'fields') name = '字段';
    if (cat.id === 'prompts') name = '提示词';
    if (cat.id === 'quick_fields' || name === '快捷键') name = '快捷字段';
    if (!name) throw new Error('栏目名称不能为空');
    cat.name = name;

    const rows = state.data[cat.id] || [];
    const seen = new Set();
    for (const row of rows) {
      const key = String(row.key || '').trim();
      const val = String(row.value || '').trim();
      if (!key && !val) continue;
      if (!key) throw new Error(`栏目【${cat.name}】存在空触发词`);
      const low = key.toLowerCase();
      if (seen.has(low)) throw new Error(`栏目【${cat.name}】触发词重复：${key}`);
      seen.add(low);
    }
  }

  const defs = state.hotkeyDefs.length ? state.hotkeyDefs : fallbackHotkeyDefs;
  const hotkeySeenByScope = new Map();
  for (const def of defs) {
    const txt = String(state.hotkeys[def.id] ?? '').trim();
    if (!txt) throw new Error(`快捷键不能为空：${def.label || def.id}`);
    const ahk = friendlyToAhk(txt);
    if (!ahk) throw new Error(`快捷键格式不支持：${txt}`);
    const scope = String(def.scope || 'shared').trim().toLowerCase() || 'shared';
    if (!hotkeySeenByScope.has(scope)) {
      hotkeySeenByScope.set(scope, new Set());
    }
    const scopedSeen = hotkeySeenByScope.get(scope);
    const low = ahk.toLowerCase();
    if (scopedSeen.has(low)) throw new Error(`快捷键冲突：${txt}`);
    scopedSeen.add(low);
    state.hotkeys[def.id] = ahk;
  }

  state.behavior.auto_refresh_enabled = isTruthy(state.behavior.auto_refresh_enabled) ? 1 : 0;
  state.behavior.refresh_every_uses = toInt(state.behavior.refresh_every_uses, 3, 1, 1000);
  state.behavior.refresh_every_minutes = toInt(state.behavior.refresh_every_minutes, 5, 1, 1440);
}

export async function saveShortcuts(options = {}) {
  const silent = !!options.silent;
  validateBeforeSave();
  const sanitizedData = buildSanitizedData();
  state.app ||= {};
  state.app.shortcuts_selected_category = state.selectedCategoryId || 'fields';

  await api('/api/save', {
    method: 'POST',
    body: JSON.stringify({
      categories: state.categories,
      data: sanitizedData,
      hotkeys: state.hotkeys,
      behavior: state.behavior,
      app: state.app,
      assistant: state.assistant
    })
  });

  renderHotkeys();
  setDirty(false, 'shortcuts');
  try {
    sessionStorage.removeItem('raccourci.shortcutsDraft');
    sessionStorage.setItem('raccourci.shortcutsLastSavedAt', String(Date.now()));
  } catch {}
  if (!silent) {
    toast('快捷键配置已保存并生效');
  }
}

export function initShortcutsHandlers() {
  byId('addTabBtn').onclick = () => {
    const id = `cat_${Date.now()}`;
    state.categories.push({ id, name: '新栏目', builtin: 0 });
    state.data[id] = [];
    state.selectedCategoryId = id;
    state.app.shortcuts_selected_category = id;
    setDirty(true, 'shortcuts');
    renderTabs();
    renderRows();
    void saveShortcutsNowOnStructureChange('新增栏目保存失败');
  };

  byId('deleteTabBtn').onclick = () => {
    ensureVisibleSelectedCategory();
    const cat = state.categories.find(c => c.id === state.selectedCategoryId);
    if (!cat) return;
    if (state.protectedCategoryIds.has(cat.id)) {
      toast('默认栏目不可删除');
      return;
    }
    if (!confirm(`确认删除栏目【${cat.name}】吗？`)) return;
    state.categories = state.categories.filter(c => c.id !== cat.id);
    delete state.data[cat.id];
    state.selectedCategoryId = state.categories[0]?.id || null;
    state.app.shortcuts_selected_category = state.selectedCategoryId || 'fields';
    setDirty(true, 'shortcuts');
    renderTabs();
    renderRows();
    void saveShortcutsNowOnStructureChange('删除栏目保存失败');
  };

  byId('addRowBtn').onclick = () => {
    ensureVisibleSelectedCategory();
    const catId = state.selectedCategoryId;
    if (!catId) return;
    state.data[catId] ||= [];
    state.data[catId].push({ key: '', value: '', usage: 0 });
    setDirty(true, 'shortcuts');
    renderRows();
  };

  byId('resetHotkeysBtn').onclick = () => {
    const defs = state.hotkeyDefs.length ? state.hotkeyDefs : fallbackHotkeyDefs;
    for (const def of defs) {
      state.hotkeys[def.id] = def.default;
    }
    renderHotkeys();
    setDirty(true, 'shortcuts');
    toast('已恢复默认快捷键');
    scheduleAutoSave();
  };

}

