import { state, byId, api, toast, setDirty, escapeHtml } from './app-common.js';

function renderNotesList() {
  const listEl = byId('notesList');
  listEl.innerHTML = '';

  for (const note of state.notes.list) {
    const item = document.createElement('div');
    item.className = `note-item ${note.id === state.notes.currentId ? 'active' : ''}`;
    item.innerHTML = `<div>${escapeHtml(note.title || 'Untitled')}</div>`;
    item.onclick = () => selectNote(note.id).catch(e => toast(`切换失败: ${e.message}`));
    listEl.appendChild(item);
  }
}

async function loadNoteContent(id) {
  const payload = await api(`/api/notes/get?id=${encodeURIComponent(id)}`);
  if (!payload.ok) throw new Error(payload.error || 'load note failed');
  const note = payload.note || { id, title: '', content: '' };
  state.notes.currentId = note.id;
  byId('noteTitle').value = note.title || '';
  byId('noteContent').value = note.content || '';
  state.notes.dirty = false;
  setDirty(false, 'notes');
  renderNotesList();
}

export async function loadNotes() {
  const payload = await api('/api/notes/list');
  if (!payload.ok) throw new Error(payload.error || 'load notes failed');
  state.notes.list = payload.notes || [];

  if (!state.notes.currentId || !state.notes.list.find(n => n.id === state.notes.currentId)) {
    state.notes.currentId = state.notes.list[0]?.id || '';
  }

  renderNotesList();
  if (state.notes.currentId) {
    await loadNoteContent(state.notes.currentId);
  } else {
    byId('noteTitle').value = '';
    byId('noteContent').value = '';
  }
}

export async function saveCurrentNote() {
  const id = state.notes.currentId;
  if (!id) {
    toast('请先新建笔记');
    return;
  }
  const title = byId('noteTitle').value;
  const content = byId('noteContent').value;
  const payload = await api('/api/notes/save', {
    method: 'POST',
    body: JSON.stringify({ id, title, content })
  });
  if (!payload.ok) throw new Error(payload.error || 'save note failed');
  state.notes.dirty = false;
  setDirty(false, 'notes');
  await loadNotes();
  toast('笔记已保存');
}

export async function selectNote(id) {
  if (state.notes.currentId === id) return;
  if (state.notes.dirty) {
    await saveCurrentNote();
  }
  await loadNoteContent(id);
}

export function initNotesHandlers() {
  byId('noteTitle').oninput = () => {
    state.notes.dirty = true;
    setDirty(true, 'notes');
  };
  byId('noteContent').oninput = () => {
    state.notes.dirty = true;
    setDirty(true, 'notes');
  };

  byId('newNoteBtn').onclick = async () => {
    if (state.notes.dirty) {
      await saveCurrentNote();
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

  byId('saveNoteBtn').onclick = () => saveCurrentNote().catch(e => toast(`保存失败: ${e.message}`));

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

    state.notes.currentId = '';
    state.notes.dirty = false;
    setDirty(false, 'notes');
    await loadNotes();
    toast('笔记已删除');
  };
}
