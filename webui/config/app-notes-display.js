import { state, byId, api, toast, setDirty, escapeHtml } from './app-common.js';

function hotkeyToFriendly(hk) {
  const raw = String(hk || '').trim();
  if (!raw) return '(未设置)';

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

  let key = raw.slice(i);
  if (!key) return raw;
  const low = key.toLowerCase();
  if (low === 'esc') key = 'Esc';
  else if (low === 'enter') key = 'Enter';
  else if (low === 'up') key = 'Up';
  else if (low === 'down') key = 'Down';
  else if (/^[a-z0-9]$/i.test(key)) key = key.toUpperCase();
  else if (/^f([1-9]|1[0-9]|2[0-4])$/i.test(key)) key = key.toUpperCase();
  return mods.length ? `${mods.join('+')}+${key}` : key;
}

function renderNotesDisplayHotkeyExplain() {
  const el = byId('notesDisplayHotkeyExplain');
  if (!el) return;
  const hkOpen = hotkeyToFriendly(state.hotkeys?.notes_display_overlay || 'F4');
  el.textContent = `快捷键说明（自动同步配置）：启动笔记显示悬浮窗 ${hkOpen}；在本页写入 Markdown 后会自动解析目录；点击目录后正文预览自动跳转。`;
}

function renderNotesDisplayList() {
  const listEl = byId('notesDisplayList');
  if (!listEl) return;
  listEl.innerHTML = '';

  for (const note of state.notesDisplay.list) {
    const item = document.createElement('div');
    item.className = `note-item ${note.id === state.notesDisplay.currentId ? 'active' : ''}`;
    item.innerHTML = `<div>${escapeHtml(note.title || 'Untitled')}</div>`;
    item.onclick = () => selectNotesDisplayNote(note.id).catch((e) => toast(`切换失败: ${e.message}`));
    listEl.appendChild(item);
  }
}

function renderInlineMarkdown(text) {
  let out = escapeHtml(text);
  out = out.replace(/`([^`]+)`/g, '<code>$1</code>');
  out = out.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  out = out.replace(/__([^_]+)__/g, '<strong>$1</strong>');
  out = out.replace(/\*([^*]+)\*/g, '<em>$1</em>');
  out = out.replace(/_([^_]+)_/g, '<em>$1</em>');
  return out;
}

function slugifyHeading(text, index) {
  const base = String(text || '')
    .trim()
    .toLowerCase()
    .replace(/[^\w\u4e00-\u9fa5-]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
  return `${base || 'section'}-${index}`;
}

function buildMarkdownPreview(markdown) {
  const lines = String(markdown || '').replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
  const toc = [];
  const html = [];
  let paragraph = [];
  let listItems = [];
  let listType = '';
  let inCode = false;
  let codeLines = [];
  let headingIndex = 0;

  const flushParagraph = () => {
    if (!paragraph.length) return;
    html.push(`<p>${renderInlineMarkdown(paragraph.join(' '))}</p>`);
    paragraph = [];
  };

  const flushList = () => {
    if (!listItems.length) return;
    const tag = listType === 'ol' ? 'ol' : 'ul';
    html.push(`<${tag}>${listItems.map((item) => `<li>${renderInlineMarkdown(item)}</li>`).join('')}</${tag}>`);
    listItems = [];
    listType = '';
  };

  const flushCode = () => {
    if (!inCode) return;
    html.push(`<pre><code>${escapeHtml(codeLines.join('\n'))}</code></pre>`);
    inCode = false;
    codeLines = [];
  };

  for (const rawLine of lines) {
    const line = rawLine ?? '';
    const trimmed = line.trim();

    if (trimmed.startsWith('```')) {
      flushParagraph();
      flushList();
      if (inCode) {
        flushCode();
      } else {
        inCode = true;
        codeLines = [];
      }
      continue;
    }

    if (inCode) {
      codeLines.push(line);
      continue;
    }

    const headingMatch = trimmed.match(/^(#{1,6})\s+(.+)$/);
    if (headingMatch) {
      flushParagraph();
      flushList();
      headingIndex += 1;
      const level = headingMatch[1].length;
      const text = headingMatch[2].trim();
      const id = slugifyHeading(text, headingIndex);
      toc.push({ id, text, level });
      html.push(`<h${level} data-heading-id="${id}" id="${id}">${renderInlineMarkdown(text)}</h${level}>`);
      continue;
    }

    const orderedMatch = trimmed.match(/^\d+\.\s+(.+)$/);
    if (orderedMatch) {
      flushParagraph();
      if (listType && listType !== 'ol') flushList();
      listType = 'ol';
      listItems.push(orderedMatch[1]);
      continue;
    }

    const bulletMatch = trimmed.match(/^[-*+]\s+(.+)$/);
    if (bulletMatch) {
      flushParagraph();
      if (listType && listType !== 'ul') flushList();
      listType = 'ul';
      listItems.push(bulletMatch[1]);
      continue;
    }

    if (!trimmed) {
      flushParagraph();
      flushList();
      continue;
    }

    if (listItems.length) flushList();
    paragraph.push(trimmed);
  }

  flushParagraph();
  flushList();
  flushCode();

  return { toc, html: html.join('') };
}

function renderNotesDisplayPreview() {
  const tocEl = byId('notesDisplayPreviewToc');
  const bodyEl = byId('notesDisplayPreviewBody');
  const title = byId('notesDisplayTitle')?.value || '';
  const content = byId('notesDisplayContent')?.value || '';
  if (!tocEl || !bodyEl) return;

  const source = `${title ? `# ${title}\n\n` : ''}${content}`;
  const parsed = buildMarkdownPreview(source);

  if (!parsed.toc.length) {
    tocEl.innerHTML = '<div class="notes-display-preview-empty">当前没有可用于生成目录的 Markdown 标题。</div>';
  } else {
    tocEl.innerHTML = parsed.toc
      .map((item) => `<button class="notes-display-toc-item level-${item.level}" type="button" data-target="${item.id}">${escapeHtml(item.text)}</button>`)
      .join('');
  }

  if (!parsed.html.trim()) {
    bodyEl.innerHTML = '<div class="notes-display-preview-empty">当前没有可预览的正文内容。</div>';
  } else {
    bodyEl.innerHTML = parsed.html;
  }

  tocEl.querySelectorAll('[data-target]').forEach((btn) => {
    btn.onclick = () => {
      const target = document.getElementById(btn.dataset.target || '');
      if (target) {
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    };
  });
}

async function loadNotesDisplayContent(id) {
  const payload = await api(`/api/notes-display/get?id=${encodeURIComponent(id)}`);
  if (!payload.ok) throw new Error(payload.error || 'load notes display note failed');
  const note = payload.note || { id, title: '', content: '' };
  state.notesDisplay.currentId = note.id;
  byId('notesDisplayTitle').value = note.title || '';
  byId('notesDisplayContent').value = note.content || '';
  state.notesDisplay.dirty = false;
  setDirty(false, 'notes_display');
  renderNotesDisplayList();
  renderNotesDisplayHotkeyExplain();
  renderNotesDisplayPreview();
}

export async function loadNotesDisplayNotes() {
  const payload = await api('/api/notes-display/list');
  if (!payload.ok) throw new Error(payload.error || 'load notes display notes failed');
  state.notesDisplay.list = payload.notes || [];

  if (!state.notesDisplay.currentId || !state.notesDisplay.list.find((n) => n.id === state.notesDisplay.currentId)) {
    state.notesDisplay.currentId = state.notesDisplay.list[0]?.id || '';
  }

  renderNotesDisplayList();
  renderNotesDisplayHotkeyExplain();
  if (state.notesDisplay.currentId) {
    await loadNotesDisplayContent(state.notesDisplay.currentId);
  } else {
    byId('notesDisplayTitle').value = '';
    byId('notesDisplayContent').value = '';
    renderNotesDisplayPreview();
  }
}

export async function saveCurrentNotesDisplayNote() {
  const id = state.notesDisplay.currentId;
  if (!id) {
    toast('请先新建笔记显示内容');
    return;
  }
  const title = byId('notesDisplayTitle').value;
  const content = byId('notesDisplayContent').value;
  const payload = await api('/api/notes-display/save', {
    method: 'POST',
    body: JSON.stringify({ id, title, content })
  });
  if (!payload.ok) throw new Error(payload.error || 'save notes display note failed');
  state.notesDisplay.dirty = false;
  setDirty(false, 'notes_display');
  await loadNotesDisplayNotes();
  toast('笔记显示内容已保存');
}

export async function selectNotesDisplayNote(id) {
  if (state.notesDisplay.currentId === id) return;
  if (state.notesDisplay.dirty) {
    await saveCurrentNotesDisplayNote();
  }
  await loadNotesDisplayContent(id);
}

export function initNotesDisplayHandlers() {
  byId('notesDisplayTitle').oninput = () => {
    state.notesDisplay.dirty = true;
    setDirty(true, 'notes_display');
    renderNotesDisplayPreview();
  };
  byId('notesDisplayContent').oninput = () => {
    state.notesDisplay.dirty = true;
    setDirty(true, 'notes_display');
    renderNotesDisplayPreview();
  };

  byId('newNotesDisplayBtn').onclick = async () => {
    if (state.notesDisplay.dirty) {
      await saveCurrentNotesDisplayNote();
    }
    const payload = await api('/api/notes-display/create', {
      method: 'POST',
      body: JSON.stringify({ title: 'New Note' })
    });
    if (!payload.ok) throw new Error(payload.error || 'new notes display note failed');
    state.notesDisplay.currentId = payload.id;
    await loadNotesDisplayNotes();
    toast('已新建笔记显示内容');
  };

  byId('saveNotesDisplayBtn').onclick = () => saveCurrentNotesDisplayNote().catch((e) => toast(`保存失败: ${e.message}`));

  byId('deleteNotesDisplayBtn').onclick = async () => {
    const id = state.notesDisplay.currentId;
    if (!id) return;
    if (!confirm('确认删除当前笔记显示内容吗？')) return;
    if (!confirm('二次确认：删除后不可恢复，继续吗？')) return;

    const payload = await api('/api/notes-display/delete', {
      method: 'POST',
      body: JSON.stringify({ id })
    });
    if (!payload.ok) throw new Error(payload.error || 'delete notes display note failed');

    state.notesDisplay.currentId = '';
    state.notesDisplay.dirty = false;
    setDirty(false, 'notes_display');
    await loadNotesDisplayNotes();
    toast('笔记显示内容已删除');
  };

  renderNotesDisplayHotkeyExplain();
  renderNotesDisplayPreview();
}
