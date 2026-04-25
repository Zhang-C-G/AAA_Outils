import { state, byId, api, toast, setDirty, escapeHtml } from './app-common.js';

const NOTES_AUTOSAVE_DELAY_MS = 700;
let notesAutosaveTimer = 0;
let notesSaveInFlight = false;
let notesSaveQueued = false;
let notesSavePromise = null;
let notesChangeVersion = 0;

function renderNotesList() {
  const listEl = byId('notesList');
  listEl.innerHTML = '';

  for (const note of state.notes.list) {
    const item = document.createElement('div');
    item.className = `note-item ${note.id === state.notes.currentId ? 'active' : ''}`;
    item.innerHTML = `<div>${escapeHtml(note.title || 'Untitled')}</div>`;
    item.onclick = () => selectNote(note.id).catch((e) => toast(`切换失败: ${e.message}`));
    listEl.appendChild(item);
  }
}

function cancelNotesAutosave() {
  if (!notesAutosaveTimer) return;
  window.clearTimeout(notesAutosaveTimer);
  notesAutosaveTimer = 0;
}

function updateCurrentNoteMeta(title) {
  const id = String(state.notes.currentId || '').trim();
  if (!id) return;
  const nextTitle = String(title || '').trim() || 'Untitled';
  const list = Array.isArray(state.notes.list) ? state.notes.list : [];
  const existing = list.find((note) => String(note.id || '').trim() === id);
  if (existing) {
    existing.title = nextTitle;
  } else {
    list.unshift({ id, title: nextTitle, updated: '' });
    state.notes.list = list;
  }
  renderNotesList();
}

async function loadNoteContent(id) {
  cancelNotesAutosave();
  const payload = await api(`/api/notes/get?id=${encodeURIComponent(id)}`);
  if (!payload.ok) throw new Error(payload.error || 'load note failed');
  const note = payload.note || { id, title: '', content: '' };
  state.notes.currentId = note.id;
  byId('noteTitle').value = note.title || '';
  byId('noteContent').value = note.content || '';
  notesChangeVersion = 0;
  state.notes.dirty = false;
  setDirty(false, 'notes');
  renderNotesList();
}

export async function loadNotes() {
  const payload = await api('/api/notes/list');
  if (!payload.ok) throw new Error(payload.error || 'load notes failed');
  state.notes.list = payload.notes || [];

  if (!state.notes.currentId || !state.notes.list.find((n) => n.id === state.notes.currentId)) {
    state.notes.currentId = state.notes.list[0]?.id || '';
  }

  renderNotesList();
  if (state.notes.currentId) {
    await loadNoteContent(state.notes.currentId);
  } else {
    cancelNotesAutosave();
    notesChangeVersion = 0;
    byId('noteTitle').value = '';
    byId('noteContent').value = '';
  }
}

function scheduleNotesAutosave() {
  cancelNotesAutosave();
  notesAutosaveTimer = window.setTimeout(() => {
    notesAutosaveTimer = 0;
    void saveCurrentNote({ silent: true }).catch((error) => {
      toast(`自动保存失败: ${error.message}`);
    });
  }, NOTES_AUTOSAVE_DELAY_MS);
}

export async function saveCurrentNote(options = {}) {
  const silent = !!options.silent;
  const id = state.notes.currentId;
  if (!id) {
    if (!silent) {
      toast('请先新建笔记');
    }
    return;
  }

  if (notesSaveInFlight) {
    notesSaveQueued = true;
    await notesSavePromise;
    if (state.notes.dirty) {
      return saveCurrentNote(options);
    }
    return;
  }

  cancelNotesAutosave();
  notesSaveInFlight = true;
  const saveVersion = notesChangeVersion;
  const title = byId('noteTitle').value;
  const content = byId('noteContent').value;

  try {
    notesSavePromise = api('/api/notes/save', {
      method: 'POST',
      body: JSON.stringify({ id, title, content })
    });
    const payload = await notesSavePromise;
    if (!payload.ok) throw new Error(payload.error || 'save note failed');
    updateCurrentNoteMeta(title);
    if (saveVersion === notesChangeVersion) {
      state.notes.dirty = false;
      setDirty(false, 'notes');
    }
    if (!silent) {
      toast('笔记已保存');
    }
  } finally {
    notesSaveInFlight = false;
    notesSavePromise = null;
    if (notesSaveQueued) {
      notesSaveQueued = false;
      scheduleNotesAutosave();
    }
  }
}

export async function selectNote(id) {
  if (state.notes.currentId === id) return;
  if (state.notes.dirty) {
    await saveCurrentNote({ silent: true });
  }
  await loadNoteContent(id);
}

export function initNotesHandlers() {
  byId('noteTitle').oninput = () => {
    notesChangeVersion += 1;
    state.notes.dirty = true;
    setDirty(true, 'notes');
    updateCurrentNoteMeta(byId('noteTitle').value);
    scheduleNotesAutosave();
  };
  byId('noteContent').oninput = () => {
    notesChangeVersion += 1;
    state.notes.dirty = true;
    setDirty(true, 'notes');
    scheduleNotesAutosave();
  };

  byId('newNoteBtn').onclick = async () => {
    if (state.notes.dirty) {
      await saveCurrentNote({ silent: true });
    }
    const payload = await api('/api/notes/create', {
      method: 'POST',
      body: JSON.stringify({ title: 'New Note' })
    });
    if (!payload.ok) throw new Error(payload.error || 'new note failed');
    state.notes.currentId = payload.id;
    await loadNotes();
    toast('已新建笔记');
  };

  byId('deleteNoteBtn').onclick = async () => {
    const id = state.notes.currentId;
    if (!id) return;
    if (!confirm('确认删除当前笔记吗？')) return;
    if (!confirm('二次确认：删除后不可恢复，继续吗？')) return;

    const payload = await api('/api/notes/delete', {
      method: 'POST',
      body: JSON.stringify({ id })
    });
    if (!payload.ok) throw new Error(payload.error || 'delete note failed');

    cancelNotesAutosave();
    notesChangeVersion = 0;
    state.notes.currentId = '';
    state.notes.dirty = false;
    setDirty(false, 'notes');
    await loadNotes();
    toast('笔记已删除');
  };
}
