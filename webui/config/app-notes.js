import { state, byId, api, toast, setDirty, escapeHtml, confirmDialog } from './app-common.js';
import { parseMarkdown, serializePreviewBodyToMarkdown, slugifyHeading } from './app-markdown.js';
import {
  getNoteSessionState,
  getNoteSessionChangeVersion,
  bumpNoteSessionChangeVersion,
  resetNoteSessionChangeVersion,
  bindNoteSessionEditor,
  clearNoteSessionEditorBinding,
  resetNoteSessionUnloadState,
  isNoteSessionUnloadFlushed,
  markNoteSessionUnloadFlushed,
  markNoteSessionDirty,
  captureNoteEditorPayload as captureSessionPayload,
  saveNotePayload as saveSessionPayload,
  loadNoteContent as loadSessionNoteContent,
  loadNotesList,
  applyNotesDraftState as applySessionDraftState,
  selectNote as selectSessionNote
} from './app-note-session.js';

const NOTES_AUTOSAVE_DELAY_MS = 700;
const NOTE_SELECTION_TEXT_COLORS = [
  { token: 'sky', label: '钃濆瓧' },
  { token: 'mint', label: '缁垮瓧' },
  { token: 'amber', label: '姗欏瓧' },
  { token: 'rose', label: '绮夊瓧' }
];
const NOTE_SELECTION_BG_COLORS = [
  { token: 'sky-soft', label: '钃濆簳' },
  { token: 'mint-soft', label: '缁垮簳' },
  { token: 'amber-soft', label: '姗欏簳' },
  { token: 'rose-soft', label: '绮夊簳' }
];
let notesAutosaveTimer = 0;
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
let notesSelectionToolbarEl = null;
let notesSelectionToolbarRange = null;
let notesPreviewMutationObserver = null;
let notesSearchState = {
  query: '',
  mode: '',
  matchIndex: -1,
  matches: []
};
let activePreviewSearchHitEl = null;
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
  toggleBtn.textContent = notesSidebarCompact ? '灞曞紑鍒楄〃' : '鏀惰捣鍒楄〃';
  toggleBtn.setAttribute('aria-expanded', notesSidebarCompact ? 'false' : 'true');
}

function syncNotesExtractTool() {
  const tool = byId('notesExtractTool');
  const btn = byId('toggleNotesExtractBtn');
  if (!tool || !btn) return;
  tool.classList.toggle('collapsed', notesExtractCollapsed);
  btn.textContent = notesExtractCollapsed ? '鏄剧ず鎻愬彇' : '闅愯棌鎻愬彇';
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

function getScrollProgress(el) {
  if (!el) return 0;
  const maxScrollTop = Math.max((el.scrollHeight || 0) - (el.clientHeight || 0), 0);
  if (maxScrollTop <= 0) return 0;
  return Math.min(1, Math.max(0, (el.scrollTop || 0) / maxScrollTop));
}

function restoreScrollProgress(el, progress) {
  if (!el) return false;
  const safeProgress = Number.isFinite(progress) ? Math.min(1, Math.max(0, progress)) : 0;
  const maxScrollTop = Math.max((el.scrollHeight || 0) - (el.clientHeight || 0), 0);
  el.scrollTop = maxScrollTop * safeProgress;
  window.requestAnimationFrame(() => {
    el.scrollTop = maxScrollTop * safeProgress;
  });
  return true;
}

function normalizeAnchorText(value) {
  return String(value || '')
    .replace(/\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function buildNormalizedTextMap(text) {
  const raw = String(text || '');
  let normalized = '';
  const rawIndexByNormalizedIndex = [];
  let prevWasSpace = false;

  for (let i = 0; i < raw.length; i += 1) {
    const char = raw[i];
    if (/\s/.test(char)) {
      if (!normalized || prevWasSpace) {
        prevWasSpace = true;
        continue;
      }
      normalized += ' ';
      rawIndexByNormalizedIndex.push(i);
      prevWasSpace = true;
      continue;
    }
    normalized += char;
    rawIndexByNormalizedIndex.push(i);
    prevWasSpace = false;
  }

  normalized = normalized.trim();
  const leadingTrim = normalized.length ? String(raw).search(/\S/) : -1;
  if (leadingTrim > 0 && rawIndexByNormalizedIndex.length) {
    while (rawIndexByNormalizedIndex.length && rawIndexByNormalizedIndex[0] < leadingTrim) {
      rawIndexByNormalizedIndex.shift();
    }
  }

  return {
    normalized,
    rawIndexByNormalizedIndex
  };
}

function findCaseInsensitiveMatchRanges(text, query) {
  const source = String(text || '');
  const needle = String(query || '').trim();
  if (!source || !needle) return [];

  const haystack = source.toLocaleLowerCase();
  const target = needle.toLocaleLowerCase();
  const matches = [];
  let fromIndex = 0;

  while (fromIndex <= haystack.length) {
    const idx = haystack.indexOf(target, fromIndex);
    if (idx < 0) break;
    matches.push({
      start: idx,
      end: idx + target.length
    });
    fromIndex = idx + Math.max(target.length, 1);
  }
  return matches;
}

function getPreviewTextAnchor() {
  const previewEl = byId('notePreviewBody');
  if (!previewEl) {
    return { headingId: '', anchorText: '', progress: 0 };
  }

  const previewRect = previewEl.getBoundingClientRect();
  const probeTop = previewRect.top + 16;
  const blocks = Array.from(previewEl.querySelectorAll('h1, h2, h3, h4, h5, h6, p, li, blockquote, pre, td, th'));
  let anchorEl = null;

  for (const node of blocks) {
    if (!(node instanceof HTMLElement)) continue;
    const rect = node.getBoundingClientRect();
    if (rect.bottom <= probeTop) continue;
    const text = normalizeAnchorText(node.innerText || node.textContent || '');
    if (!text) continue;
    anchorEl = node;
    break;
  }

  if (!anchorEl) {
    const headings = Array.from(previewEl.querySelectorAll('[data-heading-id]'));
    const headingId = headings.length ? String(headings[0].getAttribute('data-heading-id') || '') : '';
    return {
      headingId,
      anchorText: '',
      progress: getScrollProgress(previewEl)
    };
  }

  const nearestHeading = anchorEl.closest('[data-heading-id]');
  return {
    headingId: String(nearestHeading?.getAttribute('data-heading-id') || ''),
    anchorText: normalizeAnchorText(anchorEl.innerText || anchorEl.textContent || '').slice(0, 120),
    progress: getScrollProgress(previewEl)
  };
}

function findSourceIndexByAnchorText(content, anchorText) {
  const normalizedAnchor = normalizeAnchorText(anchorText);
  if (!normalizedAnchor) return -1;

  const sourceMap = buildNormalizedTextMap(content);
  if (!sourceMap.normalized) return -1;

  const candidates = [];
  const full = normalizedAnchor;
  if (full.length >= 12) candidates.push(full);
  if (full.length > 60) candidates.push(full.slice(0, 60));
  if (full.length > 40) candidates.push(full.slice(0, 40));
  if (full.length > 24) candidates.push(full.slice(0, 24));
  if (full.length > 16) candidates.push(full.slice(0, 16));

  for (const snippet of candidates) {
    const idx = sourceMap.normalized.indexOf(snippet);
    if (idx >= 0) {
      return sourceMap.rawIndexByNormalizedIndex[idx] ?? 0;
    }
  }
  return -1;
}

function capturePreviewPosition() {
  const previewEl = byId('notePreviewBody');
  if (!previewEl) {
    return { headingId: '', anchorText: '', progress: 0 };
  }
  return getPreviewTextAnchor();
}

function syncSourcePositionFromPreview(position = null) {
  const sourceEl = byId('noteContent');
  if (!sourceEl) return;
  const snapshot = position || capturePreviewPosition();
  const content = String(sourceEl.value || '');

  const anchorIndex = findSourceIndexByAnchorText(content, String(snapshot?.anchorText || ''));
  if (anchorIndex >= 0) {
    scrollSourceToIndex(anchorIndex);
    return;
  }

  const headingId = String(snapshot?.headingId || '');
  if (headingId) {
    const target = notesStructureCache.find((item) => item.id === headingId);
    if (target) {
      activeOutlineHeadingId = target.id;
      syncActiveOutlineHeading();
      scrollSourceToHeading(target);
      return;
    }
  }

  restoreScrollProgress(sourceEl, Number(snapshot?.progress || 0));
}

function setNotesContentView(mode) {
  const nextMode = mode === 'markdown' ? 'markdown' : 'rendered';
  if (nextMode === notesContentView) {
    syncNotesContentMode();
    return;
  }
  const prevMode = notesContentView;
  const previewPosition = prevMode === 'rendered' && nextMode === 'markdown'
    ? capturePreviewPosition()
    : null;
  if (prevMode === 'rendered') {
    syncRenderedNoteSourceFromPreview();
  }
  notesContentView = nextMode;
  syncNotesContentMode();
  if (prevMode === 'rendered' && nextMode === 'markdown') {
    syncSourcePositionFromPreview(previewPosition);
    return;
  }
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
  return getSourceScrollTopForIndex(sourceEl, Number(heading.startIndex || 0));
}

function getSourceScrollTopForIndex(sourceEl, index) {
  if (!sourceEl) return 0;
  const computed = window.getComputedStyle(sourceEl);
  const rawLineHeight = Number.parseFloat(computed.lineHeight || '');
  const fontSize = Number.parseFloat(computed.fontSize || '16');
  const lineHeight = Number.isFinite(rawLineHeight) ? rawLineHeight : fontSize * 1.7;
  const paddingTop = Number.parseFloat(computed.paddingTop || '0') || 0;
  const paddingLeft = Number.parseFloat(computed.paddingLeft || '0') || 0;
  const paddingRight = Number.parseFloat(computed.paddingRight || '0') || 0;
  const innerWidth = Math.max(sourceEl.clientWidth - paddingLeft - paddingRight, 1);
  const beforeText = String(sourceEl.value || '').slice(0, Math.max(Number(index || 0), 0));
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

function scrollSourceToIndex(index) {
  const sourceEl = byId('noteContent');
  if (!sourceEl) return false;

  const cursor = Math.max(Number(index || 0), 0);
  const scrollTop = getSourceScrollTopForIndex(sourceEl, cursor);
  sourceEl.selectionStart = cursor;
  sourceEl.selectionEnd = cursor;
  sourceEl.scrollTop = scrollTop;
  window.requestAnimationFrame(() => {
    sourceEl.scrollTop = scrollTop;
  });
  return true;
}

function resetNotesSearchState() {
  notesSearchState = {
    query: '',
    mode: '',
    matchIndex: -1,
    matches: []
  };
}

function clearPreviewSearchHighlight() {
  if (activePreviewSearchHitEl) {
    activePreviewSearchHitEl.classList.remove('notes-search-hit');
    activePreviewSearchHitEl = null;
  }
  window.clearTimeout(clearPreviewSearchHighlight._timer);
}

function flashPreviewSearchHit(element) {
  if (!(element instanceof HTMLElement)) return;
  clearPreviewSearchHighlight();
  element.classList.add('notes-search-hit');
  activePreviewSearchHitEl = element;
  clearPreviewSearchHighlight._timer = window.setTimeout(() => {
    if (activePreviewSearchHitEl === element) {
      element.classList.remove('notes-search-hit');
      activePreviewSearchHitEl = null;
    }
  }, 1600);
}

function getSearchHitBlock(node, previewEl) {
  if (!node || !previewEl) return null;
  const anchor = node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
  if (!(anchor instanceof Element)) return null;
  return anchor.closest('h1, h2, h3, h4, h5, h6, p, li, blockquote, pre, td, th, .notes-preview-empty');
}

function collectPreviewTextSegments(previewEl) {
  if (!previewEl) {
    return { text: '', segments: [] };
  }

  const walker = document.createTreeWalker(
    previewEl,
    NodeFilter.SHOW_TEXT,
    {
      acceptNode(node) {
        if (!node || !String(node.nodeValue || '').trim()) {
          return NodeFilter.FILTER_REJECT;
        }
        return NodeFilter.FILTER_ACCEPT;
      }
    }
  );

  const segments = [];
  let text = '';
  let current = walker.nextNode();
  while (current) {
    const value = String(current.nodeValue || '');
    const start = text.length;
    text += value;
    segments.push({
      node: current,
      start,
      end: start + value.length
    });
    current = walker.nextNode();
  }

  return { text, segments };
}

function createPreviewRangeFromOffsets(segments, start, end) {
  const startSeg = segments.find((segment) => start >= segment.start && start < segment.end);
  const endSeg = segments.find((segment) => end > segment.start && end <= segment.end);
  if (!startSeg || !endSeg) return null;

  const range = document.createRange();
  range.setStart(startSeg.node, Math.max(start - startSeg.start, 0));
  range.setEnd(endSeg.node, Math.max(end - endSeg.start, 0));
  return range;
}

function revealPreviewSearchRange(range, previewEl) {
  if (!range || !previewEl) return false;

  const rect = range.getBoundingClientRect();
  const previewRect = previewEl.getBoundingClientRect();
  const relativeTop = rect.top - previewRect.top + previewEl.scrollTop;
  const nextTop = Math.max(relativeTop - 24, 0);
  previewEl.scrollTop = nextTop;
  window.requestAnimationFrame(() => {
    previewEl.scrollTop = nextTop;
  });

  const hitBlock = getSearchHitBlock(range.startContainer, previewEl);
  if (hitBlock) {
    flashPreviewSearchHit(hitBlock);
  }
  return true;
}

function getNextSearchMatchIndex(matches, currentIndex, reverse = false) {
  if (!Array.isArray(matches) || !matches.length) return -1;
  if (currentIndex < 0 || currentIndex >= matches.length) {
    return reverse ? matches.length - 1 : 0;
  }
  if (reverse) {
    return currentIndex <= 0 ? matches.length - 1 : currentIndex - 1;
  }
  return currentIndex >= matches.length - 1 ? 0 : currentIndex + 1;
}

function navigateMarkdownSearch(query, reverse = false) {
  const sourceEl = byId('noteContent');
  if (!sourceEl) return false;

  const text = String(sourceEl.value || '');
  const matches = findCaseInsensitiveMatchRanges(text, query);
  if (!matches.length) {
    toast(`没有找到“${query}”`);
    resetNotesSearchState();
    return false;
  }

  const shouldReset = notesSearchState.query !== query || notesSearchState.mode !== 'markdown';
  let nextIndex = -1;
  if (shouldReset) {
    const anchor = Number(sourceEl.selectionStart || 0);
    if (reverse) {
      nextIndex = matches.findLastIndex
        ? matches.findLastIndex((match) => match.start < anchor)
        : (() => {
            for (let i = matches.length - 1; i >= 0; i -= 1) {
              if (matches[i].start < anchor) return i;
            }
            return -1;
          })();
      if (nextIndex < 0) nextIndex = matches.length - 1;
    } else {
      nextIndex = matches.findIndex((match) => match.start >= anchor);
      if (nextIndex < 0) nextIndex = 0;
    }
  } else {
    nextIndex = getNextSearchMatchIndex(matches, notesSearchState.matchIndex, reverse);
  }

  const match = matches[nextIndex];
  notesSearchState = {
    query,
    mode: 'markdown',
    matchIndex: nextIndex,
    matches
  };
  sourceEl.selectionStart = match.start;
  sourceEl.selectionEnd = match.end;
  scrollSourceToIndex(match.start);
  return true;
}

function navigateRenderedSearch(query, reverse = false) {
  const previewEl = byId('notePreviewBody');
  if (!previewEl) return false;

  const collected = collectPreviewTextSegments(previewEl);
  const matches = findCaseInsensitiveMatchRanges(collected.text, query);
  if (!matches.length) {
    toast(`没有找到“${query}”`);
    clearPreviewSearchHighlight();
    resetNotesSearchState();
    return false;
  }

  const shouldReset = notesSearchState.query !== query || notesSearchState.mode !== 'rendered';
  let nextIndex = -1;
  if (shouldReset) {
    const probeTop = (previewEl.scrollTop || 0) + 16;
    nextIndex = reverse ? matches.length - 1 : 0;
    for (let i = 0; i < matches.length; i += 1) {
      const range = createPreviewRangeFromOffsets(collected.segments, matches[i].start, matches[i].end);
      if (!range) continue;
      const rect = range.getBoundingClientRect();
      const previewRect = previewEl.getBoundingClientRect();
      const top = rect.top - previewRect.top + previewEl.scrollTop;
      if ((!reverse && top >= probeTop) || (reverse && top >= probeTop)) {
        nextIndex = reverse ? Math.max(i - 1, 0) : i;
        break;
      }
    }
  } else {
    nextIndex = getNextSearchMatchIndex(matches, notesSearchState.matchIndex, reverse);
  }

  const match = matches[nextIndex];
  const range = createPreviewRangeFromOffsets(collected.segments, match.start, match.end);
  if (!range) {
    toast(`没有找到“${query}”`);
    resetNotesSearchState();
    return false;
  }

  notesSearchState = {
    query,
    mode: 'rendered',
    matchIndex: nextIndex,
    matches
  };
  revealPreviewSearchRange(range, previewEl);
  return true;
}

function navigateNoteSearch(reverse = false) {
  const searchEl = byId('noteContentSearch');
  const query = String(searchEl?.value || '').trim();
  if (!query) {
    toast('先输入要搜索的内容');
    resetNotesSearchState();
    clearPreviewSearchHighlight();
    return false;
  }

  if (notesContentView === 'markdown') {
    return navigateMarkdownSearch(query, reverse);
  }
  return navigateRenderedSearch(query, reverse);
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
      return `## 绗旇锛?{item.title || 'Untitled'}\n${blocks}`;
    })
    .join('\n\n');
}

function getExtractSegmentTitle(title, index = 0) {
  return String(title || '').trim() || `鐗囨 ${index + 1}`;
}

function setExtractStatus(message) {
  const host = byId('notesExtractStatus');
  if (host) {
    host.textContent = message;
  }
}

function renderNoteContentSurface() {
  const previewEl = byId('notePreviewBody');
  const sourceEl = byId('noteContent');
  if (!previewEl || !sourceEl) return;
  if (notesPreviewEditing) return;
  const html = parseMarkdown(sourceEl.value || '').html;
  previewEl.innerHTML = html.trim() ? html : '<div class="notes-preview-empty">褰撳墠杩樻病鏈夋鏂囧唴瀹广€傚彲浠ュ厛杈撳叆鎴栧鍏?Markdown锛岀郴缁熶細杞垚姝ｅ父绗旇姝ｆ枃鏄剧ず銆?/div>';
  syncNotesContentMode();
}

function ensureNotesSelectionToolbar() {
  if (notesSelectionToolbarEl && document.body.contains(notesSelectionToolbarEl)) {
    return notesSelectionToolbarEl;
  }

  const toolbar = document.createElement('div');
  toolbar.id = 'notesSelectionToolbar';
  toolbar.className = 'notes-selection-toolbar hidden';
  toolbar.innerHTML = `
    <div class="notes-selection-toolbar-section">
      <span class="notes-selection-toolbar-label">鏂囧瓧</span>
      <div class="notes-selection-toolbar-swatches">
        ${NOTE_SELECTION_TEXT_COLORS.map((item) => `
          <button
            class="notes-selection-swatch color-${item.token}"
            type="button"
            data-selection-action="text-color"
            data-selection-token="${item.token}"
            aria-label="${item.label}"
            title="${item.label}"
          ></button>
        `).join('')}
      </div>
    </div>
    <div class="notes-selection-toolbar-divider"></div>
    <div class="notes-selection-toolbar-section">
      <span class="notes-selection-toolbar-label">鑳屾櫙</span>
      <div class="notes-selection-toolbar-swatches">
        ${NOTE_SELECTION_BG_COLORS.map((item) => `
          <button
            class="notes-selection-swatch color-${item.token}"
            type="button"
            data-selection-action="background-color"
            data-selection-token="${item.token}"
            aria-label="${item.label}"
            title="${item.label}"
          ></button>
        `).join('')}
      </div>
    </div>
  `;

  toolbar.addEventListener('mousedown', (event) => {
    event.preventDefault();
  });
  toolbar.addEventListener('click', (event) => {
    const button = event.target instanceof Element ? event.target.closest('[data-selection-action]') : null;
    if (!button) return;
    const action = String(button.getAttribute('data-selection-action') || '');
    const token = String(button.getAttribute('data-selection-token') || '');
    if (!action || !token) return;
    applySelectionColor(action, token);
  });

  document.body.appendChild(toolbar);
  notesSelectionToolbarEl = toolbar;
  return toolbar;
}

function hideNotesSelectionToolbar() {
  notesSelectionToolbarRange = null;
  if (!notesSelectionToolbarEl) return;
  notesSelectionToolbarEl.classList.add('hidden');
}

function getPreviewSelectionRange() {
  const previewEl = byId('notePreviewBody');
  if (!previewEl || notesContentView !== 'rendered') return null;
  const selection = window.getSelection();
  if (!selection || selection.rangeCount < 1 || selection.isCollapsed) return null;
  const range = selection.getRangeAt(0);
  const commonNode = range.commonAncestorContainer;
  if (!previewEl.contains(commonNode)) return null;
  if (!String(selection.toString() || '').trim()) return null;
  return range;
}

function getSelectionStyleAttrName(action) {
  if (action === 'text-color') return 'data-note-color';
  if (action === 'background-color') return 'data-note-bg';
  return '';
}

function getClosestStyledSpan(node, attrName, root) {
  let current = node instanceof Element ? node : node?.parentElement || null;
  while (current && current !== root) {
    if (current.tagName === 'SPAN' && current.hasAttribute(attrName)) {
      return current;
    }
    current = current.parentElement;
  }
  return null;
}

function getClosestTag(node, tagName, root) {
  let current = node instanceof Element ? node : node?.parentElement || null;
  const expected = String(tagName || '').toUpperCase();
  while (current && current !== root) {
    if (current.tagName === expected) {
      return current;
    }
    current = current.parentElement;
  }
  return null;
}

function copyNoteStyleAttributes(source, target, options = {}) {
  const exclude = new Set(Array.isArray(options.exclude) ? options.exclude : []);
  ['data-note-color', 'data-note-bg'].forEach((attrName) => {
    if (exclude.has(attrName)) return;
    const value = String(source.getAttribute?.(attrName) || '').trim();
    if (value) {
      target.setAttribute(attrName, value);
    }
  });
}

function fragmentHasMeaningfulContent(fragment) {
  if (!fragment) return false;
  return Array.from(fragment.childNodes || []).some((node) => {
    if (node.nodeType === Node.TEXT_NODE) {
      return String(node.textContent || '').length > 0;
    }
    return true;
  });
}

function stripSelectionStyleFromFragment(fragment, attrName) {
  if (!fragment || !attrName) return;
  const styledNodes = fragment.querySelectorAll?.(`span[${attrName}]`) || [];
  styledNodes.forEach((node) => {
    node.removeAttribute(attrName);
    if (!node.hasAttribute('data-note-color') && !node.hasAttribute('data-note-bg')) {
      const childNodes = Array.from(node.childNodes || []);
      node.replaceWith(...childNodes);
    }
  });
}

function replaceStyleInsideSingleSpan(range, attrName, token, previewEl) {
  if (!range || !attrName || !token || !previewEl) return false;

  const startSpan = getClosestStyledSpan(range.startContainer, attrName, previewEl);
  const endSpan = getClosestStyledSpan(range.endContainer, attrName, previewEl);
  if (!startSpan || startSpan !== endSpan) return false;

  const containerSpan = startSpan;
  const beforeRange = document.createRange();
  beforeRange.selectNodeContents(containerSpan);
  beforeRange.setEnd(range.startContainer, range.startOffset);

  const selectedRange = range.cloneRange();
  const afterRange = document.createRange();
  afterRange.selectNodeContents(containerSpan);
  afterRange.setStart(range.endContainer, range.endOffset);

  const beforeFragment = beforeRange.cloneContents();
  const selectedFragment = selectedRange.cloneContents();
  const afterFragment = afterRange.cloneContents();
  stripSelectionStyleFromFragment(selectedFragment, attrName);

  const replacement = document.createDocumentFragment();

  if (fragmentHasMeaningfulContent(beforeFragment)) {
    const beforeSpan = document.createElement('span');
    copyNoteStyleAttributes(containerSpan, beforeSpan);
    beforeSpan.appendChild(beforeFragment);
    replacement.appendChild(beforeSpan);
  }

  if (fragmentHasMeaningfulContent(selectedFragment)) {
    const selectedSpan = document.createElement('span');
    copyNoteStyleAttributes(containerSpan, selectedSpan, { exclude: [attrName] });
    selectedSpan.setAttribute(attrName, token);
    selectedSpan.appendChild(selectedFragment);
    replacement.appendChild(selectedSpan);
  }

  if (fragmentHasMeaningfulContent(afterFragment)) {
    const afterSpan = document.createElement('span');
    copyNoteStyleAttributes(containerSpan, afterSpan);
    afterSpan.appendChild(afterFragment);
    replacement.appendChild(afterSpan);
  }

  containerSpan.replaceWith(replacement);
  return true;
}

function isCaretAtListItemStart(range, listItem) {
  if (!range || !listItem || !range.collapsed) return false;
  const probe = document.createRange();
  probe.selectNodeContents(listItem);
  probe.setEnd(range.startContainer, range.startOffset);
  return !String(probe.toString() || '').trim();
}

function unwrapEditableListItem(listItem) {
  if (!listItem) return false;
  const parentList = listItem.parentElement;
  if (!parentList || !/^(UL|OL)$/.test(parentList.tagName)) return false;

  const paragraph = document.createElement('p');
  const trailingBlocks = [];
  Array.from(listItem.childNodes || []).forEach((child) => {
    if (child.nodeType === Node.ELEMENT_NODE && /^(UL|OL)$/.test(child.nodeName.toUpperCase())) {
      trailingBlocks.push(child);
      return;
    }
    paragraph.appendChild(child);
  });

  const listTag = parentList.tagName.toLowerCase();
  const beforeItems = [];
  const afterItems = [];
  let seenCurrent = false;
  Array.from(parentList.children || []).forEach((child) => {
    if (child === listItem) {
      seenCurrent = true;
      return;
    }
    if (!seenCurrent) {
      beforeItems.push(child);
      return;
    }
    afterItems.push(child);
  });

  const buildListFromItems = (items) => {
    if (!items.length) return null;
    const nextList = document.createElement(listTag);
    items.forEach((item) => nextList.appendChild(item));
    return nextList;
  };

  const beforeList = buildListFromItems(beforeItems);
  const afterList = buildListFromItems(afterItems);
  const replacement = document.createDocumentFragment();
  if (beforeList) replacement.appendChild(beforeList);
  replacement.appendChild(paragraph);
  trailingBlocks.forEach((block) => replacement.appendChild(block));
  if (afterList) replacement.appendChild(afterList);
  parentList.replaceWith(replacement);

  const selection = window.getSelection();
  if (selection) {
    const nextRange = document.createRange();
    nextRange.selectNodeContents(paragraph);
    nextRange.collapse(true);
    selection.removeAllRanges();
    selection.addRange(nextRange);
  }
  return true;
}

function handlePreviewListMarkerDelete(event, previewEl) {
  if (!event || (event.key !== 'Backspace' && event.key !== 'Delete')) return false;
  const selection = window.getSelection();
  if (!selection || selection.rangeCount < 1 || !selection.isCollapsed) return false;
  const range = selection.getRangeAt(0);
  if (!previewEl.contains(range.startContainer)) return false;

  const listItem = getClosestTag(range.startContainer, 'LI', previewEl);
  if (!listItem) return false;
  if (!isCaretAtListItemStart(range, listItem)) return false;

  event.preventDefault();
  if (!unwrapEditableListItem(listItem)) return false;
  syncPreviewEditToSource();
  forceSaveCurrentNoteSilently();
  return true;
}

function showNotesSelectionToolbarForRange(range) {
  const toolbar = ensureNotesSelectionToolbar();
  const rect = range.getBoundingClientRect();
  if (!rect || (!rect.width && !rect.height)) {
    hideNotesSelectionToolbar();
    return;
  }

  notesSelectionToolbarRange = range.cloneRange();
  toolbar.classList.remove('hidden');
  const toolbarRect = toolbar.getBoundingClientRect();
  const top = Math.max(rect.top + window.scrollY - toolbarRect.height - 10, window.scrollY + 10);
  const left = Math.min(
    Math.max(rect.left + window.scrollX + (rect.width / 2) - (toolbarRect.width / 2), window.scrollX + 10),
    window.scrollX + window.innerWidth - toolbarRect.width - 10
  );
  toolbar.style.top = `${top}px`;
  toolbar.style.left = `${left}px`;
}

function refreshNotesSelectionToolbar() {
  const range = getPreviewSelectionRange();
  if (!range || notesPreviewEditing === false) {
    hideNotesSelectionToolbar();
    return;
  }
  showNotesSelectionToolbarForRange(range);
}

function applySelectionColor(action, token) {
  const previewEl = byId('notePreviewBody');
  const selection = window.getSelection();
  if (!previewEl || !selection || !notesSelectionToolbarRange) return;
  const attrName = getSelectionStyleAttrName(action);
  if (!attrName) return;

  selection.removeAllRanges();
  selection.addRange(notesSelectionToolbarRange);
  if (selection.isCollapsed) {
    hideNotesSelectionToolbar();
    return;
  }

  const range = selection.getRangeAt(0);
  if (replaceStyleInsideSingleSpan(range, attrName, token, previewEl)) {
    selection.removeAllRanges();
    syncPreviewEditToSource();
    forceSaveCurrentNoteSilently();
    hideNotesSelectionToolbar();
    return;
  }

  const previewFragment = range.cloneContents();
  if (previewFragment.querySelector('h1, h2, h3, h4, h5, h6, p, div, ul, ol, li, blockquote, pre, table, hr')) {
    toast('当前只支持对单段行内文字着色，请不要跨整块内容一起选。');
    hideNotesSelectionToolbar();
    return;
  }

  const wrapper = document.createElement('span');
  wrapper.setAttribute(attrName, token);
  const fragment = range.extractContents();
  if (!fragment.childNodes.length) {
    hideNotesSelectionToolbar();
    return;
  }
  stripSelectionStyleFromFragment(fragment, attrName);

  wrapper.appendChild(fragment);
  range.insertNode(wrapper);
  selection.removeAllRanges();
  syncPreviewEditToSource();
  forceSaveCurrentNoteSilently();
  hideNotesSelectionToolbar();
}

function syncPreviewEditToSource() {
  const previewEl = byId('notePreviewBody');
  const sourceEl = byId('noteContent');
  if (!previewEl || !sourceEl) return;
  sourceEl.value = serializePreviewBodyToMarkdown(previewEl);
  handleCurrentNoteContentChanged();
}

function syncRenderedNoteSourceFromPreview(options = {}) {
  if (extractViewActive || notesContentView !== 'rendered') return false;
  const previewEl = byId('notePreviewBody');
  const sourceEl = byId('noteContent');
  if (!previewEl || !sourceEl) return false;

  const nextMarkdown = serializePreviewBodyToMarkdown(previewEl);
  if (nextMarkdown === String(sourceEl.value || '')) {
    return false;
  }

  sourceEl.value = nextMarkdown;
  if (options.markDirty === false) {
    syncCurrentNoteContentCount();
    renderNoteStructure();
    return true;
  }

  handleCurrentNoteContentChanged();
  return true;
}

function handleCurrentNoteContentChanged() {
  bumpNoteSessionChangeVersion();
  markNoteSessionDirty();
  syncCurrentNoteContentCount();
  syncCurrentNoteSaveIndicator();
  renderNoteStructure();
  if (extractViewActive) {
    queueExtractAggregateSave();
  } else {
    scheduleNotesAutosave();
  }
}

function syncPreviewEditToSourceForUnload() {
  if (syncRenderedNoteSourceFromPreview({ markDirty: false })) {
    bumpNoteSessionChangeVersion();
    markNoteSessionDirty();
  }
}

function forceSaveCurrentNoteSilently() {
  if (!state.notes.currentId || !state.notes.dirty) return;
  syncCurrentNoteSaveIndicator();
  void saveCurrentNote({ silent: true }).catch((error) => {
    toast(`鑷姩淇濆瓨澶辫触: ${error.message}`);
  });
}

function sendJsonOnUnload(path, payload) {
  const text = JSON.stringify(payload);
  const blob = new Blob([text], { type: 'application/json; charset=utf-8' });
  if (navigator.sendBeacon) {
    const ok = navigator.sendBeacon(path, blob);
    if (ok) return true;
  }
  try {
    void fetch(path, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8'
      },
      body: text,
      keepalive: true
    });
    return true;
  } catch {
    return false;
  }
}

function buildExtractViewPendingSaves() {
  if (!extractViewActive) return [];
  const raw = String(byId('noteContent')?.value || '');
  const sections = parseExtractViewContent(raw);
  if (sections.length !== extractViewItems.length) return [];

  const saves = [];
  for (let i = 0; i < extractViewItems.length; i += 1) {
    const item = extractViewItems[i];
    const context = extractContextByNoteId.get(String(item.id || ''));
    if (!context) continue;
    const segments = parseExtractSegments(sections[i], context.segmentTitles || []);
    if (segments.length !== context.ranges.length) continue;

    let updatedContent = context.fullContent;
    for (let j = context.ranges.length - 1; j >= 0; j -= 1) {
      const range = context.ranges[j];
      updatedContent = updatedContent.slice(0, range.bodyStart) + segments[j] + updatedContent.slice(range.bodyEnd);
    }

    saves.push({
      id: String(context.id || ''),
      title: String(context.title || 'Untitled'),
      content: updatedContent
    });
  }
  return saves;
}

function flushPendingNoteSaveOnUnload() {
  if (isNoteSessionUnloadFlushed()) return;
  if (!state.notes.currentId || !state.notes.dirty) return;

  if (notesContentView === 'rendered') {
    syncPreviewEditToSourceForUnload();
  }

  markNoteSessionUnloadFlushed();
  cancelNotesAutosave();

  if (extractViewActive) {
    const saves = buildExtractViewPendingSaves();
    if (!saves.length) return;
    saves.forEach((payload) => {
      if (!payload.id) return;
      sendJsonOnUnload('/api/notes/save', payload);
    });
    return;
  }

  sendJsonOnUnload('/api/notes/save', {
    id: String(state.notes.currentId || ''),
    title: getCurrentNoteTitle(),
    content: String(byId('noteContent')?.value || '')
  });
}

function sanitizeExportFileName(name) {
  const base = String(name || 'Untitled')
    .replace(/[\\/:*?"<>|]+/g, '-')
    .replace(/\s+/g, ' ')
    .trim();
  return base || 'Untitled';
}

function escapeHtmlText(text) {
  return String(text || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function buildExportPlainText(markdown) {
  const html = parseMarkdown(markdown).html;
  const host = document.createElement('div');
  host.innerHTML = html;
  return String(host.innerText || host.textContent || '')
    .replace(/\r\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function buildExportHtmlDocument(title, markdown) {
  const rendered = parseMarkdown(markdown).html || '<p></p>';
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${escapeHtmlText(title)}</title>
  <style>
    :root { color-scheme: light; }
    @page { size: A4; margin: 16mm 14mm 18mm; }
    body { margin: 40px auto; max-width: 860px; padding: 0 24px 48px; font: 16px/1.75 "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif; color: #1f2328; background: #ffffff; }
    h1, h2, h3, h4, h5, h6 { line-height: 1.35; margin: 1.3em 0 .5em; }
    p, li { margin: 0 0 .8em; }
    pre { overflow: auto; padding: 14px 16px; border-radius: 10px; background: #f6f8fa; }
    code { font-family: "Cascadia Code", Consolas, monospace; }
    blockquote { margin: 0 0 1em; padding: .2em 1em; border-left: 4px solid #d0d7de; color: #57606a; background: #f6f8fa; }
    table { border-collapse: collapse; width: 100%; margin: 0 0 1em; }
    th, td { border: 1px solid #d0d7de; padding: 8px 10px; text-align: left; }
    img { max-width: 100%; }
    [data-note-color="sky"] { color: #0b73c9; }
    [data-note-color="mint"] { color: #0b8f5c; }
    [data-note-color="amber"] { color: #b16a00; }
    [data-note-color="rose"] { color: #b3366b; }
    [data-note-bg="sky-soft"] { background: rgba(54, 139, 255, .16); border-radius: 4px; }
    [data-note-bg="mint-soft"] { background: rgba(36, 168, 102, .30); border-radius: 4px; box-shadow: inset 0 0 0 1px rgba(28, 145, 88, .18); }
    [data-note-bg="amber-soft"] { background: rgba(255, 177, 66, .20); border-radius: 4px; }
    [data-note-bg="rose-soft"] { background: rgba(226, 92, 146, .16); border-radius: 4px; }
  </style>
</head>
<body>
${rendered}
</body>
</html>`;
}

function getCurrentNoteExportPayload(format) {
  const title = getCurrentNoteTitle();
  const content = String(byId('noteContent')?.value || '');
  const noteMeta = (state.notes.list || []).find((note) => String(note.id || '') === String(state.notes.currentId || '')) || {};
  const htmlDocument = buildExportHtmlDocument(title, content);

  if (format === 'html') {
    return {
      extension: 'html',
      mimeType: 'text/html;charset=utf-8',
      text: htmlDocument
    };
  }
  if (format === 'pdf') {
    return {
      extension: 'pdf',
      mimeType: 'application/pdf',
      text: htmlDocument,
      transport: 'server-pdf'
    };
  }
  if (format === 'txt') {
    return {
      extension: 'txt',
      mimeType: 'text/plain;charset=utf-8',
      text: buildExportPlainText(content)
    };
  }
  if (format === 'json') {
    return {
      extension: 'json',
      mimeType: 'application/json;charset=utf-8',
      text: JSON.stringify({
        id: String(state.notes.currentId || ''),
        title,
        content,
        updated: String(noteMeta.updated || ''),
        exported_at: new Date().toISOString()
      }, null, 2)
    };
  }
  return {
    extension: 'md',
    mimeType: 'text/markdown;charset=utf-8',
    text: content
  };
}

function triggerTextDownload(filename, mimeType, text) {
  const blob = new Blob([text], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = filename;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function triggerBlobDownload(filename, blob) {
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = filename;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
}

async function exportCurrentNotePdf(filename, html) {
  const res = await fetch('/api/notes/export-pdf', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=utf-8'
    },
    body: JSON.stringify({
      title: filename.replace(/\.pdf$/i, ''),
      html
    })
  });

  if (!res.ok) {
    const txt = await res.text();
    let error = `HTTP ${res.status}`;
    if (txt) {
      try {
        const payload = JSON.parse(txt);
        error = payload.error || error;
      } catch {
        error = txt || error;
      }
    }
    throw new Error(error);
  }

  const blob = await res.blob();
  triggerBlobDownload(filename, blob);
}

async function exportCurrentNote() {
  if (!state.notes.currentId) {
    toast('当前没有可导出的笔记');
    return;
  }
  if (extractViewActive) {
    toast('提取视图下请先恢复正文，再导出当前笔记。');
    return;
  }

  if (notesContentView === 'rendered') {
    syncRenderedNoteSourceFromPreview();
  }
  if (state.notes.dirty) {
    await saveCurrentNote({ silent: true });
  }

  const format = String(byId('noteExportFormat')?.value || 'md').trim().toLowerCase();
  const payload = getCurrentNoteExportPayload(format);
  const title = sanitizeExportFileName(getCurrentNoteTitle());
  if (payload.transport === 'server-pdf') {
    await exportCurrentNotePdf(`${title}.pdf`, payload.text);
    toast('宸插鍑轰负 PDF');
    return;
  }
  triggerTextDownload(`${title}.${payload.extension}`, payload.mimeType, payload.text);
  toast(`宸插鍑轰负 ${payload.extension.toUpperCase()}`);
}

async function saveExtractResult(noteId, nextText) {
  const context = extractContextByNoteId.get(noteId);
  if (!context) return;
  const segments = parseExtractSegments(nextText, context.segmentTitles || []);
  if (segments.length !== context.ranges.length) {
    throw new Error(`笔记“${context.title}”的提取片段数量已变化，当前应为 ${context.ranges.length} 段，请不要删除片段标题。`);
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
      content: updatedContent,
      save_intent: 'autosave'
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
    throw new Error('提取视图分段已被破坏，请不要删除“# 笔记：...”分隔标题。');
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
      toast(`鎻愬彇鍐呭淇濆瓨澶辫触: ${error.message}`);
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
      toast(`鎻愬彇鍐呭淇濆瓨澶辫触锛屽凡鐩存帴鎭㈠姝ｆ枃: ${error.message}`);
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
  setExtractStatus(`已提取 ${items.length} 条笔记，共 ${totalSegments} 个片段，现已进入主内容框集中编辑。`);
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
    host.innerHTML = '<div class="notes-outline-empty">鎶婁竴澶ф Markdown 璐磋繘鍙充晶鍚庯紝杩欓噷浼氳嚜鍔ㄥ垪鍑虹洰褰曠粨鏋勩€?/div>';
    return;
  }

  const renderOutlineButton = (heading, extraClass = '') => `
    <button class="${[
      'notes-outline-item',
      `level-${Math.min(heading.level, 6)}`,
      heading.id === activeOutlineHeadingId ? 'active' : '',
      extraClass
    ].filter(Boolean).join(' ')}" type="button" data-outline-id="${escapeOutlineText(heading.id)}">
      <span class="outline-indent depth-${Math.min(Math.max(heading.level - 1, 0), 5)}" aria-hidden="true"></span>
      <span class="outline-text">${escapeOutlineText(heading.text)}</span>
      <span class="level-label">H${heading.level}</span>
    </button>
  `;

  let html = '';
  let index = 0;
  while (index < headings.length) {
    const heading = headings[index];
    if (heading.level !== 1) {
      html += renderOutlineButton(heading);
      index += 1;
      continue;
    }

    const children = [];
    let cursor = index + 1;
    while (cursor < headings.length && headings[cursor].level !== 1) {
      children.push(headings[cursor]);
      cursor += 1;
    }

    if (!children.length) {
      html += renderOutlineButton(heading, 'notes-outline-item-h1');
      index = cursor;
      continue;
    }

    html += `
      <div class="notes-outline-group" data-outline-group="${escapeOutlineText(heading.id)}">
        ${renderOutlineButton(heading, 'notes-outline-item-h1')}
        <div class="notes-outline-children" aria-hidden="true">
          ${children.map((child) => renderOutlineButton(child, 'notes-outline-item-child')).join('')}
        </div>
      </div>
    `;
    index = cursor;
  }

  host.innerHTML = html;
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

function setCurrentNoteTitle(title, noteId = state.notes.currentId) {
  const nextTitle = String(title || '').trim() || 'Untitled';
  const hidden = byId('noteTitle');
  if (hidden) hidden.value = nextTitle;
  updateCurrentNoteMeta(nextTitle, noteId);
}

function beginNotesListTitleEdit(noteId) {
  const id = String(noteId || '').trim();
  if (!id) return;
  editingNoteTitleId = id;
  renderNotesList();
  window.requestAnimationFrame(() => {
    const input = byId('notesList')?.querySelector(`.note-item[data-id="${id}"] .note-item-title-edit`);
    if (!input) return;
    input.focus();
    input.select();
  });
}

async function renameNoteTitle(noteId, rawTitle) {
  const id = String(noteId || '').trim();
  if (!id) return;
  const title = String(rawTitle || '').trim() || 'Untitled';
  const existing = (state.notes.list || []).find((item) => String(item.id || '').trim() === id);
  if (existing && String(existing.title || '').trim() === title) {
    if (id === String(state.notes.currentId || '').trim()) {
      setCurrentNoteTitle(title);
    }
    return;
  }

  if (id === String(state.notes.currentId || '').trim()) {
    setCurrentNoteTitle(title);
    bumpNoteSessionChangeVersion();
    markNoteSessionDirty();
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
      content: note.content || '',
      save_intent: 'autosave'
    })
  });
  if (!savePayload.ok) throw new Error(savePayload.error || 'rename note failed');

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
      const input = document.createElement('input');
      input.className = 'note-item-title-edit';
      input.type = 'text';
      input.value = String(note.title || 'Untitled');
      item.appendChild(input);
    } else {
      const titleEl = document.createElement('div');
      titleEl.className = 'note-item-title';
      titleEl.textContent = String(note.title || 'Untitled');
      titleEl.addEventListener('dblclick', (event) => {
        event.preventDefault();
        event.stopPropagation();
        beginNotesListTitleEdit(note.id);
      });
      item.appendChild(titleEl);
    }
    item.addEventListener('click', () => {
      if (editingNoteTitleId === note.id) return;
      void selectNote(note.id);
    });
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
      void persistNotesOrder().catch((e) => toast(`绗旇鎺掑簭淇濆瓨澶辫触: ${e.message}`));
    });

    if (editingNoteTitleId === note.id) {
      const input = item.querySelector('.note-item-title-edit');
      const finish = async (commit) => {
        const previousTitle = String(note.title || 'Untitled').trim() || 'Untitled';
        const nextValue = commit ? String(input.value || '').trim() || 'Untitled' : previousTitle;
        editingNoteTitleId = '';
        try {
          if (commit && nextValue !== previousTitle) {
            await renameNoteTitle(note.id, nextValue);
            toast('笔记标题已更新');
          } else {
            renderNotesList();
          }
        } catch (error) {
          toast(`鏍囬淇敼澶辫触: ${error.message}`);
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
  createWrap.innerHTML = '<button id="newNoteBtnInline" class="notes-create-btn" type="button" aria-label="鏂板缓绗旇">+</button>';
  listEl.appendChild(createWrap);

  const inlineCreateBtn = createWrap.querySelector('#newNoteBtnInline');
  if (inlineCreateBtn) {
    inlineCreateBtn.onclick = () => {
      createNewNote().catch((error) => {
        toast(`鏂板缓澶辫触: ${error.message}`);
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

function getNoteTitleById(noteId = state.notes.currentId) {
  const id = String(noteId || '').trim();
  if (!id) return 'Untitled';
  if (id === String(state.notes.currentId || '').trim()) {
    return getCurrentNoteTitle();
  }
  const entry = (state.notes.list || []).find((note) => String(note.id || '').trim() === id);
  return String(entry?.title || '').trim() || 'Untitled';
}

function updateCurrentNoteMeta(title, noteId = state.notes.currentId) {
  const id = String(noteId || '').trim();
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

function getCurrentNoteContentCount() {
  const content = String(byId('noteContent')?.value || '').replace(/\r\n/g, '\n');
  return content.length;
}

function syncCurrentNoteContentCount() {
  const host = byId('noteContentCount');
  if (!host) return;
  host.textContent = String(getCurrentNoteContentCount());
}

function syncCurrentNoteSaveIndicator() {
  const dot = byId('noteContentSaveDot');
  if (!dot) return;
  const pending = !!state.notes.dirty || !!getNoteSessionState().saveInFlight;
  dot.classList.toggle('pending', pending);
}

function snapshotEditorForNote(noteId) {
  if (notesContentView === 'rendered') {
    syncRenderedNoteSourceFromPreview({ markDirty: false });
  }
  return {
    id: String(noteId || '').trim(),
    title: getNoteTitleById(noteId),
    content: String(byId('noteContent')?.value || '')
  };
}

function captureNoteEditorPayload(noteId = state.notes.currentId) {
  return captureSessionPayload(noteId, {
    getTitleById: getNoteTitleById,
    syncRenderedToSource: syncRenderedNoteSourceFromPreview
  });
}

async function loadNoteContent(id, expectedGeneration) {
  return loadSessionNoteContent(id, {
    expectedGeneration,
    cancelAutosave: cancelNotesAutosave,
    applyLoadedNote(note) {
      setCurrentNoteTitle(note.title || '', note.id);
      byId('noteContent').value = note.content || '';
      if (notesContentView === 'rendered') {
        renderNoteContentSurface();
      }
      syncCurrentNoteContentCount();
      syncCurrentNoteSaveIndicator();
      renderNotesList();
      renderNoteStructure();
    }
  });
}

export async function loadNotes() {
  return loadNotesList({
    cancelAutosave: cancelNotesAutosave,
    onListLoaded() {
      renderNotesList();
    },
    applyLoadedNote(note) {
      setCurrentNoteTitle(note.title || '', note.id);
      byId('noteContent').value = note.content || '';
      if (notesContentView === 'rendered') {
        renderNoteContentSurface();
      }
      syncCurrentNoteContentCount();
      syncCurrentNoteSaveIndicator();
      renderNotesList();
      renderNoteStructure();
    },
    onEmptyList() {
      setCurrentNoteTitle('');
      byId('noteContent').value = '';
      clearNoteSessionEditorBinding();
      syncCurrentNoteContentCount();
      syncCurrentNoteSaveIndicator();
      renderNoteStructure();
    }
  });
}

export function applyNotesDraftState(draft = {}) {
  applySessionDraftState(draft, {
    applyDraft({ id, title, content }) {
      setCurrentNoteTitle(title || getCurrentNoteTitle(), id || state.notes.currentId);
      byId('noteContent').value = content;
      syncCurrentNoteContentCount();
      syncCurrentNoteSaveIndicator();
      renderNotesList();
      renderNoteStructure();
    }
  });
}

function scheduleNotesAutosave() {
  cancelNotesAutosave();
  notesAutosaveTimer = window.setTimeout(() => {
    notesAutosaveTimer = 0;
    void saveCurrentNote({ silent: true }).catch((error) => {
      toast(`鑷姩淇濆瓨澶辫触: ${error.message}`);
    });
  }, NOTES_AUTOSAVE_DELAY_MS);
}

async function saveNotePayloadRefactored(payload, options = {}) {
  return saveSessionPayload(payload, {
    ...options,
    cancelAutosave: cancelNotesAutosave,
    scheduleAutosave: scheduleNotesAutosave,
    capturePayload: captureNoteEditorPayload,
    onMissingId() {
      toast('请先新建笔记');
    },
    onSaveStateChanged: syncCurrentNoteSaveIndicator,
    onSavedToast() {
      toast('笔记已保存');
    },
    onCurrentNoteSaved({ title, content, response }) {
      if (typeof response.content === 'string' && response.content !== content) {
        byId('noteContent').value = response.content;
        if (notesContentView === 'rendered') {
          renderNoteContentSurface();
        }
        renderNoteStructure();
        syncCurrentNoteContentCount();
      }
      updateCurrentNoteMeta(title);
    }
  });
}

export async function saveCurrentNote(options = {}) {
  if (!state.notes.currentId) {
    if (!options.silent) {
      toast('请先新建笔记');
    }
    return;
  }

  if (notesContentView === 'rendered') {
    syncRenderedNoteSourceFromPreview();
  }

  const payload = captureNoteEditorPayload(state.notes.currentId);
  if (!payload) return;
  payload.changeVersion = getNoteSessionChangeVersion();
  const manual = options.manual === true;
  return saveNotePayloadRefactored(payload, {
    ...options,
    saveIntent: manual ? 'manual' : (options.saveIntent || 'autosave')
  });
}

export async function selectNote(id) {
  return selectSessionNote(id, {
    cancelAutosave: cancelNotesAutosave,
    capturePayload: captureNoteEditorPayload,
    resetExtractViewState,
    extractViewActive,
    saveExtractAggregateView,
    onBeforeSwitch(targetId) {
      if (editingNoteTitleId && editingNoteTitleId !== targetId) {
        editingNoteTitleId = '';
      }
    },
    onSwitchError(error) {
      toast(`切换失败: ${error.message}`);
    },
    applyLoadedNote(note) {
      setCurrentNoteTitle(note.title || '', note.id);
      byId('noteContent').value = note.content || '';
      if (notesContentView === 'rendered') {
        renderNoteContentSurface();
      }
      syncCurrentNoteContentCount();
      syncCurrentNoteSaveIndicator();
      renderNotesList();
      renderNoteStructure();
    }
  });
}

export function initNotesHandlers() {
  resetNoteSessionUnloadState();
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
      toast(`鍒楄〃鐘舵€佷繚瀛樺け璐? ${error.message}`);
    });
  };
  byId('toggleNotesExtractBtn').onclick = () => {
    notesExtractCollapsed = !notesExtractCollapsed;
    syncNotesExtractTool();
    void persistNotesExtractCollapsed().catch((error) => {
      toast(`鎻愬彇鏍忕姸鎬佷繚瀛樺け璐? ${error.message}`);
    });
  };

  const previewEl = byId('notePreviewBody');
  const sourceEl = byId('noteContent');
  let previewMutationSyncQueued = false;
  const queuePreviewMutationSync = () => {
    if (!notesPreviewEditing || notesContentView !== 'rendered') return;
    if (previewMutationSyncQueued) return;
    previewMutationSyncQueued = true;
    window.requestAnimationFrame(() => {
      previewMutationSyncQueued = false;
      syncPreviewEditToSource();
    });
  };

  if (notesPreviewMutationObserver) {
    notesPreviewMutationObserver.disconnect();
  }
  notesPreviewMutationObserver = new MutationObserver((mutations) => {
    const hasRealChange = mutations.some((mutation) => {
      if (mutation.type === 'characterData') return true;
      if (mutation.type === 'childList') {
        return mutation.addedNodes.length > 0 || mutation.removedNodes.length > 0;
      }
      return false;
    });
    if (hasRealChange) {
      queuePreviewMutationSync();
    }
  });
  notesPreviewMutationObserver.observe(previewEl, {
    subtree: true,
    childList: true,
    characterData: true
  });

  previewEl.addEventListener('focus', () => {
    notesPreviewEditing = true;
  });
  previewEl.addEventListener('input', () => {
    syncPreviewEditToSource();
  });
  previewEl.addEventListener('cut', queuePreviewMutationSync);
  previewEl.addEventListener('paste', queuePreviewMutationSync);
  previewEl.addEventListener('drop', queuePreviewMutationSync);
  previewEl.addEventListener('keydown', (event) => {
    if (handlePreviewListMarkerDelete(event, previewEl)) {
      hideNotesSelectionToolbar();
    }
  });
  previewEl.addEventListener('blur', () => {
    notesPreviewEditing = false;
    hideNotesSelectionToolbar();
    syncPreviewEditToSource();
    forceSaveCurrentNoteSilently();
    renderNoteContentSurface();
  });
  previewEl.addEventListener('mouseup', () => {
    window.requestAnimationFrame(() => {
      refreshNotesSelectionToolbar();
    });
  });
  previewEl.addEventListener('keyup', () => {
    window.requestAnimationFrame(() => {
      refreshNotesSelectionToolbar();
    });
  });
  previewEl.addEventListener('scroll', () => {
    if (!notesSelectionToolbarRange) return;
    const range = getPreviewSelectionRange();
    if (!range) {
      hideNotesSelectionToolbar();
      return;
    }
    showNotesSelectionToolbarForRange(range);
  });
  sourceEl.addEventListener('input', () => {
    handleCurrentNoteContentChanged();
  });
  sourceEl.addEventListener('change', handleCurrentNoteContentChanged);
  sourceEl.addEventListener('cut', () => {
    window.requestAnimationFrame(handleCurrentNoteContentChanged);
  });
  sourceEl.addEventListener('paste', () => {
    window.requestAnimationFrame(handleCurrentNoteContentChanged);
  });
  sourceEl.addEventListener('drop', () => {
    window.requestAnimationFrame(handleCurrentNoteContentChanged);
  });

  byId('notesViewMarkdownBtn').onclick = () => {
    setNotesContentView('markdown');
    hideNotesSelectionToolbar();
  };
  byId('notesViewRenderedBtn').onclick = () => {
    setNotesContentView('rendered');
  };
  byId('saveCurrentNoteBtn').onclick = () => {
    const saver = extractViewActive
      ? saveExtractAggregateView()
      : saveCurrentNote({ manual: true });
    saver.catch((error) => {
      toast(`淇濆瓨澶辫触: ${error.message}`);
    });
  };
  byId('exportCurrentNoteBtn').onclick = () => {
    exportCurrentNote().catch((error) => {
      toast(`瀵煎嚭澶辫触: ${error.message}`);
    });
  };
  byId('noteContentSearch').addEventListener('input', () => {
    resetNotesSearchState();
    clearPreviewSearchHighlight();
  });
  byId('noteContentSearch').addEventListener('keydown', (event) => {
    if (event.key !== 'Enter') return;
    event.preventDefault();
    navigateNoteSearch(!!event.shiftKey);
  });

  document.addEventListener('selectionchange', () => {
    const active = document.activeElement;
    if (active === previewEl || previewEl.contains(active)) {
      window.requestAnimationFrame(() => {
        refreshNotesSelectionToolbar();
      });
      return;
    }
    const range = getPreviewSelectionRange();
    if (!range) {
      hideNotesSelectionToolbar();
    }
  });

  window.addEventListener('pagehide', flushPendingNoteSaveOnUnload);
  window.addEventListener('beforeunload', flushPendingNoteSaveOnUnload);

  byId('copyNoteOutlineBtn').onclick = async () => {
    const structure = parseNoteStructure(byId('noteContent')?.value || '');
    const headings = Array.isArray(structure?.headings) ? structure.headings : [];
    if (!headings.length) {
      toast('褰撳墠娌℃湁鍙鍒剁殑鐩綍');
      return;
    }
    const outlineText = headings.map((heading) => `${'  '.repeat(Math.max(heading.level - 1, 0))}${heading.text}`).join('\n');
    try {
      await navigator.clipboard.writeText(outlineText);
      toast('目录已复制');
    } catch (error) {
      toast(`鐩綍澶嶅埗澶辫触: ${error.message}`);
    }
  };

  syncCurrentNoteContentCount();
  syncCurrentNoteSaveIndicator();

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
        toast(`鎻愬彇澶辫触: ${error.message}`);
        setExtractStatus('提取失败，请检查范围后重试。');
      });
    };
  });
  byId('exitNotesExtractBtn').onclick = () => {
    exitExtractView({ allowDiscardOnFailure: true }).catch((error) => {
      toast(`鎭㈠姝ｆ枃澶辫触: ${error.message}`);
    });
  };

  byId('deleteNoteBtn').onclick = async () => {
    const id = state.notes.currentId;
    if (!id) return;
    if (!(await confirmDialog('纭鍒犻櫎褰撳墠绗旇鍚楋紵', { title: '鍒犻櫎绗旇', confirmText: '鍒犻櫎', danger: true }))) return;

    const payload = await api('/api/notes/delete', {
      method: 'POST',
      body: JSON.stringify({ id })
    });
    if (!payload.ok) throw new Error(payload.error || 'delete note failed');

    cancelNotesAutosave();
    resetNoteSessionChangeVersion();
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
