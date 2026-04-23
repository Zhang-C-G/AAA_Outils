import { state, byId, api, toast, setDirty, setModeUi } from './app-common.js';
import { initShortcutsHandlers, applyShortcutsState, saveShortcuts } from './app-shortcuts.js';
import { initNotesHandlers, loadNotes, saveCurrentNote } from './app-notes.js';
import { initCaptureHandlers, refreshCaptureState } from './app-capture.js';
import { initAssistantHandlers, applyAssistantState, saveAssistantSettings } from './app-assistant.js';
import { initTestingHandlers, runOverlayRecordTest } from './app-testing.js';

let capturePollTimer = 0;
const SHORTCUTS_DRAFT_KEY = 'raccourci.shortcutsDraft';
const SHORTCUTS_DRAFT_RESTORE_KEY = 'raccourci.shortcutsDraftRestorePending';

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
  if (!['shortcuts', 'notes', 'capture', 'assistant', 'hotkeys', 'testing'].includes(mode)) {
    mode = 'shortcuts';
  }

  if (state.app.active_mode === 'notes' && mode !== 'notes' && state.notes.dirty) {
    await saveCurrentNote();
  }

  state.app.active_mode = mode;
  setModeUi(mode);

  const saveBtn = byId('saveBtn');
  if (saveBtn) {
    saveBtn.textContent =
      mode === 'shortcuts' ? '保存' :
      (mode === 'hotkeys' ? '保存快捷键' :
      (mode === 'notes' ? '保存笔记' :
      (mode === 'capture' ? '保存截图设置' :
      (mode === 'assistant' ? '保存助手设置' : '执行测试'))));
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

  if (mode === 'notes') {
    await loadNotes();
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
}

async function reloadAll() {
  const payload = await api('/api/state');
  applyShortcutsState(payload);
  applyAssistantState(payload);
  await switchMode(payload.app?.active_mode || 'shortcuts');
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
        } else if (state.app.active_mode === 'capture') {
          byId('capSaveSettingsBtn').click();
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
  byId('modeCaptureBtn').onclick = () => switchMode('capture').catch(e => toast(`切换失败: ${e.message}`));
  byId('modeAssistantBtn').onclick = () => switchMode('assistant').catch(e => toast(`切换失败: ${e.message}`));
  byId('modeHotkeysBtn').onclick = () => switchMode('hotkeys').catch(e => toast(`切换失败: ${e.message}`));
  byId('modeTestingBtn').onclick = () => switchMode('testing').catch(e => toast(`切换失败: ${e.message}`));

  window.addEventListener('beforeunload', (e) => {
    if (!state.notes.dirty) return;
    e.preventDefault();
    e.returnValue = '笔记存在未保存改动，确定离开吗？';
  });
}

async function bootstrap() {
  initShortcutsHandlers();
  initNotesHandlers();
  initCaptureHandlers();
  initAssistantHandlers();
  initTestingHandlers();
  bindHeaderActions();

  await reloadAll();
  setDirty(false, 'shortcuts');
}

bootstrap().catch(e => {
  toast(`初始化失败: ${e.message}`);
});
