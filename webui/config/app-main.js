import { state, byId, api, toast, setDirty, setModeUi } from './app-common.js';
import { initShortcutsHandlers, applyShortcutsState, saveShortcuts } from './app-shortcuts.js';
import { initNotesHandlers, loadNotes, saveCurrentNote } from './app-notes.js';
import { initNotesDisplayHandlers, loadNotesDisplayNotes, saveCurrentNotesDisplayNote } from './app-notes-display.js';
import { initCaptureHandlers, refreshCaptureState } from './app-capture.js';
import { initAssistantHandlers, applyAssistantState, saveAssistantSettings } from './app-assistant.js';
import { initResumeHandlers, applyResumeState, saveResumeProfile } from './app-resume.js';
import { initTestingHandlers, runOverlayRecordTest, refreshTestingState } from './app-testing.js';

let capturePollTimer = 0;
const loadedModes = new Set();
const SHORTCUTS_DRAFT_KEY = 'raccourci.shortcutsDraft';
const SHORTCUTS_DRAFT_RESTORE_KEY = 'raccourci.shortcutsDraftRestorePending';
const NOTES_DRAFT_KEY = 'raccourci.notesDraft';
const NOTES_DRAFT_RESTORE_KEY = 'raccourci.notesDraftRestorePending';
const NOTES_DISPLAY_DRAFT_KEY = 'raccourci.notesDisplayDraft';
const NOTES_DISPLAY_DRAFT_RESTORE_KEY = 'raccourci.notesDisplayDraftRestorePending';
const RESUME_DRAFT_KEY = 'raccourci.resumeDraft';
const RESUME_DRAFT_RESTORE_KEY = 'raccourci.resumeDraftRestorePending';
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

function markModeLoaded(mode) {
  loadedModes.add(mode);
}

function hasModeLoaded(mode) {
  return loadedModes.has(mode);
}

function markShortcutsDraftRestorePending() {
  try {
    sessionStorage.setItem(SHORTCUTS_DRAFT_RESTORE_KEY, '1');
  } catch {}
}

function markNotesDraftRestorePending() {
  try {
    sessionStorage.setItem(NOTES_DRAFT_RESTORE_KEY, '1');
  } catch {}
}

function markNotesDisplayDraftRestorePending() {
  try {
    sessionStorage.setItem(NOTES_DISPLAY_DRAFT_RESTORE_KEY, '1');
  } catch {}
}

function markResumeDraftRestorePending() {
  try {
    sessionStorage.setItem(RESUME_DRAFT_RESTORE_KEY, '1');
  } catch {}
}

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

function saveNotesDraft() {
  try {
    const id = String(state.notes.currentId || '').trim();
    if (!id) return;
    const draft = {
      ts: Date.now(),
      id,
      title: byId('noteTitle')?.value || '',
      content: byId('noteContent')?.value || ''
    };
    sessionStorage.setItem(NOTES_DRAFT_KEY, JSON.stringify(draft));
  } catch {}
}

function saveNotesDisplayDraft() {
  try {
    const id = String(state.notesDisplay.currentId || '').trim();
    const content = byId('notesDisplayContent')?.value || '';
    if (!id && !content.trim()) return;
    const draft = {
      ts: Date.now(),
      id,
      content
    };
    sessionStorage.setItem(NOTES_DISPLAY_DRAFT_KEY, JSON.stringify(draft));
  } catch {}
}

function saveResumeDraft() {
  try {
    const sections = state.resume?.profile?.sections;
    if (!Array.isArray(sections) || !sections.length) return;
    const draft = {
      ts: Date.now(),
      selectedSectionId: state.resume.selectedSectionId || '',
      profile: state.resume.profile
    };
    sessionStorage.setItem(RESUME_DRAFT_KEY, JSON.stringify(draft));
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

function tryRestoreNotesDraft() {
  try {
    if (sessionStorage.getItem(NOTES_DRAFT_RESTORE_KEY) !== '1') return false;
    const raw = sessionStorage.getItem(NOTES_DRAFT_KEY);
    if (!raw) return false;
    const draft = JSON.parse(raw);
    const id = String(draft?.id || '').trim();
    if (!id) return false;

    state.notes.currentId = id;
    if (byId('noteTitle')) byId('noteTitle').value = String(draft?.title || '');
    if (byId('noteContent')) byId('noteContent').value = String(draft?.content || '');
    state.notes.dirty = true;
    setDirty(true, 'notes');
    toast('已恢复刷新前未保存笔记草稿');
    return true;
  } catch {}
  finally {
    try { sessionStorage.removeItem(NOTES_DRAFT_RESTORE_KEY); } catch {}
  }
  return false;
}

function tryRestoreNotesDisplayDraft() {
  try {
    if (sessionStorage.getItem(NOTES_DISPLAY_DRAFT_RESTORE_KEY) !== '1') return false;
    const raw = sessionStorage.getItem(NOTES_DISPLAY_DRAFT_KEY);
    if (!raw) return false;
    const draft = JSON.parse(raw);
    const id = String(draft?.id || '').trim();
    const content = String(draft?.content || '');
    if (!id && !content.trim()) return false;

    if (id) state.notesDisplay.currentId = id;
    if (byId('notesDisplayContent')) {
      byId('notesDisplayContent').value = content;
      byId('notesDisplayContent').dispatchEvent(new Event('input', { bubbles: true }));
    } else {
      state.notesDisplay.dirty = true;
      setDirty(true, 'notes_display');
    }
    toast('已恢复刷新前未保存笔记显示草稿');
    return true;
  } catch {}
  finally {
    try { sessionStorage.removeItem(NOTES_DISPLAY_DRAFT_RESTORE_KEY); } catch {}
  }
  return false;
}

function tryRestoreResumeDraft() {
  try {
    if (sessionStorage.getItem(RESUME_DRAFT_RESTORE_KEY) !== '1') return false;
    const raw = sessionStorage.getItem(RESUME_DRAFT_KEY);
    if (!raw) return false;
    const draft = JSON.parse(raw);
    if (!draft?.profile || !Array.isArray(draft.profile.sections)) return false;

    state.resume.profile = draft.profile;
    state.resume.selectedSectionId = String(draft?.selectedSectionId || '');
    applyResumeState({ resume: { profile: state.resume.profile, flat_map: state.resume.flat_map } });
    toast('已恢复刷新前未保存简历草稿');
    return true;
  } catch {}
  finally {
    try { sessionStorage.removeItem(RESUME_DRAFT_RESTORE_KEY); } catch {}
  }
  return false;
}

function persistShortcutsDraftForHardRefresh() {
  if (!(state.app.active_mode === 'shortcuts' || state.app.active_mode === 'hotkeys')) return;
  if (!state.dirty) return;
  saveShortcutsDraft();
  markShortcutsDraftRestorePending();
}

function persistNotesDraftForHardRefresh() {
  if (state.app.active_mode !== 'notes') return;
  if (!state.notes.dirty) return;
  saveNotesDraft();
  markNotesDraftRestorePending();
}

function persistNotesDisplayDraftForHardRefresh() {
  if (state.app.active_mode !== 'notes_display') return;
  if (!state.notesDisplay.dirty) return;
  saveNotesDisplayDraft();
  markNotesDisplayDraftRestorePending();
}

function persistResumeDraftForHardRefresh() {
  if (state.app.active_mode !== 'resume') return;
  saveResumeDraft();
  markResumeDraftRestorePending();
}

function persistAllDraftsForHardRefresh() {
  persistShortcutsDraftForHardRefresh();
  persistNotesDraftForHardRefresh();
  persistNotesDisplayDraftForHardRefresh();
  persistResumeDraftForHardRefresh();
}

function applyAppShellState(payload) {
  state.hotkeys = payload.hotkeys || state.hotkeys;
  state.hotkeyDefs = payload.hotkey_defs || state.hotkeyDefs;
  state.app = {
    ...state.app,
    ...(payload.app || {})
  };
  state.app.mode_order = normalizeModeOrder(state.app?.mode_order);
  applyModeButtonOrder();
}

function getModePrefetchPayload(mode, payload) {
  if (!payload || typeof payload !== 'object') return null;
  const effectiveMode = mode === 'hotkeys' ? 'shortcuts' : mode;
  if (effectiveMode === 'shortcuts' && payload.shortcuts_prefetch) {
    return payload.shortcuts_prefetch;
  }
  return null;
}

async function ensureModeLoaded(mode, options = {}) {
  const forceReload = !!options.forceReload;
  const prefetchedPayload = getModePrefetchPayload(mode, options.prefetchedPayload);
  const effectiveMode = mode === 'hotkeys' ? 'shortcuts' : mode;

  if (!forceReload && hasModeLoaded(effectiveMode)) {
    return;
  }

  if (effectiveMode === 'shortcuts') {
    const payload = prefetchedPayload || await api('/api/state');
    applyShortcutsState(payload);
    applyAppShellState(payload);
    markModeLoaded('shortcuts');
    markModeLoaded('hotkeys');
    return;
  }

  if (effectiveMode === 'notes') {
    await loadNotes();
    markModeLoaded('notes');
    return;
  }

  if (effectiveMode === 'notes_display') {
    await loadNotesDisplayNotes();
    markModeLoaded('notes_display');
    return;
  }

  if (effectiveMode === 'capture') {
    await refreshCaptureState();
    markModeLoaded('capture');
    return;
  }

  if (effectiveMode === 'assistant') {
    const payload = await api('/api/assistant/state');
    const assistantState = payload.state || {};
    applyAssistantState({
      assistant: {
        ...(assistantState.settings || {}),
        benchmark: assistantState.benchmark || state.assistant.benchmark,
        latest_capture: assistantState.latest_capture || state.assistant.latest_capture || ''
      }
    });
    markModeLoaded('assistant');
    return;
  }

  if (effectiveMode === 'resume') {
    const payload = await api('/api/resume/state');
    applyResumeState({ resume: payload.state || state.resume });
    markModeLoaded('resume');
    return;
  }

  if (effectiveMode === 'testing') {
    await ensureModeLoaded('assistant', options);
    await refreshTestingState();
    markModeLoaded('testing');
  }
}

async function switchModeInternal(mode, options = {}) {
  const persist = options.persist !== false;
  const forceReload = !!options.forceReload;
  const prefetchedPayload = options.prefetchedPayload || null;
  if (!['shortcuts', 'notes', 'notes_display', 'capture', 'assistant', 'resume', 'hotkeys', 'testing'].includes(mode)) {
    mode = 'shortcuts';
  }

  if (hasModeLoaded('notes') && state.app.active_mode === 'notes' && mode !== 'notes' && state.notes.dirty) {
    await saveCurrentNote();
  }
  if (hasModeLoaded('notes_display') && state.app.active_mode === 'notes_display' && mode !== 'notes_display' && state.notesDisplay.dirty) {
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
      (mode === 'resume' ? '简历自动保存' : '执行测试'))))));
  }

  const persistedMode = (mode === 'hotkeys' || mode === 'testing') ? 'shortcuts' : mode;
  if (persist) {
    await api('/api/app/mode', {
      method: 'POST',
      body: JSON.stringify({ active_mode: persistedMode })
    });
  }

  if (capturePollTimer) {
    clearInterval(capturePollTimer);
    capturePollTimer = 0;
  }

  await ensureModeLoaded(mode, { forceReload, prefetchedPayload });

  if (mode === 'notes') {
    tryRestoreNotesDraft();
  }
  if (mode === 'notes_display') {
    tryRestoreNotesDisplayDraft();
  }
  if (mode === 'capture') {
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
    tryRestoreResumeDraft();
  }
}

async function switchMode(mode) {
  return switchModeInternal(mode, { persist: true, forceReload: false });
}

async function reloadAll() {
  loadedModes.clear();
  const payload = await api('/api/app/state');
  applyAppShellState(payload);
  await switchModeInternal(payload.app?.active_mode || 'shortcuts', { persist: false, forceReload: true, prefetchedPayload: payload });
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
          markShortcutsDraftRestorePending();
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
    persistAllDraftsForHardRefresh();
    if (!state.notes.dirty && !state.notesDisplay.dirty) return;
    e.preventDefault();
    e.returnValue = '存在未保存改动，确定离开吗？';
  });

  window.addEventListener('pagehide', () => {
    persistAllDraftsForHardRefresh();
  });

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') {
      persistAllDraftsForHardRefresh();
    }
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
  if (state.app.active_mode === 'shortcuts' || state.app.active_mode === 'hotkeys') {
    tryRestoreShortcutsDraft();
  }
}

bootstrap().catch(e => {
  toast(`初始化失败: ${e.message}`);
});
