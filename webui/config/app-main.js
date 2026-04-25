import { state, byId, api, toast, setDirty, setModeUi } from './app-common.js';
import { initShortcutsHandlers, applyShortcutsState, saveShortcuts } from './app-shortcuts.js';
import { initNotesHandlers, loadNotes, saveCurrentNote } from './app-notes.js';
import { initNotesDisplayHandlers, loadNotesDisplayNotes, saveCurrentNotesDisplayNote } from './app-notes-display.js';
import { initCaptureHandlers, refreshCaptureState } from './app-capture.js';
import { initAssistantHandlers, applyAssistantState, saveAssistantSettings } from './app-assistant.js';
import { initResumeHandlers, applyResumeState, saveResumeProfile } from './app-resume.js';
import { initTestingHandlers, runOverlayRecordTest, refreshTestingState } from './app-testing.js';

let capturePollTimer = 0;
const SHORTCUTS_DRAFT_KEY = 'raccourci.shortcutsDraft';
const SHORTCUTS_DRAFT_RESTORE_KEY = 'raccourci.shortcutsDraftRestorePending';
const DEFAULT_MODE_ORDER = ['shortcuts', 'notes', 'notes_display', 'capture', 'assistant', 'resume', 'hotkeys', 'testing'];
const MODE_BUTTON_IDS = {
  shortcuts: 'modeShortcutsBtn',
  notes: 'modeNotesBtn',
  notes_display: 'modeNotesDisplayBtn',
  capture: 'modeCaptureBtn',
  assistant: 'modeAssistantBtn',
  resume: 'modeResumeBtn',
  hotkeys: 'modeHotkeysBtn',
  testing: 'modeTestingBtn'
};
let draggingModeId = '';

function normalizeModeOrder(order) {
  const seen = new Set();
  const out = [];
  const source = Array.isArray(order) ? order : [];

  for (const item of source) {
    const mode = String(item || '').trim();
    if (!DEFAULT_MODE_ORDER.includes(mode) || seen.has(mode)) continue;
    seen.add(mode);
    out.push(mode);
  }

  for (const mode of DEFAULT_MODE_ORDER) {
    if (seen.has(mode)) continue;
    seen.add(mode);
    out.push(mode);
  }
  return out;
}

function getCurrentModeOrderFromDom() {
  const panel = byId('modePanel');
  if (!panel) return normalizeModeOrder(state.app?.mode_order);
  return normalizeModeOrder(Array.from(panel.querySelectorAll('.mode-btn')).map((el) => el.dataset.mode));
}

function applyModeButtonOrder() {
  const panel = byId('modePanel');
  if (!panel) return;

  const order = normalizeModeOrder(state.app?.mode_order);
  state.app.mode_order = order;
  for (const mode of order) {
    const btn = byId(MODE_BUTTON_IDS[mode]);
    if (btn) panel.appendChild(btn);
  }
}

async function persistModeOrder(order) {
  const normalized = normalizeModeOrder(order);
  state.app.mode_order = normalized;
  await api('/api/app/mode-order', {
    method: 'POST',
    body: JSON.stringify({ mode_order: normalized })
  });
}

function bindModePanelDrag() {
  const panel = byId('modePanel');
  if (!panel) return;

  const buttons = Array.from(panel.querySelectorAll('.mode-btn'));
  for (const btn of buttons) {
    if (btn.dataset.dragBound === '1') continue;
    btn.dataset.dragBound = '1';

    btn.addEventListener('dragstart', (event) => {
      draggingModeId = btn.dataset.mode || '';
      btn.classList.add('dragging');
      try { event.dataTransfer.effectAllowed = 'move'; } catch {}
    });

    btn.addEventListener('dragend', async () => {
      btn.classList.remove('dragging');
      for (const node of panel.querySelectorAll('.drag-target')) {
        node.classList.remove('drag-target');
      }
      const nextOrder = getCurrentModeOrderFromDom();
      draggingModeId = '';
      if (JSON.stringify(nextOrder) === JSON.stringify(normalizeModeOrder(state.app?.mode_order))) return;
      try {
        await persistModeOrder(nextOrder);
        toast('模块顺序已保存');
      } catch (error) {
        toast(`顺序保存失败: ${error.message}`);
      }
    });

    btn.addEventListener('dragover', (event) => {
      event.preventDefault();
      if (!draggingModeId || draggingModeId === btn.dataset.mode) return;

      const draggingBtn = byId(MODE_BUTTON_IDS[draggingModeId]);
      if (!draggingBtn || draggingBtn === btn) return;

      const rect = btn.getBoundingClientRect();
      const insertBefore = event.clientX < rect.left + rect.width / 2;
      btn.classList.add('drag-target');
      if (insertBefore) {
        panel.insertBefore(draggingBtn, btn);
      } else {
        panel.insertBefore(draggingBtn, btn.nextSibling);
      }
    });

    btn.addEventListener('dragleave', () => {
      btn.classList.remove('drag-target');
    });

    btn.addEventListener('drop', (event) => {
      event.preventDefault();
      btn.classList.remove('drag-target');
    });
  }
}

function renderNotesDisplayView() {
  const hotkeyDef = (state.hotkeyDefs || []).find((item) => item.id === 'notes_display_overlay');
  const hotkey = state.hotkeys.notes_display_overlay || hotkeyDef?.default || 'F4';
  const hotkeyEl = byId('notesDisplayHotkeyValue');
  const statusEl = byId('notesDisplayStatus');

  if (hotkeyEl) {
    hotkeyEl.textContent = hotkey;
  }

  if (!statusEl) return;

  const latestNote = state.notesDisplay.list?.[0];
  if (!latestNote) {
    statusEl.innerHTML = `
      <div class="notes-display-empty">当前还没有可供展示的笔记显示内容。先在本模块中创建并保存内容，再按 ${hotkey} 呼出笔记显示悬浮窗。</div>
    `;
    return;
  }

  const currentTitle = latestNote.title || 'Untitled';
  const total = Array.isArray(state.notesDisplay.list) ? state.notesDisplay.list.length : 0;
  statusEl.innerHTML = `
    <div class="notes-display-meta-row"><span>模块身份</span><strong>独立于笔记模块</strong></div>
    <div class="notes-display-meta-row"><span>默认呼出对象</span><strong>${currentTitle}</strong></div>
    <div class="notes-display-meta-row"><span>当前笔记总数</span><strong>${total}</strong></div>
    <div class="notes-display-meta-row"><span>呼出方式</span><strong>按下 ${hotkey}</strong></div>
    <div class="notes-display-tip">笔记显示是独立模块。当前页中的内容编辑、Markdown 解析、目录生成与悬浮展示，都只属于笔记显示模块自身。</div>
  `;
}

function saveShortcutsDraft() {
  try {
    const draft = {
      ts: Date.now(),
      categories: state.categories,
      data: state.data,
      hotkeys: state.hotkeys,
      behavior: state.behavior
    };
    sessionStorage.setItem(SHORTCUTS_DRAFT_KEY, JSON.stringify(draft));
  } catch {}
}

function tryRestoreShortcutsDraft() {
  try {
    if (sessionStorage.getItem(SHORTCUTS_DRAFT_RESTORE_KEY) !== '1') return;
    const raw = sessionStorage.getItem(SHORTCUTS_DRAFT_KEY);
    if (!raw) return;
    const draft = JSON.parse(raw);
    const lastSavedAt = Number(sessionStorage.getItem('raccourci.shortcutsLastSavedAt') || 0);
    if (Number.isFinite(lastSavedAt) && lastSavedAt > 0 && Number(draft?.ts || 0) <= lastSavedAt) {
      sessionStorage.removeItem(SHORTCUTS_DRAFT_KEY);
      return;
    }
    if (!Array.isArray(draft?.categories) || typeof draft?.data !== 'object') return;

    applyShortcutsState({
      categories: draft.categories,
      data: draft.data,
      hotkeys: draft.hotkeys || state.hotkeys,
      hotkey_defs: state.hotkeyDefs,
      behavior: draft.behavior || state.behavior,
      app: state.app,
      assistant: state.assistant
    });
    setDirty(true, 'shortcuts');
    toast('已恢复刷新前未保存草稿');
  } catch {}
  finally {
    try { sessionStorage.removeItem(SHORTCUTS_DRAFT_RESTORE_KEY); } catch {}
  }
}

async function switchMode(mode) {
  if (!['shortcuts', 'notes', 'notes_display', 'capture', 'assistant', 'resume', 'hotkeys', 'testing'].includes(mode)) {
    mode = 'shortcuts';
  }

  if (state.app.active_mode === 'notes' && mode !== 'notes' && state.notes.dirty) {
    await saveCurrentNote();
  }
  if (state.app.active_mode === 'notes_display' && mode !== 'notes_display' && state.notesDisplay.dirty) {
    await saveCurrentNotesDisplayNote();
  }

  state.app.active_mode = mode;
  setModeUi(mode);

  const saveBtn = byId('saveBtn');
  if (saveBtn) {
    saveBtn.textContent =
      mode === 'shortcuts' ? '保存' :
      (mode === 'hotkeys' ? '保存快捷键' :
      (mode === 'notes' ? '保存笔记' :
      (mode === 'notes_display' ? '保存笔记显示内容' :
      (mode === 'capture' ? '保存截图设置' :
      (mode === 'assistant' ? '保存助手设置' :
      (mode === 'resume' ? '保存简历资料' : '执行测试'))))));
  }

  const persistedMode = (mode === 'hotkeys' || mode === 'testing') ? 'shortcuts' : mode;
  await api('/api/app/mode', {
    method: 'POST',
    body: JSON.stringify({ active_mode: persistedMode })
  });

  if (capturePollTimer) {
    clearInterval(capturePollTimer);
    capturePollTimer = 0;
  }

  if (mode === 'notes' || mode === 'notes_display') {
    if (mode === 'notes') {
      await loadNotes();
    } else {
      await loadNotesDisplayNotes();
      renderNotesDisplayView();
    }
  }
  if (mode === 'capture') {
    await refreshCaptureState();
    capturePollTimer = setInterval(() => {
      refreshCaptureState().catch(() => {});
    }, 1500);
  }
  if (mode === 'assistant') {
    applyAssistantState({ assistant: state.assistant });
  }
  if (mode === 'testing') {
    await refreshTestingState();
  }
  if (mode === 'resume') {
    applyResumeState({ resume: state.resume });
  }
}

async function reloadAll() {
  const [payload, resumePayload] = await Promise.all([
    api('/api/state'),
    api('/api/resume/state')
  ]);
  applyShortcutsState(payload);
  applyAssistantState(payload);
  applyResumeState({ resume: resumePayload.state || state.resume });
  state.app.mode_order = normalizeModeOrder(state.app?.mode_order);
  applyModeButtonOrder();
  await switchMode(payload.app?.active_mode || 'shortcuts');
}

async function waitForServerReady(maxAttempts = 20, delayMs = 500) {
  let lastError = null;
  for (let i = 0; i < maxAttempts; i += 1) {
    try {
      await api('/api/ping');
      return;
    } catch (error) {
      lastError = error;
      await new Promise((resolve) => window.setTimeout(resolve, delayMs));
    }
  }
  throw lastError || new Error('web config server not ready');
}

function bindHeaderActions() {
  const saveBtn = byId('saveBtn');
  if (saveBtn) {
    saveBtn.onclick = async () => {
      try {
        if (state.app.active_mode === 'shortcuts' || state.app.active_mode === 'hotkeys') {
          await saveShortcuts();
        } else if (state.app.active_mode === 'notes') {
          await saveCurrentNote();
        } else if (state.app.active_mode === 'notes_display') {
          await saveCurrentNotesDisplayNote();
          await loadNotesDisplayNotes();
          renderNotesDisplayView();
        } else if (state.app.active_mode === 'capture') {
          byId('capSaveSettingsBtn').click();
        } else if (state.app.active_mode === 'resume') {
          await saveResumeProfile();
        } else if (state.app.active_mode === 'testing') {
          await runOverlayRecordTest();
        } else {
          await saveAssistantSettings();
        }
      } catch (e) {
        toast(`保存失败: ${e.message}`);
      }
    };
  }

  const reloadBtn = byId('reloadBtn');
  if (reloadBtn) {
    reloadBtn.onclick = async () => {
      try {
        if ((state.app.active_mode === 'shortcuts' || state.app.active_mode === 'hotkeys') && state.dirty) {
          saveShortcutsDraft();
          try { sessionStorage.setItem(SHORTCUTS_DRAFT_RESTORE_KEY, '1'); } catch {}
        }
        await reloadAll();
        if (state.app.active_mode === 'shortcuts' || state.app.active_mode === 'hotkeys') {
          tryRestoreShortcutsDraft();
        }
      } catch (e) {
        toast(`刷新失败: ${e.message}`);
      }
    };
  }

  const saveVersionBtn = byId('saveVersionBtn');
  if (saveVersionBtn) {
    saveVersionBtn.onclick = async () => {
      const payload = await api('/api/version/save', { method: 'POST', body: '{}' });
      if (!payload.ok) throw new Error(payload.error || 'save version failed');
      toast('版本已保存');
    };
  }

  const restoreVersionBtn = byId('restoreVersionBtn');
  if (restoreVersionBtn) {
    restoreVersionBtn.onclick = async () => {
      const payload = await api('/api/version/restore', { method: 'POST', body: '{}' });
      if (!payload.ok) throw new Error(payload.error || 'restore failed');
      await reloadAll();
      toast('已恢复到保存版本');
    };
  }

  byId('modeShortcutsBtn').onclick = () => switchMode('shortcuts').catch(e => toast(`切换失败: ${e.message}`));
  byId('modeNotesBtn').onclick = () => switchMode('notes').catch(e => toast(`切换失败: ${e.message}`));
  byId('modeNotesDisplayBtn').onclick = () => switchMode('notes_display').catch(e => toast(`切换失败: ${e.message}`));
  byId('modeCaptureBtn').onclick = () => switchMode('capture').catch(e => toast(`切换失败: ${e.message}`));
  byId('modeAssistantBtn').onclick = () => switchMode('assistant').catch(e => toast(`切换失败: ${e.message}`));
  byId('modeResumeBtn').onclick = () => switchMode('resume').catch(e => toast(`切换失败: ${e.message}`));
  byId('modeHotkeysBtn').onclick = () => switchMode('hotkeys').catch(e => toast(`切换失败: ${e.message}`));
  byId('modeTestingBtn').onclick = () => switchMode('testing').catch(e => toast(`切换失败: ${e.message}`));

  window.addEventListener('beforeunload', (e) => {
    if (!state.notes.dirty && !state.notesDisplay.dirty) return;
    e.preventDefault();
    e.returnValue = '存在未保存改动，确定离开吗？';
  });
}

async function bootstrap() {
  initShortcutsHandlers();
  initNotesHandlers();
  initNotesDisplayHandlers();
  initCaptureHandlers();
  initAssistantHandlers();
  initResumeHandlers();
  initTestingHandlers();
  bindModePanelDrag();
  bindHeaderActions();

  await waitForServerReady();
  await reloadAll();
  setDirty(false, 'shortcuts');
}

bootstrap().catch(e => {
  toast(`初始化失败: ${e.message}`);
});
