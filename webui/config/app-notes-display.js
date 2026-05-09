import { state, byId, api, toast, setDirty, escapeHtml, confirmDialog } from './app-common.js';

const NOTES_DISPLAY_AUTOSAVE_DELAY_MS = 700;
let notesDisplayAutosaveTimer = 0;
let notesDisplayLoading = false;
let notesDisplayPreviewEditing = false;
let notesDisplaySidebarCompact = false;
let notesDisplayContentView = 'rendered';
let notesDisplayStructureCache = [];
let activeNotesDisplayHeadingId = '';
let activeNotesDisplayPreviewHeadingEl = null;

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
  const hkUp = hotkeyToFriendly(state.hotkeys?.notes_overlay_up || 'Up');
  const hkDown = hotkeyToFriendly(state.hotkeys?.notes_overlay_down || 'Down');
  el.textContent = `快捷键说明（自动同步配置）：启动笔记显示悬浮窗 ${hkOpen}；目录上移 ${hkUp}；目录下移 ${hkDown}；在本页写入 Markdown 后会自动解析目录；点击目录或使用上下键后正文预览自动跳转。`;
}

function syncNotesDisplaySidebar() {
  const layout = byId('notesDisplayLayoutRoot');
  const toggleBtn = byId('toggleNotesDisplaySidebarBtn');
  if (!layout || !toggleBtn) return;
  layout.classList.toggle('sidebar-compact', notesDisplaySidebarCompact);
  toggleBtn.textContent = notesDisplaySidebarCompact ? '展开列表' : '收起列表';
  toggleBtn.setAttribute('aria-expanded', notesDisplaySidebarCompact ? 'false' : 'true');
}

async function persistNotesDisplaySidebarCompact() {
  const value = notesDisplaySidebarCompact ? 1 : 0;
  state.app.notes_display_sidebar_compact = value;
  await api('/api/app/notes-display-sidebar', {
    method: 'POST',
    body: JSON.stringify({ notes_display_sidebar_compact: value })
  });
}

function deriveNotesDisplayTitle(content) {
  const lines = String(content || '').replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
  for (const raw of lines) {
    const trimmed = raw.trim();
    if (!trimmed) continue;
    const heading = trimmed.match(/^#{1,6}\s+(.+)$/);
    const text = heading ? heading[1].trim() : trimmed;
    if (!text) continue;
    return text.slice(0, 60);
  }
  return 'Untitled';
}

async function ensureNotesDisplayCurrentId() {
  if (state.notesDisplay.currentId) return state.notesDisplay.currentId;
  const payload = await api('/api/notes-display/create', {
    method: 'POST',
    body: JSON.stringify({ title: 'Untitled' })
  });
  if (!payload.ok || !payload.id) {
    throw new Error(payload.error || 'create notes display note failed');
  }
  state.notesDisplay.currentId = String(payload.id);
  return state.notesDisplay.currentId;
}

function renderNotesDisplayList() {
  const listEl = byId('notesDisplayList');
  if (!listEl) return;
  listEl.innerHTML = '';

  if (!Array.isArray(state.notesDisplay.list) || state.notesDisplay.list.length === 0) {
    listEl.innerHTML = '<div class="notes-display-list-empty">当前还没有可展示内容。先在右侧写入 Markdown，系统会自动保存并生成目录与预览。</div>';
    return;
  }

  for (const note of state.notesDisplay.list) {
    const item = document.createElement('div');
    item.className = `note-item ${note.id === state.notesDisplay.currentId ? 'active' : ''}`;
    item.innerHTML = `<div class="note-item-title">${escapeHtml(note.title || 'Untitled')}</div>`;
    item.onclick = () => selectNotesDisplayNote(note.id).catch((e) => toast(`切换失败: ${e.message}`));
    listEl.appendChild(item);
  }

  const createWrap = document.createElement('div');
  createWrap.className = 'notes-list-create-wrap';
  createWrap.innerHTML = '<button id="newNotesDisplayBtnInline" class="notes-create-btn" type="button" aria-label="新建笔记显示">+</button>';
  listEl.appendChild(createWrap);

  const inlineCreateBtn = createWrap.querySelector('#newNotesDisplayBtnInline');
  if (inlineCreateBtn) {
    inlineCreateBtn.onclick = () => {
      createNewNotesDisplayNote().catch((error) => {
        toast(`新建失败: ${error.message}`);
      });
    };
  }
}

async function createNewNotesDisplayNote() {
  if (state.notesDisplay.dirty) {
    await saveCurrentNotesDisplayNote({ silent: true });
  }
  const payload = await api('/api/notes-display/create', {
    method: 'POST',
    body: JSON.stringify({ title: 'Untitled' })
  });
  if (!payload.ok || !payload.id) {
    throw new Error(payload.error || 'create notes display note failed');
  }
  state.notesDisplay.currentId = String(payload.id);
  await loadNotesDisplayNotes();
  toast('已新建内容');
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

function syncNotesDisplayContentMode() {
  const markdownBtn = byId('notesDisplayViewMarkdownBtn');
  const renderedBtn = byId('notesDisplayViewRenderedBtn');
  const sourceEl = byId('notesDisplayContent');
  const previewEl = byId('notesDisplayPreviewBody');
  const showingMarkdown = notesDisplayContentView === 'markdown';

  if (markdownBtn) {
    markdownBtn.classList.toggle('active', showingMarkdown);
    markdownBtn.setAttribute('aria-pressed', showingMarkdown ? 'true' : 'false');
  }
  if (renderedBtn) {
    renderedBtn.classList.toggle('active', !showingMarkdown);
    renderedBtn.setAttribute('aria-pressed', showingMarkdown ? 'false' : 'true');
  }
  if (sourceEl) {
    sourceEl.classList.toggle('visible', showingMarkdown);
    sourceEl.setAttribute('aria-hidden', showingMarkdown ? 'false' : 'true');
  }
  if (previewEl) {
    previewEl.classList.toggle('hidden', showingMarkdown);
    previewEl.setAttribute('aria-hidden', showingMarkdown ? 'true' : 'false');
  }
}

function setNotesDisplayContentView(mode) {
  notesDisplayContentView = mode === 'markdown' ? 'markdown' : 'rendered';
  syncNotesDisplayContentMode();
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
    html.push(`<p>${renderInlineMarkdown(paragraph.join('\n'))}</p>`);
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

function syncActiveNotesDisplayHeading() {
  const host = byId('notesDisplayOutlineList');
  if (!host) return;
  host.querySelectorAll('.notes-outline-item.active').forEach((node) => {
    if (node.getAttribute('data-outline-id') !== activeNotesDisplayHeadingId) {
      node.classList.remove('active');
    }
  });
  if (!activeNotesDisplayHeadingId) return;
  const activeNode = host.querySelector(`.notes-outline-item[data-outline-id="${activeNotesDisplayHeadingId}"]`);
  if (activeNode) activeNode.classList.add('active');
}

function scrollNotesDisplayPreviewToHeading(headingId) {
  const previewEl = byId('notesDisplayPreviewBody');
  const headingEl = previewEl?.querySelector(`[data-heading-id="${headingId}"]`);
  if (!previewEl || !headingEl) return false;

  const previewRect = previewEl.getBoundingClientRect();
  const headingRect = headingEl.getBoundingClientRect();
  const relativeTop = headingRect.top - previewRect.top + previewEl.scrollTop;
  const nextTop = Math.max(relativeTop - 12, 0);
  previewEl.scrollTop = nextTop;

  if (activeNotesDisplayPreviewHeadingEl && activeNotesDisplayPreviewHeadingEl !== headingEl) {
    activeNotesDisplayPreviewHeadingEl.classList.remove('notes-preview-active-heading');
  }
  headingEl.classList.add('notes-preview-active-heading');
  activeNotesDisplayPreviewHeadingEl = headingEl;
  window.clearTimeout(focusNotesDisplayHeading._highlightTimer);
  focusNotesDisplayHeading._highlightTimer = window.setTimeout(() => {
    headingEl.classList.remove('notes-preview-active-heading');
    if (activeNotesDisplayPreviewHeadingEl === headingEl) {
      activeNotesDisplayPreviewHeadingEl = null;
    }
  }, 1400);
  return true;
}

function createNotesDisplaySourceMeasureContext(sourceEl, computed) {
  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d');
  if (!ctx) return null;
  const fontStyle = computed.fontStyle || 'normal';
  const fontVariant = computed.fontVariant || 'normal';
  const fontWeight = computed.fontWeight || '400';
  const fontSize = computed.fontSize || '16px';
  const fontFamily = computed.fontFamily || 'monospace';
  ctx.font = `${fontStyle} ${fontVariant} ${fontWeight} ${fontSize} / ${computed.lineHeight || 'normal'} ${fontFamily}`;
  return ctx;
}

function countNotesDisplayWrappedVisualLines(text, maxWidth, measureCtx) {
  if (!measureCtx || !Number.isFinite(maxWidth) || maxWidth <= 0) {
    return String(text || '').split('\n').length;
  }
  const lines = String(text || '').split('\n');
  let visualLines = 0;
  for (const line of lines) {
    if (!line) {
      visualLines += 1;
      continue;
    }
    let rowWidth = 0;
    let rowCount = 1;
    for (const char of line) {
      const width = measureCtx.measureText(char).width || 0;
      if (rowWidth > 0 && (rowWidth + width) > maxWidth) {
        rowCount += 1;
        rowWidth = width;
      } else {
        rowWidth += width;
      }
    }
    visualLines += rowCount;
  }
  return visualLines;
}

function getNotesDisplaySourceHeadingScrollTop(sourceEl, heading) {
  if (!sourceEl || !heading) return 0;
  const computed = window.getComputedStyle(sourceEl);
  const rawLineHeight = Number.parseFloat(computed.lineHeight || '');
  const fontSize = Number.parseFloat(computed.fontSize || '16');
  const lineHeight = Number.isFinite(rawLineHeight) ? rawLineHeight : fontSize * 1.7;
  const paddingTop = Number.parseFloat(computed.paddingTop || '0') || 0;
  const paddingLeft = Number.parseFloat(computed.paddingLeft || '0') || 0;
  const paddingRight = Number.parseFloat(computed.paddingRight || '0') || 0;
  const innerWidth = Math.max(sourceEl.clientWidth - paddingLeft - paddingRight, 1);
  const beforeText = String(sourceEl.value || '').slice(0, Math.max(Number(heading.startIndex || 0), 0));
  const measureCtx = createNotesDisplaySourceMeasureContext(sourceEl, computed);
  const visualLinesBefore = Math.max(countNotesDisplayWrappedVisualLines(beforeText, innerWidth, measureCtx) - 1, 0);
  return Math.max((visualLinesBefore * lineHeight) - paddingTop - 12, 0);
}

function scrollNotesDisplaySourceToHeading(heading) {
  const sourceEl = byId('notesDisplayContent');
  if (!sourceEl || !heading) return false;
  const cursor = Math.max(Number(heading.startIndex || 0), 0);
  const scrollTop = getNotesDisplaySourceHeadingScrollTop(sourceEl, heading);
  sourceEl.selectionStart = cursor;
  sourceEl.selectionEnd = cursor;
  sourceEl.scrollTop = scrollTop;
  window.requestAnimationFrame(() => {
    sourceEl.scrollTop = scrollTop;
  });
  return true;
}

function focusNotesDisplayHeading(headingId) {
  const target = notesDisplayStructureCache.find((item) => item.id === headingId);
  if (!target) return;
  activeNotesDisplayHeadingId = target.id;
  syncActiveNotesDisplayHeading();
  if (notesDisplayContentView === 'markdown') {
    scrollNotesDisplaySourceToHeading(target);
    return;
  }
  if (scrollNotesDisplayPreviewToHeading(target.id)) return;
  renderNotesDisplayPreview();
  scrollNotesDisplayPreviewToHeading(target.id);
}

function collectMarkdownFromPreviewNode(node, lines) {
  if (!node) return;
  const tag = (node.nodeName || '').toUpperCase();

  if (tag === '#TEXT') {
    const text = String(node.textContent || '').replace(/\u00A0/g, ' ').trim();
    if (text) lines.push(text);
    return;
  }

  if (/^H[1-6]$/.test(tag)) {
    const level = Number(tag.slice(1));
    const text = (node.innerText || node.textContent || '').replace(/\u00A0/g, ' ').trim();
    if (text) {
      lines.push(`${'#'.repeat(level)} ${text}`);
      lines.push('');
    }
    return;
  }

  if (tag === 'P') {
    const text = (node.innerText || node.textContent || '').replace(/\u00A0/g, ' ').trim();
    if (text) {
      lines.push(text);
      lines.push('');
    }
    return;
  }

  if (tag === 'UL' || tag === 'OL') {
    const items = Array.from(node.children || []).filter((child) => child.nodeName.toUpperCase() === 'LI');
    items.forEach((item, index) => {
      const text = (item.innerText || item.textContent || '').replace(/\u00A0/g, ' ').trim();
      if (!text) return;
      lines.push(`${tag === 'OL' ? `${index + 1}. ` : '- '}${text}`);
    });
    if (items.length) lines.push('');
    return;
  }

  if (tag === 'PRE') {
    const code = (node.innerText || node.textContent || '').replace(/\r\n/g, '\n').replace(/\r/g, '\n').trimEnd();
    lines.push('```');
    if (code) lines.push(code);
    lines.push('```');
    lines.push('');
    return;
  }

  if (tag === 'DIV' || tag === 'SECTION' || tag === 'ARTICLE') {
    Array.from(node.childNodes || []).forEach((child) => collectMarkdownFromPreviewNode(child, lines));
    return;
  }

  const text = (node.innerText || node.textContent || '').replace(/\u00A0/g, ' ').trim();
  if (text) {
    lines.push(text);
    lines.push('');
  }
}

function serializePreviewBodyToMarkdown(bodyEl) {
  const lines = [];
  Array.from(bodyEl.childNodes || []).forEach((node) => collectMarkdownFromPreviewNode(node, lines));
  while (lines.length && !String(lines[lines.length - 1]).trim()) {
    lines.pop();
  }
  return lines.join('\n');
}

function renderNotesDisplayStructure(toc = []) {
  const host = byId('notesDisplayOutlineList');
  if (!host) return;
  notesDisplayStructureCache = Array.isArray(toc) ? toc : [];
  if (activeNotesDisplayHeadingId && !notesDisplayStructureCache.some((item) => item.id === activeNotesDisplayHeadingId)) {
    activeNotesDisplayHeadingId = '';
  }
  if (!notesDisplayStructureCache.length) {
    host.innerHTML = '<div class="notes-outline-empty">把一大段 Markdown 贴进右侧后，这里会自动列出目录结构。</div>';
    return;
  }
  host.innerHTML = notesDisplayStructureCache
    .map((item) => `
      <button class="notes-outline-item level-${Math.min(item.level, 6)} ${item.id === activeNotesDisplayHeadingId ? 'active' : ''}" type="button" data-outline-id="${escapeHtml(item.id)}">
        <span class="outline-indent depth-${Math.min(Math.max(item.level - 1, 0), 5)}" aria-hidden="true"></span>
        <span class="outline-text">${escapeHtml(item.text)}</span>
        <span class="level-label">H${item.level}</span>
      </button>
    `)
    .join('');
}

function syncNotesDisplayPreviewEdit() {
  const bodyEl = byId('notesDisplayPreviewBody');
  const contentEl = byId('notesDisplayContent');
  if (!bodyEl || !contentEl) return;
  contentEl.value = serializePreviewBodyToMarkdown(bodyEl);
  state.notesDisplay.dirty = true;
  setDirty(true, 'notes_display');
  scheduleNotesDisplayAutosave();
}

function clearNotesDisplayAutosaveTimer() {
  if (!notesDisplayAutosaveTimer) return;
  window.clearTimeout(notesDisplayAutosaveTimer);
  notesDisplayAutosaveTimer = 0;
}

function renderNotesDisplayPreview() {
  const bodyEl = byId('notesDisplayPreviewBody');
  const content = byId('notesDisplayContent')?.value || '';
  if (!bodyEl) return;
  if (notesDisplayPreviewEditing) return;

  const parsed = buildMarkdownPreview(content);
  renderNotesDisplayStructure(parsed.toc);

  if (!parsed.html.trim()) {
    bodyEl.innerHTML = '<div class="notes-preview-empty">当前没有可预览的正文内容。</div>';
  } else {
    bodyEl.innerHTML = parsed.html;
  }

  bodyEl.setAttribute('contenteditable', 'true');
  bodyEl.setAttribute('spellcheck', 'false');
  syncNotesDisplayContentMode();
}

async function loadNotesDisplayContent(id) {
  const payload = await api(`/api/notes-display/get?id=${encodeURIComponent(id)}`);
  if (!payload.ok) throw new Error(payload.error || 'load notes display note failed');
  const note = payload.note || { id, title: '', content: '' };

  notesDisplayLoading = true;
  clearNotesDisplayAutosaveTimer();
  state.notesDisplay.currentId = note.id;
  byId('notesDisplayContent').value = note.content || '';
  state.notesDisplay.dirty = false;
  setDirty(false, 'notes_display');
  renderNotesDisplayList();
  renderNotesDisplayHotkeyExplain();
  renderNotesDisplayPreview();
  notesDisplayLoading = false;
}

export async function loadNotesDisplayNotes() {
  const payload = await api('/api/notes-display/list');
  if (!payload.ok) throw new Error(payload.error || 'load notes display notes failed');
  state.notesDisplay.list = payload.notes || [];

  if (!state.notesDisplay.list.length) {
    await ensureNotesDisplayCurrentId();
    const retry = await api('/api/notes-display/list');
    if (!retry.ok) throw new Error(retry.error || 'reload notes display notes failed');
    state.notesDisplay.list = retry.notes || [];
  }

  if (!state.notesDisplay.currentId || !state.notesDisplay.list.find((n) => n.id === state.notesDisplay.currentId)) {
    state.notesDisplay.currentId = state.notesDisplay.list[0]?.id || '';
  }

  renderNotesDisplayList();
  renderNotesDisplayHotkeyExplain();
  if (state.notesDisplay.currentId) {
    await loadNotesDisplayContent(state.notesDisplay.currentId);
  } else {
    clearNotesDisplayAutosaveTimer();
    byId('notesDisplayContent').value = '';
    renderNotesDisplayPreview();
  }
}

export async function saveCurrentNotesDisplayNote(options = {}) {
  const id = await ensureNotesDisplayCurrentId();

  const content = byId('notesDisplayContent').value;
  const title = deriveNotesDisplayTitle(content);
  const payload = await api('/api/notes-display/save', {
    method: 'POST',
    body: JSON.stringify({ id, title, content })
  });
  if (!payload.ok) throw new Error(payload.error || 'save notes display note failed');

  state.notesDisplay.dirty = false;
  setDirty(false, 'notes_display');
  await loadNotesDisplayNotes();
  if (!options.silent) {
    toast('笔记显示内容已保存');
  }
}

export async function deleteCurrentNotesDisplayNote() {
  const id = state.notesDisplay.currentId;
  if (!id) return;
  if (!(await confirmDialog('确认删除当前内容吗？', { title: '删除内容', confirmText: '删除', danger: true }))) return;
  const payload = await api('/api/notes-display/delete', {
    method: 'POST',
    body: JSON.stringify({ id })
  });
  if (!payload.ok) throw new Error(payload.error || 'delete notes display note failed');
  clearNotesDisplayAutosaveTimer();
  state.notesDisplay.currentId = '';
  state.notesDisplay.dirty = false;
  setDirty(false, 'notes_display');
  await loadNotesDisplayNotes();
  toast('内容已删除');
}

function scheduleNotesDisplayAutosave() {
  if (notesDisplayLoading) return;
  clearNotesDisplayAutosaveTimer();
  notesDisplayAutosaveTimer = window.setTimeout(() => {
    notesDisplayAutosaveTimer = 0;
    saveCurrentNotesDisplayNote({ silent: true }).catch((e) => toast(`自动保存失败: ${e.message}`));
  }, NOTES_DISPLAY_AUTOSAVE_DELAY_MS);
}

export async function selectNotesDisplayNote(id) {
  if (state.notesDisplay.currentId === id) return;
  if (state.notesDisplay.dirty) {
    await saveCurrentNotesDisplayNote({ silent: true });
  }
  await loadNotesDisplayContent(id);
}

export function initNotesDisplayHandlers() {
  notesDisplaySidebarCompact = Number(state.app?.notes_display_sidebar_compact || 0) === 1;
  const contentEl = byId('notesDisplayContent');
  const previewBodyEl = byId('notesDisplayPreviewBody');
  const outlineEl = byId('notesDisplayOutlineList');

  byId('toggleNotesDisplaySidebarBtn').onclick = () => {
    notesDisplaySidebarCompact = !notesDisplaySidebarCompact;
    syncNotesDisplaySidebar();
    void persistNotesDisplaySidebarCompact().catch((e) => {
      toast(`列表状态保存失败: ${e.message}`);
    });
  };

  contentEl.oninput = () => {
    state.notesDisplay.dirty = true;
    setDirty(true, 'notes_display');
    renderNotesDisplayPreview();
    scheduleNotesDisplayAutosave();
  };

  contentEl.addEventListener('blur', () => {
    if (!state.notesDisplay.dirty) return;
    saveCurrentNotesDisplayNote({ silent: true }).catch((e) => toast(`自动保存失败: ${e.message}`));
  });

  previewBodyEl.addEventListener('focus', () => {
    notesDisplayPreviewEditing = true;
  });

  previewBodyEl.addEventListener('input', () => {
    syncNotesDisplayPreviewEdit();
  });

  previewBodyEl.addEventListener('blur', () => {
    notesDisplayPreviewEditing = false;
    syncNotesDisplayPreviewEdit();
    renderNotesDisplayPreview();
  });

  byId('notesDisplayViewMarkdownBtn').onclick = () => {
    setNotesDisplayContentView('markdown');
  };

  byId('notesDisplayViewRenderedBtn').onclick = () => {
    setNotesDisplayContentView('rendered');
  };

  byId('deleteNotesDisplayBtn').onclick = () => {
    deleteCurrentNotesDisplayNote().catch((e) => toast(`删除失败: ${e.message}`));
  };

  byId('copyNotesDisplayOutlineBtn').onclick = async () => {
    const headings = Array.isArray(notesDisplayStructureCache) ? notesDisplayStructureCache : [];
    if (!headings.length) {
      toast('当前没有可复制的目录');
      return;
    }
    const outlineText = headings.map((heading) => `${'  '.repeat(Math.max((heading.level || 1) - 1, 0))}${heading.text || ''}`).join('\n');
    try {
      await navigator.clipboard.writeText(outlineText);
      toast('目录已复制');
    } catch (error) {
      toast(`目录复制失败: ${error.message}`);
    }
  };

  outlineEl.addEventListener('click', (event) => {
    const button = event.target instanceof Element ? event.target.closest('.notes-outline-item') : null;
    if (!button) return;
    const headingId = button.getAttribute('data-outline-id') || '';
    if (!headingId) return;
    focusNotesDisplayHeading(headingId);
  });

  renderNotesDisplayHotkeyExplain();
  renderNotesDisplayPreview();
  syncNotesDisplayContentMode();
  syncNotesDisplaySidebar();
}
