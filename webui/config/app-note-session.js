import { state, byId, api, setDirty } from './app-common.js';

const NOTES_LAST_SAVED_KEY = 'raccourci.notesLastSavedAt';
const NOTES_DRAFT_RESTORE_KEY = 'raccourci.notesDraftRestorePending';
const NOTES_DRAFT_KEY = 'raccourci.notesDraft';
const NOTES_LOADED_REVISION_KEY = 'raccourci.notesLoadedRevision';

const session = {
  saveInFlight: false,
  saveQueued: false,
  savePromise: null,
  changeVersion: 0,
  switchGeneration: 0,
  editorBoundId: '',
  loadedRevision: { id: '', updatedAt: 0 },
  switchChain: Promise.resolve(),
  unloadFlushDone: false
};

export function resetNoteSessionUnloadState() {
  session.unloadFlushDone = false;
}

export function isNoteSessionUnloadFlushed() {
  return session.unloadFlushDone;
}

export function markNoteSessionUnloadFlushed() {
  session.unloadFlushDone = true;
}

export function getNoteSessionState() {
  return session;
}

export function getNoteSessionChangeVersion() {
  return session.changeVersion;
}

export function bumpNoteSessionChangeVersion() {
  session.changeVersion += 1;
  return session.changeVersion;
}

export function resetNoteSessionChangeVersion() {
  session.changeVersion = 0;
  return session.changeVersion;
}

export function bindNoteSessionEditor(noteId) {
  session.editorBoundId = String(noteId || '').trim();
}

export function clearNoteSessionEditorBinding() {
  session.editorBoundId = '';
}

export function isNoteSessionBoundTo(noteId) {
  const id = String(noteId || '').trim();
  if (!id) return false;
  if (!session.editorBoundId) return true;
  return session.editorBoundId === id;
}

export function updateNoteSessionLoadedRevision(id, updatedAt = 0) {
  session.loadedRevision = {
    id: String(id || '').trim(),
    updatedAt: Number(updatedAt || 0)
  };
  try {
    sessionStorage.setItem(NOTES_LOADED_REVISION_KEY, JSON.stringify(session.loadedRevision));
  } catch {}
}

export function getNoteSessionLoadedRevision() {
  return session.loadedRevision;
}

export function markNoteSessionDirty() {
  state.notes.dirty = true;
  setDirty(true, 'notes');
}

export function markNoteSessionClean() {
  state.notes.dirty = false;
  setDirty(false, 'notes');
}

export function markNoteSessionSavedForRefreshRestore() {
  try {
    sessionStorage.setItem(NOTES_LAST_SAVED_KEY, String(Date.now()));
    sessionStorage.removeItem(NOTES_DRAFT_RESTORE_KEY);
    sessionStorage.removeItem(NOTES_DRAFT_KEY);
    sessionStorage.setItem(NOTES_LOADED_REVISION_KEY, JSON.stringify(session.loadedRevision));
  } catch {}
}

export function captureNoteEditorPayload(noteId, { getTitleById, syncRenderedToSource } = {}) {
  const id = String(noteId || state.notes.currentId || '').trim();
  if (!id) return null;
  if (session.editorBoundId && id !== session.editorBoundId) {
    return null;
  }
  if (typeof syncRenderedToSource === 'function') {
    syncRenderedToSource({ markDirty: false });
  }
  return {
    id,
    title: typeof getTitleById === 'function' ? getTitleById(id) : 'Untitled',
    content: String(byId('noteContent')?.value || '')
  };
}

export async function saveNotePayload(payload, options = {}) {
  const silent = !!options.silent;
  const id = String(payload?.id || '').trim();
  if (!id) {
    if (typeof options.onMissingId === 'function' && !silent) {
      options.onMissingId();
    }
    return;
  }

  if (session.editorBoundId && id !== session.editorBoundId) {
    return;
  }

  if (session.saveInFlight) {
    session.saveQueued = true;
    await session.savePromise;
    if (
      options.retryOnQueue !== false
      && String(state.notes.currentId || '') === id
      && state.notes.dirty
      && typeof options.capturePayload === 'function'
    ) {
      const retryPayload = options.capturePayload(id);
      if (!retryPayload) return;
      retryPayload.changeVersion = session.changeVersion;
      return saveNotePayload(retryPayload, { ...options, retryOnQueue: false });
    }
    return;
  }

  if (typeof options.cancelAutosave === 'function') {
    options.cancelAutosave();
  }
  session.saveInFlight = true;
  if (typeof options.onSaveStateChanged === 'function') {
    options.onSaveStateChanged();
  }

  const saveVersion = Number(payload?.changeVersion ?? session.changeVersion);
  const title = String(payload?.title ?? 'Untitled').trim() || 'Untitled';
  const content = String(payload?.content ?? '');

  try {
    const saveIntent = String(options.saveIntent || 'autosave').trim().toLowerCase() || 'autosave';
    session.savePromise = api('/api/notes/save', {
      method: 'POST',
      body: JSON.stringify({
        id,
        title,
        content,
        save_intent: saveIntent
      })
    });
    const response = await session.savePromise;
    if (!response.ok) throw new Error(response.error || 'save note failed');

    const isCurrentNote = id === String(state.notes.currentId || '');
    if (isCurrentNote && typeof options.onCurrentNoteSaved === 'function') {
      options.onCurrentNoteSaved({
        id,
        title,
        content,
        response,
        saveVersion,
        currentChangeVersion: session.changeVersion
      });
    }

    if (saveVersion === session.changeVersion && isCurrentNote) {
      markNoteSessionClean();
      markNoteSessionSavedForRefreshRestore();
    }

    if (typeof options.onSaveStateChanged === 'function') {
      options.onSaveStateChanged();
    }
    if (!silent && typeof options.onSavedToast === 'function') {
      options.onSavedToast();
    }
  } catch (error) {
    if (id === String(state.notes.currentId || '')) {
      markNoteSessionDirty();
      if (typeof options.scheduleAutosave === 'function') {
        options.scheduleAutosave();
      }
    }
    session.saveQueued = false;
    if (typeof options.onSaveStateChanged === 'function') {
      options.onSaveStateChanged();
    }
    throw error;
  } finally {
    session.saveInFlight = false;
    if (typeof options.onSaveStateChanged === 'function') {
      options.onSaveStateChanged();
    }
    session.savePromise = null;
    if (session.saveQueued) {
      session.saveQueued = false;
      if (id === String(state.notes.currentId || '') && state.notes.dirty && typeof options.scheduleAutosave === 'function') {
        options.scheduleAutosave();
      }
    }
  }
}

export async function loadNoteContent(noteId, options = {}) {
  const id = String(noteId || '').trim();
  if (!id) return;
  if (typeof options.cancelAutosave === 'function') {
    options.cancelAutosave();
  }
  const payload = await api(`/api/notes/get?id=${encodeURIComponent(id)}&_=${Date.now()}`);
  if (options.expectedGeneration !== undefined && options.expectedGeneration !== session.switchGeneration) {
    return null;
  }
  if (!payload.ok) throw new Error(payload.error || 'load note failed');

  const note = payload.note || { id, title: '', content: '' };
  state.notes.currentId = note.id;
  bindNoteSessionEditor(note.id);
  resetNoteSessionChangeVersion();
  markNoteSessionClean();
  updateNoteSessionLoadedRevision(note.id, Number(note.updatedAt || 0));

  if (typeof options.applyLoadedNote === 'function') {
    options.applyLoadedNote(note);
  }
  return note;
}

export async function loadNotesList(options = {}) {
  const payload = await api('/api/notes/list');
  if (!payload.ok) throw new Error(payload.error || 'load notes failed');
  state.notes.list = payload.notes || [];

  if (!state.notes.currentId || !state.notes.list.find((n) => n.id === state.notes.currentId)) {
    state.notes.currentId = state.notes.list[0]?.id || '';
  }

  if (typeof options.onListLoaded === 'function') {
    options.onListLoaded(state.notes.list);
  }

  if (state.notes.currentId) {
    return loadNoteContent(state.notes.currentId, options);
  }

  resetNoteSessionChangeVersion();
  clearNoteSessionEditorBinding();
  if (typeof options.onEmptyList === 'function') {
    options.onEmptyList();
  }
  return null;
}

export function applyNotesDraftState(draft = {}, options = {}) {
  const id = String(draft?.id || '').trim();
  const title = String(draft?.title || '').trim();
  const content = String(draft?.content || '');

  if (id) {
    state.notes.currentId = id;
    bindNoteSessionEditor(id);
  }

  if (typeof options.applyDraft === 'function') {
    options.applyDraft({
      id,
      title,
      content
    });
  }

  bumpNoteSessionChangeVersion();
  markNoteSessionDirty();
}

export async function selectNote(targetId, options = {}) {
  const id = String(targetId || '').trim();
  if (!id) return null;

  session.switchChain = session.switchChain
    .then(async () => {
      if (state.notes.currentId === id) return state.notes.currentId;

      if (typeof options.onBeforeSwitch === 'function') {
        options.onBeforeSwitch(id);
      }

      const generation = ++session.switchGeneration;
      if (typeof options.cancelAutosave === 'function') {
        options.cancelAutosave();
      }

      const fromId = String(state.notes.currentId || '');
      let pending = null;
      if (
        fromId
        && fromId !== id
        && state.notes.dirty
        && (!session.editorBoundId || fromId === session.editorBoundId)
        && typeof options.capturePayload === 'function'
      ) {
        pending = options.capturePayload(fromId);
        if (pending) {
          pending.dirty = true;
          pending.changeVersion = session.changeVersion;
        }
      }

      if (options.extractViewActive && state.notes.dirty && typeof options.saveExtractAggregateView === 'function') {
        await options.saveExtractAggregateView({ silent: true });
      } else if (pending?.dirty) {
        await saveNotePayload(pending, {
          ...options,
          silent: true,
          saveIntent: 'switch'
        });
      }

      if (generation !== session.switchGeneration) return null;

      if (typeof options.resetExtractViewState === 'function') {
        options.resetExtractViewState();
      }
      await loadNoteContent(id, {
        ...options,
        expectedGeneration: generation
      });
      return id;
    })
    .catch((error) => {
      if (typeof options.onSwitchError === 'function') {
        options.onSwitchError(error);
      }
      return null;
    });

  return session.switchChain;
}
