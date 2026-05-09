import { state, byId, api, toast, setDirty, escapeHtml, confirmDialog } from './app-common.js';

const NOTES_AUTOSAVE_DELAY_MS = 700;
let notesAutosaveTimer = 0;
let notesSaveInFlight = false;
let notesSaveQueued = false;
let notesSavePromise = null;
let notesChangeVersion = 0;
let draggingNoteId = '';
let notesSidebarCompact = false;
let notesExtractCollapsed = false;
let extractSaveTimers = new Map();
let extractContextByNoteId = new Map();
let extractViewActive = false;
let extractViewItems = [];
let notesStructureCache = [];
let activeOutlineHeadingId = '';
let activePreviewHeadingEl = null;
let notesPreviewEditing = false;
let editingNoteTitleId = '';
let notesContentView = 'rendered';
const EXTRACT_SLOTS = [1, 2, 3];

async function createNewNote() {
  if (extractViewActive && state.notes.dirty) {
    await saveExtractAggregateView({ silent: true });
  } else if (state.notes.dirty) {
    await saveCurrentNote({ silent: true });
  }
  resetExtractViewState();
  const payload = await api('/api/notes/create', {
    method: 'POST',
    body: JSON.stringify({ title: 'New Note' })
  });
  if (!payload.ok) throw new Error(payload.error || 'new note failed');
  state.notes.currentId = payload.id;
  await loadNotes();
  toast('已新建笔记');
}

function resetExtractViewState() {
  for (const timer of extractSaveTimers.values()) {
    window.clearTimeout(timer);
  }
  extractSaveTimers.clear();
  extractContextByNoteId = new Map();
  extractViewItems = [];
  extractViewActive = false;
}

function syncNotesSidebar() {
  const layout = byId('notesLayoutRoot');
  const toggleBtn = byId('toggleNotesSidebarBtn');
  if (!layout || !toggleBtn) return;
  layout.classList.toggle('sidebar-compact', notesSidebarCompact);
  toggleBtn.textContent = notesSidebarCompact ? '展开列表' : '收起列表';
  toggleBtn.setAttribute('aria-expanded', notesSidebarCompact ? 'false' : 'true');
}

function syncNotesExtractTool() {
  const tool = byId('notesExtractTool');
  const btn = byId('toggleNotesExtractBtn');
  if (!tool || !btn) return;
  tool.classList.toggle('collapsed', notesExtractCollapsed);
  btn.textContent = notesExtractCollapsed ? '显示提取' : '隐藏提取';
  btn.setAttribute('aria-expanded', notesExtractCollapsed ? 'false' : 'true');
}

function syncNotesContentMode() {
  const markdownBtn = byId('notesViewMarkdownBtn');
  const renderedBtn = byId('notesViewRenderedBtn');
  const sourceEl = byId('noteContent');
  const previewEl = byId('notePreviewBody');
  const showingMarkdown = notesContentView === 'markdown';

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

function setNotesContentView(mode) {
  notesContentView = mode === 'markdown' ? 'markdown' : 'rendered';
  syncNotesContentMode();
}

function syncActiveOutlineHeading() {
  const host = byId('notesOutlineList');
  if (!host) return;
  host.querySelectorAll('.notes-outline-item.active').forEach((node) => {
    if (node.getAttribute('data-outline-id') !== activeOutlineHeadingId) {
      node.classList.remove('active');
    }
  });
  if (!activeOutlineHeadingId) return;
  const activeNode = host.querySelector(`.notes-outline-item[data-outline-id="${activeOutlineHeadingId}"]`);
  if (activeNode) {
    activeNode.classList.add('active');
  }
}

function scrollPreviewToHeading(headingId) {
  const previewEl = byId('notePreviewBody');
  const headingEl = previewEl?.querySelector(`[data-heading-id="${headingId}"]`);
  if (!previewEl || !headingEl) return false;

  const previewRect = previewEl.getBoundingClientRect();
  const headingRect = headingEl.getBoundingClientRect();
  const relativeTop = headingRect.top - previewRect.top + previewEl.scrollTop;
  const nextTop = Math.max(relativeTop - 12, 0);

  previewEl.scrollTop = nextTop;
  if (activePreviewHeadingEl && activePreviewHeadingEl !== headingEl) {
    activePreviewHeadingEl.classList.remove('notes-preview-active-heading');
  }
  headingEl.classList.add('notes-preview-active-heading');
  activePreviewHeadingEl = headingEl;
  window.clearTimeout(focusOutlineHeading._highlightTimer);
  focusOutlineHeading._highlightTimer = window.setTimeout(() => {
    headingEl.classList.remove('notes-preview-active-heading');
    if (activePreviewHeadingEl === headingEl) {
      activePreviewHeadingEl = null;
    }
  }, 1400);
  return true;
}

function createSourceMeasureContext(sourceEl, computed) {
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

function countWrappedVisualLines(text, maxWidth, measureCtx) {
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

function getSourceHeadingScrollTop(sourceEl, heading) {
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
  const measureCtx = createSourceMeasureContext(sourceEl, computed);
  const visualLinesBefore = Math.max(countWrappedVisualLines(beforeText, innerWidth, measureCtx) - 1, 0);

  return Math.max((visualLinesBefore * lineHeight) - paddingTop - 12, 0);
}

function scrollSourceToHeading(heading) {
  const sourceEl = byId('noteContent');
  if (!sourceEl || !heading) return false;

  const cursor = Math.max(Number(heading.startIndex || 0), 0);
  const scrollTop = getSourceHeadingScrollTop(sourceEl, heading);
  sourceEl.selectionStart = cursor;
  sourceEl.selectionEnd = cursor;
  sourceEl.scrollTop = scrollTop;
  window.requestAnimationFrame(() => {
    sourceEl.scrollTop = scrollTop;
  });
  return true;
}

async function persistNotesSidebarCompact() {
  const value = notesSidebarCompact ? 1 : 0;
  state.app.notes_sidebar_compact = value;
  await api('/api/app/notes-sidebar', {
    method: 'POST',
    body: JSON.stringify({ notes_sidebar_compact: value })
  });
}

async function persistNotesExtractCollapsed() {
  const value = notesExtractCollapsed ? 1 : 0;
  state.app.notes_extract_collapsed = value;
  await api('/api/app/notes-extract-collapsed', {
    method: 'POST',
    body: JSON.stringify({ notes_extract_collapsed: value })
  });
}

function escapeOutlineText(value) {
  return escapeHtml(String(value || '').trim());
}

function stripAsteriskMarker(value) {
  return String(value || '')
    .trim()
    .replace(/^\*{2,}/, '')
    .replace(/\*{2,}$/, '')
    .trim();
}

function normalizeExtractMarker(value) {
  const inner = stripAsteriskMarker(value);
  if (!inner) return '';
  return `**${inner}**`;
}

function syncExtractMarkerInput(inputId) {
  const input = byId(inputId);
  if (!input) return;
  input.value = stripAsteriskMarker(input.value);
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
  const normalized = String(content || '').replace(/\r\n/g, '\n');
  const lines = normalized.split('\n');
  const headings = [];
  let cursor = 0;
  let headingIndex = 0;

  lines.forEach((line, index) => {
    const match = /^(#{1,6})\s+(.+?)\s*$/.exec(line);
    if (match) {
      const level = match[1].length;
      const text = match[2].trim();
      headingIndex += 1;
      headings.push({
        id: slugifyHeading(text, headingIndex),
        text,
        level,
        lineIndex: index,
        startIndex: cursor
      });
    }
    cursor += line.length + 1;
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

function extractAllRanges(content, startMarker, endMarker) {
  const source = String(content || '');
  const start = normalizeExtractMarker(startMarker);
  const end = normalizeExtractMarker(endMarker);
  if (!start) return [];

  const structure = parseNoteStructure(source);
  const headings = Array.isArray(structure?.headings) ? structure.headings : [];

  const ranges = [];
  let searchFrom = 0;

  while (searchFrom < source.length) {
    const startIndex = source.indexOf(start, searchFrom);
    if (startIndex < 0) break;

    const bodyStart = startIndex + start.length;
    let bodyEnd = source.length;

    if (end) {
      const nextIndex = source.indexOf(end, bodyStart);
      if (nextIndex >= 0) {
        bodyEnd = nextIndex;
      }
    }

    let headingTitle = '';
    for (let i = headings.length - 1; i >= 0; i -= 1) {
      if (headings[i].startIndex < bodyStart) {
        headingTitle = headings[i].text || '';
        break;
      }
    }

    ranges.push({
      bodyStart,
      bodyEnd,
      text: source.slice(bodyStart, bodyEnd),
      headingTitle
    });

    searchFrom = Math.max(bodyEnd, bodyStart + 1);
  }

  return ranges;
}

async function fetchNoteForExtraction(note) {
  if (String(note.id || '') === String(state.notes.currentId || '')) {
    return {
      id: String(note.id || ''),
      title: getCurrentNoteTitle(),
      content: byId('noteContent')?.value || ''
    };
  }
  const payload = await api(`/api/notes/get?id=${encodeURIComponent(note.id)}`);
  if (!payload.ok) throw new Error(payload.error || 'load note failed');
  return payload.note || { id: String(note.id || ''), title: note.title || 'Untitled', content: '' };
}

function buildExtractViewContent(items) {
  return items
    .map((item) => {
      const blocks = (item.ranges || [])
        .map((range, index) => `### ${getExtractSegmentTitle(range.headingTitle, index)}\n${String(range.text || '').trim()}`)
        .join('\n\n');
      return `## 笔记：${item.title || 'Untitled'}\n${blocks}`;
    })
    .join('\n\n');
}

function getExtractSegmentTitle(title, index = 0) {
  return String(title || '').trim() || `片段 ${index + 1}`;
}

function setExtractStatus(message) {
  const host = byId('notesExtractStatus');
  if (host) {
    host.textContent = message;
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

function buildMarkdownPreview(markdown) {
  const lines = String(markdown || '').replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
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
      html.push(`<h${level} data-heading-id="${id}" id="${id}">${renderInlineMarkdown(text)}</h${level}>`);
      continue;
    }

    const standaloneStrongMatch = trimmed.match(/^(\*\*[^*]+\*\*|__[^_]+__)$/);
    if (standaloneStrongMatch) {
      flushParagraph();
      flushList();
      html.push(`<p class="notes-preview-label">${renderInlineMarkdown(trimmed)}</p>`);
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
  return html.join('');
}

function collectInlineMarkdown(node) {
  if (!node) return '';
  const tag = (node.nodeName || '').toUpperCase();

  if (tag === '#TEXT') {
    return String(node.textContent || '').replace(/\u00A0/g, ' ');
  }
  if (tag === 'BR') {
    return '\n';
  }
  if (tag === 'STRONG' || tag === 'B') {
    const inner = Array.from(node.childNodes || []).map((child) => collectInlineMarkdown(child)).join('');
    return inner ? `**${inner}**` : '';
  }
  if (tag === 'EM' || tag === 'I') {
    const inner = Array.from(node.childNodes || []).map((child) => collectInlineMarkdown(child)).join('');
    return inner ? `*${inner}*` : '';
  }
  if (tag === 'CODE') {
    const inner = Array.from(node.childNodes || []).map((child) => collectInlineMarkdown(child)).join('');
    return inner ? `\`${inner}\`` : '';
  }

  return Array.from(node.childNodes || []).map((child) => collectInlineMarkdown(child)).join('');
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
    const text = collectInlineMarkdown(node).trim();
    if (text) {
      lines.push(`${'#'.repeat(level)} ${text}`);
      lines.push('');
    }
    return;
  }

  if (tag === 'P') {
    const text = collectInlineMarkdown(node).replace(/\n{3,}/g, '\n\n').trim();
    if (text) {
      lines.push(text);
      lines.push('');
    }
    return;
  }

  if (tag === 'UL' || tag === 'OL') {
    const items = Array.from(node.children || []).filter((child) => child.nodeName.toUpperCase() === 'LI');
    items.forEach((item, index) => {
      const text = collectInlineMarkdown(item).replace(/\n+/g, ' ').trim();
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

  const text = collectInlineMarkdown(node).replace(/\n{3,}/g, '\n\n').trim();
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

function renderNoteContentSurface() {
  const previewEl = byId('notePreviewBody');
  const sourceEl = byId('noteContent');
  if (!previewEl || !sourceEl) return;
  if (notesPreviewEditing) return;
  const html = buildMarkdownPreview(sourceEl.value || '');
  previewEl.innerHTML = html.trim() ? html : '<div class="notes-preview-empty">当前还没有正文内容。可以先输入或导入 Markdown，系统会转成正常笔记正文显示。</div>';
  syncNotesContentMode();
}

function syncPreviewEditToSource() {
  const previewEl = byId('notePreviewBody');
  const sourceEl = byId('noteContent');
  if (!previewEl || !sourceEl) return;
  sourceEl.value = serializePreviewBodyToMarkdown(previewEl);
  notesChangeVersion += 1;
  state.notes.dirty = true;
  setDirty(true, 'notes');
  renderNoteStructure();
  if (extractViewActive) {
    queueExtractAggregateSave();
  } else {
    scheduleNotesAutosave();
  }
}

async function saveExtractResult(noteId, nextText) {
  const context = extractContextByNoteId.get(noteId);
  if (!context) return;
  const segments = parseExtractSegments(nextText, context.segmentTitles || []);
  if (segments.length !== context.ranges.length) {
    throw new Error(`笔记“${context.title}”的提取片段数量已变化，当前为 ${context.ranges.length} 段，请不要删除片段标题`);
  }

  let updatedContent = context.fullContent;
  for (let i = context.ranges.length - 1; i >= 0; i -= 1) {
    const range = context.ranges[i];
    updatedContent = updatedContent.slice(0, range.bodyStart) + segments[i] + updatedContent.slice(range.bodyEnd);
  }

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
  const refreshedRanges = extractAllRanges(updatedContent, context.startMarker, context.endMarker);
  context.ranges = refreshedRanges.map((range) => ({
    bodyStart: range.bodyStart,
    bodyEnd: range.bodyEnd
  }));

  if (!extractViewActive && String(context.id) === String(state.notes.currentId || '')) {
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

function parseExtractViewContent(raw) {
  const text = String(raw || '').replace(/\r\n/g, '\n');
  const regex = /^## 笔记：.*$/gm;
  const matches = Array.from(text.matchAll(regex));
  if (!matches.length) return [];

  const sections = [];
  for (let i = 0; i < matches.length; i += 1) {
    const start = matches[i].index;
    const bodyStart = start + matches[i][0].length;
    const end = i + 1 < matches.length ? matches[i + 1].index : text.length;
    sections.push(text.slice(bodyStart, end).replace(/^\n+/, '').replace(/\n+$/, ''));
  }
  return sections;
}

function parseExtractSegments(raw, expectedTitles = []) {
  const normalizedTitles = Array.isArray(expectedTitles)
    ? expectedTitles.map((title, index) => getExtractSegmentTitle(title, index))
    : [];
  if (!normalizedTitles.length) {
    return parseExtractSegmentsLegacy(raw);
  }

  const text = String(raw || '').replace(/\r\n/g, '\n');
  const headingLines = normalizedTitles.map((title) => `### ${title}`);
  const firstIndex = text.indexOf(headingLines[0]);
  if (firstIndex < 0) {
    return parseExtractSegmentsLegacy(text);
  }

  const sections = [];
  let searchFrom = firstIndex;
  for (let i = 0; i < headingLines.length; i += 1) {
    const heading = headingLines[i];
    const start = text.indexOf(heading, searchFrom);
    if (start < 0) {
      return parseExtractSegmentsLegacy(text);
    }
    const bodyStart = start + heading.length;
    const nextHeading = i + 1 < headingLines.length ? headingLines[i + 1] : '';
    const bodyEnd = nextHeading ? text.indexOf(nextHeading, bodyStart) : text.length;
    sections.push(text.slice(bodyStart, bodyEnd >= 0 ? bodyEnd : text.length).replace(/^\n+/, '').replace(/\n+$/, ''));
    searchFrom = bodyEnd >= 0 ? bodyEnd : text.length;
  }
  return sections;
}

function parseExtractSegmentsLegacy(raw) {
  const text = String(raw || '').replace(/\r\n/g, '\n');
  const regex = /^### .+$/gm;
  const matches = Array.from(text.matchAll(regex));
  if (!matches.length) {
    return [text.trim()];
  }

  const sections = [];
  for (let i = 0; i < matches.length; i += 1) {
    const start = matches[i].index;
    const bodyStart = start + matches[i][0].length;
    const end = i + 1 < matches.length ? matches[i + 1].index : text.length;
    sections.push(text.slice(bodyStart, end).replace(/^\n+/, '').replace(/\n+$/, ''));
  }
  return sections;
}

async function saveExtractAggregateView(options = {}) {
  const silent = !!options.silent;
  if (!extractViewActive) return;
  const sections = parseExtractViewContent(byId('noteContent')?.value || '');
  if (sections.length !== extractViewItems.length) {
    throw new Error('提取视图分段已被改坏，请不要删除“## 笔记：...”分隔标题');
  }

  for (let i = 0; i < extractViewItems.length; i += 1) {
    await saveExtractResult(extractViewItems[i].id, sections[i]);
  }

  state.notes.dirty = false;
  setDirty(false, 'notes');
  if (!silent) {
    toast('提取内容已回写');
  }
}

function queueExtractAggregateSave() {
  const key = '__extract_view__';
  if (extractSaveTimers.has(key)) {
    window.clearTimeout(extractSaveTimers.get(key));
  }
  const timer = window.setTimeout(() => {
    extractSaveTimers.delete(key);
    saveExtractAggregateView({ silent: true }).catch((error) => {
      toast(`提取内容保存失败: ${error.message}`);
    });
  }, 500);
  extractSaveTimers.set(key, timer);
}

async function exitExtractView(options = {}) {
  const allowDiscardOnFailure = options.allowDiscardOnFailure !== false;
  if (extractViewActive && state.notes.dirty) {
    try {
      await saveExtractAggregateView({ silent: true });
    } catch (error) {
      if (!allowDiscardOnFailure) {
        throw error;
      }
      toast(`提取内容保存失败，已直接恢复正文: ${error.message}`);
      state.notes.dirty = false;
      setDirty(false, 'notes');
    }
  }
  resetExtractViewState();
  if (state.notes.currentId) {
    await loadNoteContent(state.notes.currentId);
  } else {
    byId('noteContent').value = '';
    renderNoteStructure();
  }
  setExtractStatus('已恢复当前笔记正文视图。');
}

async function runNotesExtraction(slot = 1) {
  const startMarker = normalizeExtractMarker(byId(`notesExtractStart${slot}`)?.value || '');
  const endMarker = normalizeExtractMarker(byId(`notesExtractEnd${slot}`)?.value || '');
  if (!startMarker) {
    toast('请先填写提取起点');
    return;
  }

  if (extractViewActive && state.notes.dirty) {
    await saveExtractAggregateView({ silent: true });
  } else if (state.notes.dirty) {
    await saveCurrentNote({ silent: true });
  }

  setExtractStatus('正在提取各笔记内容...');
  resetExtractViewState();
  const notes = Array.isArray(state.notes.list) ? state.notes.list : [];
  const items = [];

  for (const note of notes) {
    const fullNote = await fetchNoteForExtraction(note);
    const extractedRanges = extractAllRanges(fullNote.content || '', startMarker, endMarker);
    if (!extractedRanges.length) continue;

    extractContextByNoteId.set(String(fullNote.id), {
      id: String(fullNote.id),
      title: fullNote.title || note.title || 'Untitled',
      fullContent: String(fullNote.content || ''),
      startMarker,
      endMarker,
      segmentTitles: extractedRanges.map((range, index) => getExtractSegmentTitle(range.headingTitle, index)),
      ranges: extractedRanges.map((range) => ({
        bodyStart: range.bodyStart,
        bodyEnd: range.bodyEnd
      }))
    });

    items.push({
      id: String(fullNote.id),
      title: fullNote.title || note.title || 'Untitled',
      ranges: extractedRanges.map((range) => ({
        text: range.text,
        headingTitle: range.headingTitle || ''
      })),
      rangeLabel: endMarker ? `${startMarker} -> ${endMarker}` : `${startMarker} -> 文末`
    });
  }

  if (!items.length) {
    renderNoteStructure();
    state.notes.dirty = false;
    setDirty(false, 'notes');
    setExtractStatus('当前范围在现有笔记中没有命中结果，主内容框保持当前正文。');
    return;
  }

  extractViewItems = items;
  extractViewActive = true;
  byId('noteContent').value = buildExtractViewContent(items);
  renderNoteStructure();
  state.notes.dirty = false;
  setDirty(false, 'notes');
  const totalSegments = items.reduce((sum, item) => sum + (item.ranges?.length || 0), 0);
  setExtractStatus(`已提取 ${items.length} 条笔记、共 ${totalSegments} 个片段，现已进入主内容框集中编辑。`);
}

function renderOutlineList(structure) {
  const host = byId('notesOutlineList');
  if (!host) return;
  const headings = Array.isArray(structure?.headings) ? structure.headings : [];
  notesStructureCache = headings;
  if (activeOutlineHeadingId && !headings.some((heading) => heading.id === activeOutlineHeadingId)) {
    activeOutlineHeadingId = '';
  }
  if (!headings.length) {
    host.innerHTML = '<div class="notes-outline-empty">把一大段 Markdown 贴进右侧后，这里会自动列出目录结构。</div>';
    return;
  }

  host.innerHTML = headings
    .map((heading) => `
      <button class="notes-outline-item level-${Math.min(heading.level, 6)} ${heading.id === activeOutlineHeadingId ? 'active' : ''}" type="button" data-outline-id="${escapeOutlineText(heading.id)}">
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
  renderNoteContentSurface();
}

function getCurrentNoteTitle() {
  const hiddenTitle = String(byId('noteTitle')?.value || '').trim();
  if (hiddenTitle) return hiddenTitle;
  const currentId = String(state.notes.currentId || '').trim();
  const current = (state.notes.list || []).find((note) => String(note.id || '').trim() === currentId);
  return String(current?.title || '').trim() || 'Untitled';
}

function setCurrentNoteTitle(title) {
  const nextTitle = String(title || '').trim() || 'Untitled';
  const hidden = byId('noteTitle');
  if (hidden) hidden.value = nextTitle;
  updateCurrentNoteMeta(nextTitle);
}

async function renameNoteTitle(noteId, rawTitle) {
  const id = String(noteId || '').trim();
  if (!id) return;
  const title = String(rawTitle || '').trim() || 'Untitled';

  if (id === String(state.notes.currentId || '').trim()) {
    setCurrentNoteTitle(title);
    notesChangeVersion += 1;
    state.notes.dirty = true;
    setDirty(true, 'notes');
    await saveCurrentNote({ silent: true });
    return;
  }

  const payload = await api(`/api/notes/get?id=${encodeURIComponent(id)}`);
  if (!payload.ok) throw new Error(payload.error || 'load note failed');
  const note = payload.note || { id, title, content: '' };
  const savePayload = await api('/api/notes/save', {
    method: 'POST',
    body: JSON.stringify({
      id,
      title,
      content: note.content || ''
    })
  });
  if (!savePayload.ok) throw new Error(savePayload.error || 'rename note failed');

  const existing = (state.notes.list || []).find((item) => String(item.id || '').trim() === id);
  if (existing) existing.title = title;
  renderNotesList();
}

function focusOutlineHeading(headingId) {
  const target = notesStructureCache.find((item) => item.id === headingId);
  if (!target) return;
  activeOutlineHeadingId = target.id;
  syncActiveOutlineHeading();
  if (notesContentView === 'markdown') {
    scrollSourceToHeading(target);
    return;
  }
  if (scrollPreviewToHeading(target.id)) return;
  renderNoteContentSurface();
  scrollPreviewToHeading(target.id);
}

function renderNotesList() {
  const listEl = byId('notesList');
  listEl.innerHTML = '';

  for (const note of state.notes.list) {
    const item = document.createElement('div');
    item.className = `note-item ${note.id === state.notes.currentId ? 'active' : ''}`;
    item.draggable = true;
    item.dataset.id = note.id;
    if (editingNoteTitleId === note.id) {
      item.innerHTML = `<input class="note-item-title-edit" type="text" value="${escapeHtml(note.title || 'Untitled')}" />`;
    } else {
      item.innerHTML = `<div class="note-item-title">${escapeHtml(note.title || 'Untitled')}</div>`;
    }
    item.onclick = () => selectNote(note.id).catch((e) => toast(`切换失败: ${e.message}`));
    item.ondblclick = (event) => {
      event.preventDefault();
      event.stopPropagation();
      editingNoteTitleId = note.id;
      renderNotesList();
      const input = listEl.querySelector(`.note-item[data-id="${note.id}"] .note-item-title-edit`);
      if (input) {
        input.focus();
        input.select();
      }
    };
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

    if (editingNoteTitleId === note.id) {
      const input = item.querySelector('.note-item-title-edit');
      const finish = async (commit) => {
        const nextValue = commit ? input.value : (note.title || 'Untitled');
        editingNoteTitleId = '';
        try {
          if (commit) {
            await renameNoteTitle(note.id, nextValue);
            toast('笔记标题已更新');
          } else {
            renderNotesList();
          }
        } catch (error) {
          toast(`标题修改失败: ${error.message}`);
          renderNotesList();
        }
      };
      input.addEventListener('click', (event) => event.stopPropagation());
      input.addEventListener('dblclick', (event) => event.stopPropagation());
      input.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') {
          event.preventDefault();
          void finish(true);
        }
        if (event.key === 'Escape') {
          event.preventDefault();
          void finish(false);
        }
      });
      input.addEventListener('blur', () => {
        void finish(true);
      });
    }
    listEl.appendChild(item);
  }

  const createWrap = document.createElement('div');
  createWrap.className = 'notes-list-create-wrap';
  createWrap.innerHTML = '<button id="newNoteBtnInline" class="notes-create-btn" type="button" aria-label="新建笔记">+</button>';
  listEl.appendChild(createWrap);

  const inlineCreateBtn = createWrap.querySelector('#newNoteBtnInline');
  if (inlineCreateBtn) {
    inlineCreateBtn.onclick = () => {
      createNewNote().catch((error) => {
        toast(`新建失败: ${error.message}`);
      });
    };
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
  setCurrentNoteTitle(note.title || '');
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
    setCurrentNoteTitle('');
    byId('noteContent').value = '';
    renderNoteStructure();
  }
}

export function applyNotesDraftState(draft = {}) {
  const id = String(draft?.id || '').trim();
  const title = String(draft?.title || '').trim();
  const content = String(draft?.content || '');

  if (id) {
    state.notes.currentId = id;
  }
  setCurrentNoteTitle(title || getCurrentNoteTitle());
  byId('noteContent').value = content;
  notesChangeVersion += 1;
  state.notes.dirty = true;
  setDirty(true, 'notes');
  renderNotesList();
  renderNoteStructure();
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
  const title = getCurrentNoteTitle();
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
  } catch (error) {
    state.notes.dirty = true;
    setDirty(true, 'notes');
    notesSaveQueued = false;
    scheduleNotesAutosave();
    throw error;
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
  if (extractViewActive && state.notes.dirty) {
    await saveExtractAggregateView({ silent: true });
  } else if (state.notes.dirty) {
    await saveCurrentNote({ silent: true });
  }
  resetExtractViewState();
  await loadNoteContent(id);
}

export function initNotesHandlers() {
  notesSidebarCompact = Number(state.app?.notes_sidebar_compact || 0) === 1;
  notesExtractCollapsed = Number(state.app?.notes_extract_collapsed || 0) === 1;
  EXTRACT_SLOTS.forEach((slot) => {
    syncExtractMarkerInput(`notesExtractStart${slot}`);
    syncExtractMarkerInput(`notesExtractEnd${slot}`);
  });

  byId('toggleNotesSidebarBtn').onclick = () => {
    notesSidebarCompact = !notesSidebarCompact;
    syncNotesSidebar();
    void persistNotesSidebarCompact().catch((error) => {
      toast(`列表状态保存失败: ${error.message}`);
    });
  };
  byId('toggleNotesExtractBtn').onclick = () => {
    notesExtractCollapsed = !notesExtractCollapsed;
    syncNotesExtractTool();
    void persistNotesExtractCollapsed().catch((error) => {
      toast(`提取栏状态保存失败: ${error.message}`);
    });
  };

  const previewEl = byId('notePreviewBody');
  const sourceEl = byId('noteContent');
  previewEl.addEventListener('focus', () => {
    notesPreviewEditing = true;
  });
  previewEl.addEventListener('input', () => {
    syncPreviewEditToSource();
  });
  previewEl.addEventListener('blur', () => {
    notesPreviewEditing = false;
    syncPreviewEditToSource();
    renderNoteContentSurface();
  });
  sourceEl.addEventListener('input', () => {
    notesChangeVersion += 1;
    state.notes.dirty = true;
    setDirty(true, 'notes');
    renderNoteStructure();
    if (extractViewActive) {
      queueExtractAggregateSave();
    } else {
      scheduleNotesAutosave();
    }
  });

  byId('notesViewMarkdownBtn').onclick = () => {
    setNotesContentView('markdown');
  };
  byId('notesViewRenderedBtn').onclick = () => {
    setNotesContentView('rendered');
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

  byId('notesOutlineList').addEventListener('click', (event) => {
    const button = event.target instanceof Element ? event.target.closest('.notes-outline-item') : null;
    if (!button) return;
    const headingId = button.getAttribute('data-outline-id') || '';
    if (!headingId) return;
    focusOutlineHeading(headingId);
  });

  EXTRACT_SLOTS.forEach((slot) => {
    byId(`notesExtractStart${slot}`).addEventListener('blur', () => {
      syncExtractMarkerInput(`notesExtractStart${slot}`);
    });
    byId(`notesExtractEnd${slot}`).addEventListener('blur', () => {
      syncExtractMarkerInput(`notesExtractEnd${slot}`);
    });
    byId(`runNotesExtractBtn${slot}`).onclick = () => {
      runNotesExtraction(slot).catch((error) => {
        toast(`提取失败: ${error.message}`);
        setExtractStatus('提取失败，请检查范围后重试。');
      });
    };
  });
  byId('exitNotesExtractBtn').onclick = () => {
    exitExtractView({ allowDiscardOnFailure: true }).catch((error) => {
      toast(`恢复正文失败: ${error.message}`);
    });
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
    resetExtractViewState();
    await loadNotes();
    toast('笔记已删除');
  };

  syncNotesSidebar();
  syncNotesContentMode();
  syncNotesExtractTool();
}

