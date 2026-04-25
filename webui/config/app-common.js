export const state = {
  categories: [],
  data: {},
  hotkeys: {},
  hotkeyDefs: [],
  behavior: { auto_refresh_enabled: 1, refresh_every_uses: 3, refresh_every_minutes: 5 },
  app: {
    active_mode: 'shortcuts',
    mode_order: ['shortcuts', 'notes', 'notes_display', 'capture', 'assistant', 'resume', 'hotkeys', 'testing']
  },
  assistant: {
    enabled: 1,
    api_endpoint: 'https://ark.cn-beijing.volces.com/api/v3/responses',
    api_key: '',
    has_api_key: 0,
    model: 'doubao-seed-2-0-lite-260215',
    model_options: [
      { id: 'doubao-seed-2-0-lite-260215', name: 'Doubao Seed 2.0 Lite (Vision)', enabled: 1 },
      { id: 'doubao-seed-2-0-pro-260215', name: 'Doubao Seed 2.0 Pro (Vision)', enabled: 1 },
      { id: 'doubao-seed-2-0-mini-260215', name: 'Doubao Seed 2.0 Mini (ASR Fast | 语音识别特别快)', enabled: 1 }
    ],
    prompt: '编程题：直接给完整可运行代码，并在代码框中输出；随后对核心思路做简短说明。选择题：先写15字以内题目总结，再直接给答案。',
    active_template: 'default_template',
    templates: [{
      name: 'default_template',
      prompt: '编程题：直接给完整可运行代码，并在代码框中输出；随后对核心思路做简短说明。选择题：先写15字以内题目总结，再直接给答案。'
    }],
    overlay_opacity: 75,
    enhanced_capture_mode: 0,
    disable_copy: 1,
    voice_input_enabled: 0,
    rate_limit_enabled: 1,
    rate_limit_per_hour: 100,
    capture_dir: '',
    latest_capture: '',
    benchmark: {
      image_url: '',
      image_name: '',
      image_kb: 0,
      note: '',
      selected_model: '',
      last_result: null,
      history: []
    }
  },
  selectedCategoryId: null,
  protectedCategoryIds: new Set(['fields', 'prompts', 'quick_fields']),
  dirty: false,
  notes: { list: [], currentId: '', dirty: false },
  notesDisplay: { list: [], currentId: '', dirty: false },
  capture: { phoneUrl: '' },
  resume: {
    profile: { version: 1, updated_at: '', sections: [] },
    flat_map: {},
    selectedSectionId: ''
  }
};

export const fallbackHotkeyDefs = [
  { id: 'toggle_panel', label: '呼出悬浮窗', default: '!q', group: 'shared', group_label: '公共快捷键', scope: 'global' },
  { id: 'open_config', label: '打开主界面', default: '!+q', group: 'shared', group_label: '公共快捷键', scope: 'global' },
  { id: 'close_panel', label: '关闭悬浮窗', default: 'Esc', group: 'shared', group_label: '公共快捷键', scope: 'global' },
  { id: 'confirm_selection', label: '确认插入', default: 'Enter', group: 'shared', group_label: '公共快捷键', scope: 'panel' },
  { id: 'move_up', label: '上移候选', default: 'Up', group: 'shared', group_label: '公共快捷键', scope: 'panel' },
  { id: 'move_down', label: '下移候选', default: 'Down', group: 'shared', group_label: '公共快捷键', scope: 'panel' },
  { id: 'assistant_capture', label: '启动问答悬浮窗', default: '!+a', group: 'assistant', group_label: '截图问答特有', scope: 'assistant' },
  { id: 'assistant_capture_now', label: '截图并问答', default: 'F1', group: 'assistant', group_label: '截图问答特有', scope: 'assistant' },
  { id: 'assistant_voice_input', label: '按住语音输入', default: 'F3', group: 'assistant', group_label: '截图问答特有', scope: 'assistant' },
  { id: 'notes_display_overlay', label: '启动笔记显示悬浮窗', default: 'F4', group: 'notes_display', group_label: '笔记显示特有', scope: 'notes_display' },
  { id: 'assistant_overlay_up', label: '问答悬浮上移', default: '!Up', group: 'assistant', group_label: '截图问答特有', scope: 'assistant' },
  { id: 'assistant_overlay_down', label: '问答悬浮下移', default: '!Down', group: 'assistant', group_label: '截图问答特有', scope: 'assistant' }
];

export function byId(id) {
  return document.getElementById(id);
}

const toastState = {
  host: null,
  seed: 0,
  visible: new Map(),
  timers: new Map()
};

function ensureToastHost() {
  if (toastState.host && document.body.contains(toastState.host)) {
    return toastState.host;
  }
  toastState.host = byId('toastHost');
  if (!toastState.host) {
    toastState.host = document.createElement('section');
    toastState.host.id = 'toastHost';
    toastState.host.className = 'toast-host';
    toastState.host.setAttribute('aria-live', 'polite');
    toastState.host.setAttribute('aria-atomic', 'false');
    document.body.appendChild(toastState.host);
  }
  return toastState.host;
}

function inferToastType(message, type = '') {
  if (type) return type;
  const text = String(message || '');
  if (/失败|错误|异常|invalid|error|failed|无法|未能/i.test(text)) return 'error';
  if (/警告|注意|提醒|warning/i.test(text)) return 'warning';
  if (/成功|已保存|已恢复|已完成|已打开|已触发|已更新|录入成功|启动|生成/i.test(text)) return 'success';
  return 'info';
}

function inferToastDuration(type, duration) {
  if (Number.isFinite(duration) && duration > 0) return duration;
  if (type === 'error') return 3400;
  if (type === 'warning') return 2800;
  return 2200;
}

function normalizeToastInput(input, options = {}) {
  if (typeof input === 'object' && input !== null && !Array.isArray(input)) {
    return normalizeToastInput(input.message || input.msg || '', { ...input, ...options });
  }

  const message = String(input || '').trim();
  const type = inferToastType(message, options.type || '');
  return {
    message,
    type,
    title: String(options.title || '').trim(),
    duration: inferToastDuration(type, options.duration),
    dedupeKey: String(options.dedupeKey || `${type}:${message}`),
    persistent: options.persistent === true
  };
}

function dropToast(id) {
  const el = toastState.visible.get(id);
  if (!el) return;

  const timer = toastState.timers.get(id);
  if (timer) {
    window.clearTimeout(timer);
    toastState.timers.delete(id);
  }

  el.classList.remove('show');
  el.classList.add('hide');
  window.setTimeout(() => {
    if (el.parentNode) el.parentNode.removeChild(el);
    toastState.visible.delete(id);
  }, 220);
}

function scheduleToastRemoval(id, duration) {
  const prev = toastState.timers.get(id);
  if (prev) window.clearTimeout(prev);
  const timer = window.setTimeout(() => dropToast(id), duration);
  toastState.timers.set(id, timer);
}

export function toast(input, options = {}) {
  const payload = normalizeToastInput(input, options);
  if (!payload.message) return null;

  const host = ensureToastHost();
  const existing = Array.from(toastState.visible.entries()).find(([, el]) => el.dataset.dedupeKey === payload.dedupeKey);
  if (existing) {
    const [existingId, el] = existing;
    const bodyEl = el.querySelector('.toast-message');
    const titleEl = el.querySelector('.toast-title');
    if (titleEl) titleEl.textContent = payload.title;
    if (bodyEl) bodyEl.textContent = payload.message;
    el.className = `toast-item toast-${payload.type} show`;
    if (!payload.persistent) scheduleToastRemoval(existingId, payload.duration);
    return existingId;
  }

  const id = `toast-${++toastState.seed}`;
  const item = document.createElement('article');
  item.className = `toast-item toast-${payload.type}`;
  item.dataset.toastId = id;
  item.dataset.dedupeKey = payload.dedupeKey;
  item.setAttribute('role', payload.type === 'error' ? 'alert' : 'status');

  const closeBtn = document.createElement('button');
  closeBtn.type = 'button';
  closeBtn.className = 'toast-close';
  closeBtn.setAttribute('aria-label', '关闭提示');
  closeBtn.textContent = '×';
  closeBtn.onclick = () => dropToast(id);

  const content = document.createElement('div');
  content.className = 'toast-content';

  if (payload.title) {
    const title = document.createElement('div');
    title.className = 'toast-title';
    title.textContent = payload.title;
    content.appendChild(title);
  }

  const message = document.createElement('div');
  message.className = 'toast-message';
  message.textContent = payload.message;
  content.appendChild(message);

  item.appendChild(content);
  item.appendChild(closeBtn);
  host.appendChild(item);
  toastState.visible.set(id, item);

  window.requestAnimationFrame(() => item.classList.add('show'));

  while (toastState.visible.size > 4) {
    const oldestId = toastState.visible.keys().next().value;
    if (!oldestId || oldestId === id) break;
    dropToast(oldestId);
  }

  if (!payload.persistent) {
    scheduleToastRemoval(id, payload.duration);
  }
  return id;
}

toast.success = (message, options = {}) => toast(message, { ...options, type: 'success' });
toast.error = (message, options = {}) => toast(message, { ...options, type: 'error' });
toast.warning = (message, options = {}) => toast(message, { ...options, type: 'warning' });
toast.info = (message, options = {}) => toast(message, { ...options, type: 'info' });

export function setDirty(v, mode = 'shortcuts') {
  if (mode === 'shortcuts') {
    state.dirty = !!v;
  } else if (mode === 'notes') {
    state.notes.dirty = !!v;
  } else if (mode === 'notes_display') {
    state.notesDisplay.dirty = !!v;
  }

  const sub = byId('subTitle');
  if (state.dirty || state.notes.dirty || state.notesDisplay.dirty) {
    sub.textContent = '已修改，系统将自动保存';
    sub.classList.add('dirty-tip');
  } else {
    sub.textContent = 'Web UI Config · 黑白风 · 阴影 · 动效';
    sub.classList.remove('dirty-tip');
  }
}

export async function api(path, options = {}) {
  const headers = {
    'Content-Type': 'application/json; charset=utf-8',
    ...(options.headers || {})
  };
  const res = await fetch(path, {
    ...options,
    headers
  });

  const txt = await res.text();
  let payload = {};
  if (txt) {
    try {
      payload = JSON.parse(txt);
    } catch {
      payload = { raw: txt };
    }
  }

  if (!res.ok) {
    const msg = payload.error || `HTTP ${res.status}`;
    throw new Error(msg);
  }
  return payload;
}

export function toInt(v, def, min = 1, max = 9999) {
  const n = Number(v);
  if (!Number.isFinite(n)) return def;
  return Math.min(max, Math.max(min, Math.round(n)));
}

export function isTruthy(v) {
  if (typeof v === 'number') return v !== 0;
  if (typeof v === 'string') {
    const t = v.trim().toLowerCase();
    return t === '1' || t === 'true' || t === 'yes';
  }
  return !!v;
}

export function escapeHtml(text) {
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

export function validateHotkeyText(hk) {
  const txt = String(hk || '').trim();
  if (!txt) return false;
  return /^[A-Za-z0-9+!^#_\-]+$/.test(txt);
}

export function setModeUi(mode) {
  const isShortcuts = mode === 'shortcuts';
  const isHotkeys = mode === 'hotkeys';
  const isResume = mode === 'resume';
  const isTesting = mode === 'testing';
  const isNotesDisplay = mode === 'notes_display';

  byId('modeShortcutsBtn').classList.toggle('active', isShortcuts);
  byId('modeNotesBtn').classList.toggle('active', mode === 'notes');
  byId('modeNotesDisplayBtn').classList.toggle('active', isNotesDisplay);
  byId('modeCaptureBtn').classList.toggle('active', mode === 'capture');
  byId('modeAssistantBtn').classList.toggle('active', mode === 'assistant');
  byId('modeResumeBtn').classList.toggle('active', isResume);
  byId('modeHotkeysBtn').classList.toggle('active', isHotkeys);
  byId('modeTestingBtn').classList.toggle('active', isTesting);

  byId('shortcutsView').classList.toggle('hidden', !isShortcuts);
  byId('hotkeysView').classList.toggle('hidden', !isHotkeys);
  byId('notesView').classList.toggle('hidden', mode !== 'notes');
  byId('notesDisplayView').classList.toggle('hidden', !isNotesDisplay);
  byId('captureView').classList.toggle('hidden', mode !== 'capture');
  byId('assistantView').classList.toggle('hidden', mode !== 'assistant');
  byId('resumeView').classList.toggle('hidden', !isResume);
  byId('testingView').classList.toggle('hidden', !isTesting);
}
