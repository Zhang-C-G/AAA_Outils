import { state, byId, api, toast, setDirty, escapeHtml, confirmDialog } from './app-common.js';

const NOTES_AUTOSAVE_DELAY_MS = 700;
let notesAutosaveTimer = 0;
let notesSaveInFlight = false;
let notesSaveQueued = false;
let notesSavePromise = null;
let notesChangeVersion = 0;
let draggingNoteId = '';
let selectedDirectoryKey = '__all__';
let notesExplainCollapsed = true;
let notesSidebarCompact = false;

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
  const directories = [];
  const extracts = [];
  let currentDirectoryId = '__root__';
  let currentDirectoryName = '未归类';

  lines.forEach((line, index) => {
    const match = /^(#{1,6})\s+(.+?)\s*$/.exec(line);
    if (match) {
      const level = match[1].length;
      const text = match[2].trim();
      const heading = {
        id: slugifyHeading(text, index),
        text,
        level,
        directoryId: currentDirectoryId,
        directoryName: currentDirectoryName
      };

      if (level <= 2) {
        currentDirectoryId = heading.id;
        currentDirectoryName = text;
        heading.directoryId = currentDirectoryId;
        heading.directoryName = currentDirectoryName;
        directories.push({ id: currentDirectoryId, name: currentDirectoryName });
      } else if (!directories.length) {
        heading.directoryId = '__root__';
        heading.directoryName = '未归类';
      } else {
        heading.directoryId = currentDirectoryId;
        heading.directoryName = currentDirectoryName;
      }

      headings.push(heading);
    }

    const labelMatch = /^\*\*(.+?)[:：]\*\*\s*(.*)$/.exec(line.trim());
    if (labelMatch && labelMatch[1].trim() === '结论式开场') {
      const parts = [];
      if (labelMatch[2]) {
        parts.push(labelMatch[2].trim());
      }
      let next = index + 1;
      while (next < lines.length) {
        const nextLine = lines[next].trim();
        if (!nextLine) {
          next += 1;
          continue;
        }
        if (/^\*\*(.+?)[:：]\*\*/.test(nextLine) || /^(#{1,6})\s+/.test(nextLine)) {
          break;
        }
        parts.push(nextLine);
        next += 1;
      }
      extracts.push({
        directoryName: currentDirectoryName,
        text: parts.join(' ').trim() || '当前结论式开场后还没有正文内容。'
      });
    }
  });

  return {
    headings,
    directories,
    extracts
  };
}

function getFilteredHeadings(structure) {
  const headings = Array.isArray(structure?.headings) ? structure.headings : [];
  if (selectedDirectoryKey === '__all__') return headings;
  return headings.filter((heading) => heading.directoryId === selectedDirectoryKey);
}

function getFilteredExtracts(structure) {
  const extracts = Array.isArray(structure?.extracts) ? structure.extracts : [];
  if (selectedDirectoryKey === '__all__') return extracts;
  return extracts.filter((item) => item.directoryName === getSelectedDirectoryName(structure));
}

function getSelectedDirectoryName(structure) {
  const directories = Array.isArray(structure?.directories) ? structure.directories : [];
  return directories.find((item) => item.id === selectedDirectoryKey)?.name || '未归类';
}

function renderDirectoryChips(structure) {
  const host = byId('notesModuleChips');
  if (!host) return;
  const directories = Array.isArray(structure?.directories) ? structure.directories : [];
  if (selectedDirectoryKey !== '__all__' && !directories.find((item) => item.id === selectedDirectoryKey)) {
    selectedDirectoryKey = '__all__';
  }

  const items = [{ id: '__all__', name: '全部目录' }, ...directories];
  host.innerHTML = items
    .map((item) => `<button class="chip ${item.id === selectedDirectoryKey ? 'active' : ''}" type="button" data-directory-id="${escapeOutlineText(item.id)}">${escapeOutlineText(item.name)}</button>`)
    .join('');

  host.querySelectorAll('[data-directory-id]').forEach((button) => {
    button.onclick = () => {
      selectedDirectoryKey = button.dataset.directoryId || '__all__';
      renderNoteStructure();
    };
  });
}

function renderOutlineList(structure) {
  const host = byId('notesOutlineList');
  if (!host) return;
  const headings = getFilteredHeadings(structure);
  if (!headings.length) {
    host.innerHTML = '<div class="notes-outline-empty">当前筛选下还没有可识别的目录项。</div>';
    return;
  }

  host.innerHTML = headings
    .map((heading) => `
      <button class="notes-outline-item level-${Math.min(heading.level, 6)}" type="button">
        <span class="outline-text">${escapeOutlineText(heading.text)}</span>
        <span class="level-label">H${heading.level}</span>
      </button>
    `)
    .join('');
}

function renderStructureSummary(structure) {
  const host = byId('notesStructureSummary');
  if (!host) return;
  const headings = Array.isArray(structure?.headings) ? structure.headings : [];
  const directories = Array.isArray(structure?.directories) ? structure.directories : [];
  if (!headings.length) {
    host.textContent = '当前笔记还没有可识别的 Markdown 标题。建议后续按目录块使用 H1/H2 标题，便于大体量内容拆块。';
    return;
  }
  host.textContent = `已识别 ${headings.length} 个目录项，${directories.length || 1} 个目录块。当前第一阶段默认以 H1/H2 作为笔记目录的分段基准。`;
}

function renderExtractList(structure) {
  const host = byId('notesExtractList');
  if (!host) return;
  const extracts = getFilteredExtracts(structure);
  if (!extracts.length) {
    host.innerHTML = '<div class="notes-outline-empty">检测到 `**结论式开场：**` 后，这里会单独列出提取结果。</div>';
    return;
  }
  host.innerHTML = extracts
    .map((item, index) => `
      <div class="notes-extract-item">
        <strong>结论式开场 ${index + 1}${item.directoryName && item.directoryName !== '未归类' ? ` · ${escapeOutlineText(item.directoryName)}` : ''}</strong>
        <span>${escapeOutlineText(item.text)}</span>
      </div>
    `)
    .join('');
}

function renderNoteStructure() {
  const content = byId('noteContent')?.value || '';
  const structure = parseNoteStructure(content);
  renderStructureSummary(structure);
  renderDirectoryChips(structure);
  renderOutlineList(structure);
  renderExtractList(structure);
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
  selectedDirectoryKey = '__all__';
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
    selectedDirectoryKey = '__all__';
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
    const headings = getFilteredHeadings(structure);
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

