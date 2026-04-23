export const state = {
  categories: [],
  data: {},
  hotkeys: {},
  hotkeyDefs: [],
  behavior: { auto_refresh_enabled: 1, refresh_every_uses: 3, refresh_every_minutes: 5 },
  app: { active_mode: 'shortcuts' },
  assistant: {
    enabled: 1,
    api_endpoint: 'https://ark.cn-beijing.volces.com/api/v3/responses',
    api_key: '',
    has_api_key: 0,
    model: 'doubao-seed-2-0-lite-260215',
    model_options: [
      { id: 'doubao-seed-2-0-lite-260215', name: 'Doubao Seed 2.0 Lite (Vision)', enabled: 1 },
      { id: 'doubao-seed-2-0-pro-260215', name: 'Doubao Seed 2.0 Pro (Vision)', enabled: 1 }
    ],
    prompt: '编程题：直接给完整可运行代码，并在代码框中输出；随后对核心思路做简短说明。选择题：先写15字以内题目总结，再直接给答案。',
    active_template: 'default_template',
    templates: [{
      name: 'default_template',
      prompt: '编程题：直接给完整可运行代码，并在代码框中输出；随后对核心思路做简短说明。选择题：先写15字以内题目总结，再直接给答案。'
    }],
    overlay_opacity: 92,
    disable_copy: 1,
    rate_limit_enabled: 1,
    rate_limit_per_hour: 100
  },
  selectedCategoryId: null,
  protectedCategoryIds: new Set(['fields', 'prompts', 'quick_fields']),
  dirty: false,
  notes: { list: [], currentId: '', dirty: false },
  capture: { phoneUrl: '' }
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
  { id: 'assistant_overlay_up', label: '问答悬浮上移', default: '!Up', group: 'assistant', group_label: '截图问答特有', scope: 'assistant' },
  { id: 'assistant_overlay_down', label: '问答悬浮下移', default: '!Down', group: 'assistant', group_label: '截图问答特有', scope: 'assistant' }
];

export function byId(id) {
  return document.getElementById(id);
}

export function toast(msg) {
  const toastEl = byId('toast');
  toastEl.textContent = msg;
  toastEl.classList.add('show');
  setTimeout(() => toastEl.classList.remove('show'), 1800);
}

export function setDirty(v, mode = 'shortcuts') {
  if (mode === 'shortcuts') {
    state.dirty = !!v;
  } else if (mode === 'notes') {
    state.notes.dirty = !!v;
  }

  const sub = byId('subTitle');
  if (state.dirty || state.notes.dirty) {
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
  const isTesting = mode === 'testing';

  byId('modeShortcutsBtn').classList.toggle('active', isShortcuts);
  byId('modeNotesBtn').classList.toggle('active', mode === 'notes');
  byId('modeCaptureBtn').classList.toggle('active', mode === 'capture');
  byId('modeAssistantBtn').classList.toggle('active', mode === 'assistant');
  byId('modeHotkeysBtn').classList.toggle('active', isHotkeys);
  byId('modeTestingBtn').classList.toggle('active', isTesting);

  byId('shortcutsView').classList.toggle('hidden', !isShortcuts);
  byId('hotkeysView').classList.toggle('hidden', !isHotkeys);
  byId('notesView').classList.toggle('hidden', mode !== 'notes');
  byId('captureView').classList.toggle('hidden', mode !== 'capture');
  byId('assistantView').classList.toggle('hidden', mode !== 'assistant');
  byId('testingView').classList.toggle('hidden', !isTesting);
}
