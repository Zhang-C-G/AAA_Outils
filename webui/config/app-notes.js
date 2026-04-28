import { state, byId, api, toast, setDirty, escapeHtml, confirmDialog } from './app-common.js';

const NOTES_AUTOSAVE_DELAY_MS = 700;
let notesAutosaveTimer = 0;
let notesSaveInFlight = false;
let notesSaveQueued = false;
let notesSavePromise = null;
let notesChangeVersion = 0;
let draggingNoteId = '';
let notesExplainCollapsed = true;
let notesSidebarCompact = false;
let extractSaveTimers = new Map();
let extractContextByNoteId = new Map();

function syncNotesExplainBar() {
  const bar = byId('notesExplainBar');
  const btn = byId('toggleNotesExplainBtn');
  if (!bar || !btn) return;
  bar.classList.toggle('collapsed', notesExplainCollapsed);
  btn.setAttribute('aria-expanded', notesExplainCollapsed ? 'false' : 'true');
  const caret = btn.querySelector('.notes-explain-caret');
  if (caret) {
    caret.textContent = notesExplainCollapsed ? '展开' : '收起';
  }
}

function syncNotesSidebar() {
  const layout = byId('notesLayoutRoot');
  const toggleBtn = byId('toggleNotesSidebarBtn');
  if (!layout || !toggleBtn) return;
  layout.classList.toggle('sidebar-compact', notesSidebarCompact);
  toggleBtn.textContent = notesSidebarCompact ? '展开列表' : '收起列表';
  toggleBtn.setAttribute('aria-expanded', notesSidebarCompact ? 'false' : 'true');
}

function escapeOutlineText(value) {
  return escapeHtml(String(value || '').trim());
}

function normalizeExtractMarker(value) {
  return String(value || '').trim();
}

function slugifyHeading(text, index) {
  const base = String(text || '')
    .trim()
    .toLowerCase()
    .replace(/[^\w\u4e00-\u9fa5]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return `${base || 'section'}-${index}`;
}

function parseNoteStructure(content) {
  const lines = String(content || '').replace(/\r\n/g, '\n').split('\n');
  const headings = [];

  lines.forEach((line, index) => {
    const match = /^(#{1,6})\s+(.+?)\s*$/.exec(line);
    if (match) {
      const level = match[1].length;
      const text = match[2].trim();
      headings.push({
        id: slugifyHeading(text, index),
        text,
        level
      });
    }
  });

  return {
    headings
  }
}

function extractRange(content, startMarker, endMarker) {
  const source = String(content || '');
  const start = normalizeExtractMarker(startMarker);
  const end = normalizeExtractMarker(endMarker);
  if (!start) return null;
  const startIndex = source.indexOf(start);
  if (startIndex < 0) return null;
  const bodyStart = startIndex + start.length;
  let bodyEnd = source.length;
  if (end) {
    const nextIndex = source.indexOf(end, bodyStart);
    if (nextIndex >= 0) {
      bodyEnd = nextIndex;
    }
  }
  return {
    bodyStart,
    bodyEnd,
    text: source.slice(bodyStart, bodyEnd)
  };
}

async function fetchNoteForExtraction(note) {
  if (String(note.id || '') === String(state.notes.currentId || '')) {
    return {
      id: String(note.id || ''),
      title: byId('noteTitle')?.value || note.title || 'Untitled',
      content: byId('noteContent')?.value || ''
    };
  }
  const payload = await api(`/api/notes/get?id=${encodeURIComponent(note.id)}`);
  if (!payload.ok) throw new Error(payload.error || 'load note failed');
  return payload.note || { id: String(note.id || ''), title: note.title || 'Untitled', content: '' };
}

function renderExtractResults(items) {
  const host = byId('notesExtractResults');
  if (!host) return;
  if (!items.length) {
    host.innerHTML = '<div class="notes-outline-empty">当前范围在现有笔记中没有命中结果。</div>';
    return;
  }

  host.innerHTML = items
    .map((item) => `
      <div class="notes-extract-result" data-note-id="${escapeOutlineText(item.id)}">
        <div class="notes-extract-result-head">
          <strong>${escapeOutlineText(item.title || 'Untitled')}</strong>
          <span>${escapeOutlineText(item.rangeLabel)}</span>
        </div>
        <textarea class="notes-extract-editor" data-note-id="${escapeOutlineText(item.id)}"></textarea>
      </div>
    `)
    .join('');

  items.forEach((item) => {
    const editor = host.querySelector(`.notes-extract-editor[data-note-id="${CSS.escape(item.id)}"]`);
    if (!editor) return;
    editor.value = item.text;
    editor.oninput = () => {
      queueExtractSave(item.id, editor.value);
    };
  });
}

function setExtractStatus(message) {
  const host = byId('notesExtractStatus');
  if (host) {
    host.textContent = message;
  }
}

async function saveExtractResult(noteId, nextText) {
  const context = extractContextByNoteId.get(noteId);
  if (!context) return;
  const updatedContent = context.fullContent.slice(0, context.bodyStart) + nextText + context.fullContent.slice(context.bodyEnd);
  const payload = await api('/api/notes/save', {
    method: 'POST',
    body: JSON.stringify({
      id: context.id,
      title: context.title,
      content: updatedContent
    })
  });
  if (!payload.ok) throw new Error(payload.error || 'save extracted note failed');
  context.fullContent = updatedContent;
  context.bodyEnd = context.bodyStart + nextText.length;

  if (String(context.id) === String(state.notes.currentId || '')) {
    byId('noteContent').value = updatedContent;
    renderNoteStructure();
    state.notes.dirty = false;
    setDirty(false, 'notes');
  }

  const entry = state.notes.list.find((item) => String(item.id || '') === String(context.id));
  if (entry) {
    entry.title = context.title;
  }
  renderNotesList();
}

function queueExtractSave(noteId, nextText) {
  if (extractSaveTimers.has(noteId)) {
    window.clearTimeout(extractSaveTimers.get(noteId));
  }
  const timer = window.setTimeout(() => {
    extractSaveTimers.delete(noteId);
    saveExtractResult(noteId, nextText).catch((error) => {
      toast(`提取内容保存失败: ${error.message}`);
    });
  }, 500);
  extractSaveTimers.set(noteId, timer);
}

async function runNotesExtraction() {
  const startMarker = normalizeExtractMarker(byId('notesExtractStart')?.value || '');
  const endMarker = normalizeExtractMarker(byId('notesExtractEnd')?.value || '');
  if (!startMarker) {
    toast('请先填写提取起点');
    return;
  }

  if (state.notes.dirty) {
    await saveCurrentNote({ silent: true });
  }

  setExtractStatus('正在提取各笔记内容...');
  extractContextByNoteId = new Map();
  const notes = Array.isArray(state.notes.list) ? state.notes.list : [];
  const items = [];

  for (const note of notes) {
    const fullNote = await fetchNoteForExtraction(note);
    const extracted = extractRange(fullNote.content || '', startMarker, endMarker);
    if (!extracted) continue;

    extractContextByNoteId.set(String(fullNote.id), {
      id: String(fullNote.id),
      title: fullNote.title || note.title || 'Untitled',
      fullContent: String(fullNote.content || ''),
      bodyStart: extracted.bodyStart,
      bodyEnd: extracted.bodyEnd
    });

    items.push({
      id: String(fullNote.id),
      title: fullNote.title || note.title || 'Untitled',
      text: extracted.text,
      rangeLabel: endMarker ? `${startMarker} -> ${endMarker}` : `${startMarker} -> 文末`
    });
  }

  renderExtractResults(items);
  setExtractStatus(items.length ? `已提取 ${items.length} 条笔记内容，可直接在下方修改。` : '当前范围在现有笔记中没有命中结果。');
}

function renderOutlineList(structure) {
  const host = byId('notesOutlineList');
  if (!host) return;
  const headings = Array.isArray(structure?.headings) ? structure.headings : [];
  if (!headings.length) {
    host.innerHTML = '<div class="notes-outline-empty">把一大段 Markdown 贴进右侧后，这里会自动列出目录结构。</div>';
    return;
  }

  host.innerHTML = headings
    .map((heading) => `
      <button class="notes-outline-item level-${Math.min(heading.level, 6)}" type="button">
        <span class="outline-indent depth-${Math.min(Math.max(heading.level - 1, 0), 5)}" aria-hidden="true"></span>
        <span class="outline-text">${escapeOutlineText(heading.text)}</span>
        <span class="level-label">H${heading.level}</span>
      </button>
    `)
    .join('');
}

function renderNoteStructure() {
  const content = byId('noteContent')?.value || '';
  const structure = parseNoteStructure(content);
  renderOutlineList(structure);
}

function renderNotesList() {
  const listEl = byId('notesList');
  listEl.innerHTML = '';

  for (const note of state.notes.list) {
    const item = document.createElement('div');
    item.className = `note-item ${note.id === state.notes.currentId ? 'active' : ''}`;
    item.draggable = true;
    item.dataset.id = note.id;
    item.innerHTML = `<div>${escapeHtml(note.title || 'Untitled')}</div>`;
    item.onclick = () => selectNote(note.id).catch((e) => toast(`切换失败: ${e.message}`));
    item.addEventListener('dragstart', (event) => {
      draggingNoteId = note.id;
      item.classList.add('dragging');
      event.dataTransfer.effectAllowed = 'move';
      event.dataTransfer.setData('text/plain', note.id);
    });
    item.addEventListener('dragend', () => {
      draggingNoteId = '';
      item.classList.remove('dragging');
      for (const node of listEl.querySelectorAll('.drag-target')) {
        node.classList.remove('drag-target');
      }
    });
    item.addEventListener('dragover', (event) => {
      event.preventDefault();
      if (!draggingNoteId || draggingNoteId === note.id) return;
      item.classList.add('drag-target');
    });
    item.addEventListener('dragleave', () => {
      item.classList.remove('drag-target');
    });
    item.addEventListener('drop', (event) => {
      event.preventDefault();
      item.classList.remove('drag-target');
      const fromId = event.dataTransfer.getData('text/plain');
      if (!fromId || fromId === note.id) return;
      const from = state.notes.list.findIndex((entry) => entry.id === fromId);
      const to = state.notes.list.findIndex((entry) => entry.id === note.id);
      if (from < 0 || to < 0) return;
      const [moving] = state.notes.list.splice(from, 1);
      state.notes.list.splice(to, 0, moving);
      renderNotesList();
      void persistNotesOrder().catch((e) => toast(`笔记排序保存失败: ${e.message}`));
    });
    listEl.appendChild(item);
  }
}

async function persistNotesOrder() {
  const order = (state.notes.list || []).map((note) => String(note.id || '').trim()).filter(Boolean);
  const payload = await api('/api/notes/reorder', {
    method: 'POST',
    body: JSON.stringify({ order })
  });
  if (!payload.ok) throw new Error(payload.error || 'reorder notes failed');
  state.notes.list = payload.notes || state.notes.list;
  renderNotesList();
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
  renderNoteStructure();
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
    renderNoteStructure();
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
  byId('toggleNotesSidebarBtn').onclick = () => {
    notesSidebarCompact = !notesSidebarCompact;
    syncNotesSidebar();
  };

  byId('toggleNotesExplainBtn').onclick = () => {
    notesExplainCollapsed = !notesExplainCollapsed;
    syncNotesExplainBar();
  };

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
    renderNoteStructure();
    scheduleNotesAutosave();
  };

  byId('copyNoteOutlineBtn').onclick = async () => {
    const structure = parseNoteStructure(byId('noteContent')?.value || '');
    const headings = Array.isArray(structure?.headings) ? structure.headings : [];
    if (!headings.length) {
      toast('当前没有可复制的目录');
      return;
    }
    const outlineText = headings.map((heading) => `${'  '.repeat(Math.max(heading.level - 1, 0))}${heading.text}`).join('\n');
    try {
      await navigator.clipboard.writeText(outlineText);
      toast('目录已复制');
    } catch (error) {
      toast(`目录复制失败: ${error.message}`);
    }
  };

  byId('runNotesExtractBtn').onclick = () => {
    runNotesExtraction().catch((error) => {
      toast(`提取失败: ${error.message}`);
      setExtractStatus('提取失败，请检查范围后重试。');
    });
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
    if (!(await confirmDialog('确认删除当前笔记吗？', { title: '删除笔记', confirmText: '删除', danger: true }))) return;

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

  syncNotesExplainBar();
  syncNotesSidebar();
}

