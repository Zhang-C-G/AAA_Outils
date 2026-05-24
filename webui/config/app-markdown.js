import { marked } from './vendor/marked.esm.js';

const ALLOWED_TAGS = new Set([
  'A', 'BLOCKQUOTE', 'BR', 'CODE', 'DEL', 'DIV', 'EM', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6',
  'HR', 'IMG', 'INPUT', 'LI', 'OL', 'P', 'PRE', 'SPAN', 'STRONG', 'TABLE', 'TBODY', 'TD',
  'TH', 'THEAD', 'TR', 'UL'
]);

const URL_PROTOCOLS = new Set(['http:', 'https:', 'mailto:', 'tel:']);
const ALLOWED_NOTE_COLOR_TOKENS = new Set([
  'sky',
  'mint',
  'amber',
  'rose',
  'sky-soft',
  'mint-soft',
  'amber-soft',
  'rose-soft'
]);

function isSafeUrl(raw, tagName) {
  const value = String(raw || '').trim();
  if (!value) return '';
  if (value.startsWith('#') || value.startsWith('/')) return value;
  if (tagName === 'IMG' && /^data:image\/[a-z0-9.+-]+;base64,/i.test(value)) return value;
  try {
    const url = new URL(value, window.location.origin);
    return URL_PROTOCOLS.has(url.protocol) ? url.href : '';
  } catch {
    return '';
  }
}

function sanitizeNode(node) {
  if (!node) return;

  if (node.nodeType === Node.COMMENT_NODE) {
    node.remove();
    return;
  }

  if (node.nodeType !== Node.ELEMENT_NODE) {
    return;
  }

  const tag = node.tagName.toUpperCase();
  if (!ALLOWED_TAGS.has(tag)) {
    if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'IFRAME' || tag === 'OBJECT') {
      node.remove();
      return;
    }
    const children = Array.from(node.childNodes);
    const fragment = document.createDocumentFragment();
    children.forEach((child) => fragment.appendChild(child));
    node.replaceWith(fragment);
    children.forEach((child) => sanitizeNode(child));
    return;
  }

  Array.from(node.attributes).forEach((attr) => {
    const name = attr.name.toLowerCase();
    const value = attr.value;
    const isHeadingAttr = /^H[1-6]$/.test(tag) && (name === 'id' || name === 'data-heading-id');
    const isCodeClass = tag === 'CODE' && name === 'class' && /^language-[\w-]+$/.test(value);
    const isCellAlign = (tag === 'TH' || tag === 'TD') && name === 'align';
    const isNoteColorAttr = tag === 'SPAN'
      && (name === 'data-note-color' || name === 'data-note-bg')
      && ALLOWED_NOTE_COLOR_TOKENS.has(String(value || '').trim().toLowerCase());

    if (isHeadingAttr || isCodeClass || isCellAlign || isNoteColorAttr) {
      return;
    }

    if (tag === 'A' && name === 'href') {
      const safe = isSafeUrl(value, tag);
      if (safe) {
        node.setAttribute('href', safe);
      } else {
        node.removeAttribute(attr.name);
      }
      return;
    }

    if (tag === 'IMG' && name === 'src') {
      const safe = isSafeUrl(value, tag);
      if (safe) {
        node.setAttribute('src', safe);
      } else {
        node.remove();
      }
      return;
    }

    if ((tag === 'A' || tag === 'IMG') && (name === 'title' || name === 'alt')) {
      return;
    }

    if (tag === 'INPUT' && (name === 'type' || name === 'checked' || name === 'disabled')) {
      return;
    }

    node.removeAttribute(attr.name);
  });

  if (tag === 'A') {
    node.setAttribute('target', '_blank');
    node.setAttribute('rel', 'noopener noreferrer');
  }

  if (tag === 'INPUT') {
    if ((node.getAttribute('type') || '').toLowerCase() !== 'checkbox') {
      node.remove();
      return;
    }
    node.setAttribute('disabled', '');
  }

  Array.from(node.childNodes).forEach((child) => sanitizeNode(child));
}

function extractPlainTextFromTokens(tokens = []) {
  return tokens.map((token) => {
    if (!token) return '';
    if (Array.isArray(token.tokens)) return extractPlainTextFromTokens(token.tokens);
    if (Array.isArray(token.items)) {
      return token.items.map((item) => extractPlainTextFromTokens(item.tokens || [])).join(' ');
    }
    return String(token.text || '');
  }).join('');
}

export function slugifyHeading(text, index) {
  const base = String(text || '')
    .trim()
    .toLowerCase()
    .replace(/[^\w\u4e00-\u9fa5-]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-+|-+$/g, '');
  return `${base || 'section'}-${index}`;
}

export function parseMarkdown(markdown) {
  const toc = [];
  let headingIndex = 0;
  const renderer = new marked.Renderer();

  renderer.heading = function heading(token) {
    const depth = Number(token.depth || 1);
    const text = extractPlainTextFromTokens(token.tokens || []).trim();
    headingIndex += 1;
    const id = slugifyHeading(text, headingIndex);
    toc.push({ id, text, level: depth });
    return `<h${depth} data-heading-id="${id}" id="${id}">${this.parser.parseInline(token.tokens || [])}</h${depth}>`;
  };

  const rawHtml = marked.parse(String(markdown || ''), {
    gfm: true,
    breaks: false,
    renderer
  });

  const template = document.createElement('template');
  template.innerHTML = rawHtml;
  Array.from(template.content.childNodes).forEach((child) => sanitizeNode(child));
  return { toc, html: template.innerHTML.trim() };
}

export function collectInlineMarkdown(node) {
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
  if (tag === 'DEL' || tag === 'S') {
    const inner = Array.from(node.childNodes || []).map((child) => collectInlineMarkdown(child)).join('');
    return inner ? `~~${inner}~~` : '';
  }
  if (tag === 'CODE') {
    const inner = Array.from(node.childNodes || []).map((child) => collectInlineMarkdown(child)).join('');
    return inner ? `\`${inner}\`` : '';
  }
  if (tag === 'A') {
    const inner = Array.from(node.childNodes || []).map((child) => collectInlineMarkdown(child)).join('').trim();
    const href = String(node.getAttribute('href') || '').trim();
    return inner && href ? `[${inner}](${href})` : inner;
  }
  if (tag === 'IMG') {
    const alt = String(node.getAttribute('alt') || '');
    const src = String(node.getAttribute('src') || '').trim();
    return src ? `![${alt}](${src})` : '';
  }
  if (tag === 'SPAN') {
    const inner = Array.from(node.childNodes || []).map((child) => collectInlineMarkdown(child)).join('');
    const noteColor = String(node.getAttribute('data-note-color') || '').trim().toLowerCase();
    const noteBg = String(node.getAttribute('data-note-bg') || '').trim().toLowerCase();
    const attrs = [];
    if (ALLOWED_NOTE_COLOR_TOKENS.has(noteColor)) {
      attrs.push(`data-note-color="${noteColor}"`);
    }
    if (ALLOWED_NOTE_COLOR_TOKENS.has(noteBg)) {
      attrs.push(`data-note-bg="${noteBg}"`);
    }
    if (!attrs.length) {
      return inner;
    }
    return `<span ${attrs.join(' ')}>${inner}</span>`;
  }

  return Array.from(node.childNodes || []).map((child) => collectInlineMarkdown(child)).join('');
}

function prefixMarkdownBlock(text, prefix) {
  return String(text || '')
    .split('\n')
    .map((line) => `${prefix}${line}`.trimEnd())
    .join('\n');
}

function serializeListItem(node, ordered, index) {
  const marker = ordered ? `${index + 1}. ` : '- ';
  const lines = [];
  const nested = [];
  let checkbox = '';
  let inline = '';

  Array.from(node.childNodes || []).forEach((child) => {
    const tag = (child.nodeName || '').toUpperCase();
    if (tag === 'INPUT' && String(child.getAttribute('type') || '').toLowerCase() === 'checkbox') {
      checkbox = child.hasAttribute('checked') ? '[x] ' : '[ ] ';
      return;
    }
    if (tag === 'UL' || tag === 'OL') {
      const nestedLines = [];
      collectMarkdownFromPreviewNode(child, nestedLines);
      if (nestedLines.length) nested.push(prefixMarkdownBlock(nestedLines.join('\n'), '  '));
      return;
    }
    inline += collectInlineMarkdown(child);
  });

  const text = inline.replace(/\n{3,}/g, '\n\n').trim();
  lines.push(`${marker}${checkbox}${text}`.trimEnd());
  if (nested.length) lines.push(...nested);
  return lines.join('\n');
}

function serializeTable(node, lines) {
  const rows = Array.from(node.querySelectorAll('tr'));
  if (!rows.length) return;

  const cellsByRow = rows.map((row) =>
    Array.from(row.children || [])
      .filter((cell) => /^(TH|TD)$/.test(cell.nodeName.toUpperCase()))
      .map((cell) => collectInlineMarkdown(cell).replace(/\n+/g, ' ').trim())
  ).filter((row) => row.length);

  if (!cellsByRow.length) return;
  const header = cellsByRow[0];
  lines.push(`| ${header.join(' | ')} |`);
  lines.push(`| ${header.map(() => '---').join(' | ')} |`);
  cellsByRow.slice(1).forEach((row) => {
    lines.push(`| ${row.join(' | ')} |`);
  });
  lines.push('');
}

export function collectMarkdownFromPreviewNode(node, lines) {
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
      const text = serializeListItem(item, tag === 'OL', index);
      if (text) lines.push(text);
    });
    if (items.length) lines.push('');
    return;
  }

  if (tag === 'BLOCKQUOTE') {
    const nestedLines = [];
    Array.from(node.childNodes || []).forEach((child) => collectMarkdownFromPreviewNode(child, nestedLines));
    while (nestedLines.length && !String(nestedLines[nestedLines.length - 1]).trim()) {
      nestedLines.pop();
    }
    if (nestedLines.length) {
      lines.push(prefixMarkdownBlock(nestedLines.join('\n'), '> '));
      lines.push('');
    }
    return;
  }

  if (tag === 'PRE') {
    const codeEl = node.querySelector('code');
    const languageMatch = String(codeEl?.className || '').match(/\blanguage-([\w-]+)\b/);
    const language = languageMatch ? languageMatch[1] : '';
    const code = (node.innerText || node.textContent || '').replace(/\r\n/g, '\n').replace(/\r/g, '\n').trimEnd();
    lines.push(`\`\`\`${language}`);
    if (code) lines.push(code);
    lines.push('```');
    lines.push('');
    return;
  }

  if (tag === 'HR') {
    lines.push('---');
    lines.push('');
    return;
  }

  if (tag === 'TABLE') {
    serializeTable(node, lines);
    return;
  }

  if (tag === 'DIV' || tag === 'SECTION' || tag === 'ARTICLE' || tag === 'THEAD' || tag === 'TBODY' || tag === 'TR') {
    Array.from(node.childNodes || []).forEach((child) => collectMarkdownFromPreviewNode(child, lines));
    return;
  }

  const text = collectInlineMarkdown(node).replace(/\n{3,}/g, '\n\n').trim();
  if (text) {
    lines.push(text);
    lines.push('');
  }
}

export function serializePreviewBodyToMarkdown(bodyEl) {
  const lines = [];
  Array.from(bodyEl?.childNodes || []).forEach((node) => collectMarkdownFromPreviewNode(node, lines));
  while (lines.length && !String(lines[lines.length - 1]).trim()) {
    lines.pop();
  }
  return lines.join('\n');
}
