import { state, byId, api, setDirty } from './app-common.js';

const session = {
  autosaveTimer: 0,
  loading: false,
  saveInFlight: false,
  saveQueued: false,
  savePromise: null
};

export function getNotesDisplaySessionState() {
  return session;
}

export function clearNotesDisplaySessionAutosave() {
  if (!session.autosaveTimer) return;
  window.clearTimeout(session.autosaveTimer);
  session.autosaveTimer = 0;
}

export function markNotesDisplaySessionDirty() {
  state.notesDisplay.dirty = true;
  setDirty(true, 'notes_display');
}

export function markNotesDisplaySessionClean() {
  state.notesDisplay.dirty = false;
  setDirty(false, 'notes_display');
}

export function setNotesDisplaySessionLoading(value) {
  session.loading = !!value;
}

export async function loadNotesDisplayContent(noteId, options = {}) {
  const id = String(noteId || '').trim();
  if (!id) return null;
  const payload = await api(`/api/notes-display/get?id=${encodeURIComponent(id)}`);
  if (!payload.ok) throw new Error(payload.error || 'load notes display note failed');
  const note = payload.note || { id, title: '', content: '' };

  session.loading = true;
  clearNotesDisplaySessionAutosave();
  state.notesDisplay.currentId = note.id;
  state.app.notes_display_current_id = note.id;
  markNotesDisplaySessionClean();

  if (typeof options.applyLoadedNote === 'function') {
    options.applyLoadedNote(note);
  }
  session.loading = false;

  if (typeof options.persistWorkspaceState === 'function') {
    await options.persistWorkspaceState();
  }
  return note;
}

export async function loadNotesDisplayNotesList(options = {}) {
  const payload = await api('/api/notes-display/list');
  if (!payload.ok) throw new Error(payload.error || 'load notes display notes failed');
  state.notesDisplay.list = payload.notes || [];

  if (!state.notesDisplay.list.length && typeof options.ensureCurrentId === 'function') {
    await options.ensureCurrentId();
    const retry = await api('/api/notes-display/list');
    if (!retry.ok) throw new Error(retry.error || 'reload notes display notes failed');
    state.notesDisplay.list = retry.notes || [];
  }

  if (!state.notesDisplay.currentId || !state.notesDisplay.list.find((n) => n.id === state.notesDisplay.currentId)) {
    const preferredId = String(state.app?.notes_display_current_id || '').trim();
    state.notesDisplay.currentId = (preferredId && state.notesDisplay.list.find((n) => n.id === preferredId) ? preferredId : '') || state.notesDisplay.list[0]?.id || '';
  }

  if (typeof options.onListLoaded === 'function') {
    options.onListLoaded(state.notesDisplay.list);
  }

  if (state.notesDisplay.currentId) {
    return loadNotesDisplayContent(state.notesDisplay.currentId, options);
  }

  clearNotesDisplaySessionAutosave();
  if (typeof options.onEmptyList === 'function') {
    options.onEmptyList();
  }
  return null;
}

export async function saveNotesDisplayPayload(payload, options = {}) {
  const id = String(payload?.id || '').trim();
  if (!id) return;

  if (session.saveInFlight) {
    session.saveQueued = true;
    await session.savePromise;
    if (state.notesDisplay.dirty && typeof options.retry === 'function') {
      return options.retry();
    }
    return;
  }

  clearNotesDisplaySessionAutosave();
  session.saveInFlight = true;

  try {
    session.savePromise = api('/api/notes-display/save', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
    const response = await session.savePromise;
    if (!response.ok) throw new Error(response.error || 'save notes display note failed');

    if (typeof options.onSaved === 'function') {
      await options.onSaved(payload, response);
    }
    markNotesDisplaySessionClean();
  } catch (error) {
    markNotesDisplaySessionDirty();
    session.saveQueued = false;
    if (typeof options.scheduleAutosave === 'function') {
      options.scheduleAutosave();
    }
    throw error;
  } finally {
    session.saveInFlight = false;
    session.savePromise = null;
    if (session.saveQueued) {
      session.saveQueued = false;
      if (typeof options.scheduleAutosave === 'function') {
        options.scheduleAutosave();
      }
    }
  }
}

export function scheduleNotesDisplaySessionAutosave(callback, delayMs) {
  if (session.loading) return;
  clearNotesDisplaySessionAutosave();
  session.autosaveTimer = window.setTimeout(() => {
    session.autosaveTimer = 0;
    void callback();
  }, delayMs);
}

export async function selectNotesDisplaySessionNote(id, options = {}) {
  const targetId = String(id || '').trim();
  if (!targetId || state.notesDisplay.currentId === targetId) return null;
  if (state.notesDisplay.dirty && typeof options.saveCurrent === 'function') {
    await options.saveCurrent({ silent: true });
  }
  return loadNotesDisplayContent(targetId, options);
}
