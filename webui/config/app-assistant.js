import { state, byId, api, toast, toInt } from './app-common.js';

const API_KEY_MASK = '****************';
let assistantAutoSaveTimer = 0;
let assistantAutoSaveInFlight = false;
let assistantAutoSaveQueued = false;

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

function renderHotkeyExplain() {
  const el = byId('assistantHotkeyExplain');
  if (!el) return;
  const hkOpen = hotkeyToFriendly(state.hotkeys?.assistant_capture || '');
  const hkRun = hotkeyToFriendly(state.hotkeys?.assistant_capture_now || '');
  const hkUp = hotkeyToFriendly(state.hotkeys?.assistant_overlay_up || '');
  const hkDown = hotkeyToFriendly(state.hotkeys?.assistant_overlay_down || '');
  el.textContent = `快捷键说明（自动同步配置）：启动悬浮窗 ${hkOpen}；截图并问答 ${hkRun}；答案上滚 ${hkUp}；答案下滚 ${hkDown}。`;
}

function scheduleAssistantAutoSave(immediate = false) {
  if (assistantAutoSaveTimer) {
    clearTimeout(assistantAutoSaveTimer);
    assistantAutoSaveTimer = 0;
  }
  assistantAutoSaveTimer = window.setTimeout(() => {
    void runAssistantAutoSave();
  }, immediate ? 80 : 700);
}

async function runAssistantAutoSave() {
  if (assistantAutoSaveInFlight) {
    assistantAutoSaveQueued = true;
    return;
  }
  assistantAutoSaveInFlight = true;
  try {
    await saveAssistantSettings({ silent: true });
  } catch {
    // 自动保存失败时保持可编辑，用户仍可手动保存查看错误。
  } finally {
    assistantAutoSaveInFlight = false;
    if (assistantAutoSaveQueued) {
      assistantAutoSaveQueued = false;
      scheduleAssistantAutoSave(true);
    }
  }
}

function defaults() {
  return {
    enabled: 1,
    api_endpoint: 'https://ark.cn-beijing.volces.com/api/v3/responses',
    api_key: '',
    has_api_key: 0,
    model: 'doubao-seed-2-0-lite-260215',
    model_options: [
      { id: 'doubao-seed-2-0-lite-260215', name: 'Doubao Seed 2.0 Lite (Vision)', enabled: 1 },
      { id: 'doubao-seed-2-0-pro-260215', name: 'Doubao Seed 2.0 Pro (Vision)', enabled: 1 }
    ],
    prompt: '编程题：直接给编程完整答案，代码写在代码框中，并对核心部分做简短解释。选择题：先写15字以内题目总结，再直接给答案。',
    active_template: 'default_template',
    templates: [{
      name: 'default_template',
      prompt: '编程题：直接给编程完整答案，代码写在代码框中，并对核心部分做简短解释。选择题：先写15字以内题目总结，再直接给答案。'
    }],
    overlay_opacity: 92,
    disable_copy: 1,
    rate_limit_enabled: 1,
    rate_limit_per_hour: 30
  };
}

function normalizeModelOptions(options) {
  const src = Array.isArray(options) ? options : [];
  const out = [];
  const seen = new Set();
  for (const m of src) {
    const id = String(m?.id || '').trim();
    if (!id) continue;
    const key = id.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({
      id,
      name: String(m?.name || id).trim() || id,
      enabled: Number(m?.enabled ?? 1) === 0 ? 0 : 1
    });
  }
  if (!out.length) {
    return defaults().model_options;
  }
  return out;
}

function renderModelOptions(selectedModel) {
  const sel = byId('assistantModel');
  sel.innerHTML = '';

  const list = normalizeModelOptions(state.assistant.model_options);
  for (const item of list) {
    if (Number(item.enabled || 0) === 0) continue;
    const opt = document.createElement('option');
    opt.value = item.id;
    opt.textContent = `${item.name} (${item.id})`;
    sel.appendChild(opt);
  }

  const hasSelected = Array.from(sel.options).some((o) => o.value === selectedModel);
  sel.value = hasSelected ? selectedModel : (sel.options[0]?.value || 'doubao-seed-2-0-lite-260215');
  state.assistant.model = sel.value;
}

function isBrokenPrompt(text) {
  const t = String(text || '').trim();
  if (!t) return true;
  if (/^[?？]+$/.test(t)) return true;
  if (t.includes('???') || t.includes('？？？')) return true;
  return false;
}

function normalizeTemplates(inputTemplates, fallbackPrompt) {
  const list = [];
  const seen = new Set();
  const source = Array.isArray(inputTemplates) ? inputTemplates : [];

  for (const t of source) {
    const name = String(t?.name || '').trim();
    let prompt = String(t?.prompt || '').trim();
    if (!name) continue;
    const low = name.toLowerCase();
    if (seen.has(low)) continue;
    seen.add(low);
    if (isBrokenPrompt(prompt)) prompt = fallbackPrompt;
    list.push({ name, prompt });
  }

  if (!list.length) {
    list.push({ name: 'default_template', prompt: fallbackPrompt });
  }
  return list;
}

function ensureActiveTemplate() {
  const fallback = defaults();
  if (!Array.isArray(state.assistant.templates) || !state.assistant.templates.length) {
    state.assistant.templates = [...fallback.templates];
  }

  const active = String(state.assistant.active_template || '').trim();
  const found = state.assistant.templates.find((t) => t.name === active);
  state.assistant.active_template = found ? found.name : state.assistant.templates[0].name;

  const current = state.assistant.templates.find((t) => t.name === state.assistant.active_template);
  state.assistant.prompt = current?.prompt || fallback.prompt;
}

function renderTemplateControls() {
  const sel = byId('assistantTemplateSelect');
  sel.innerHTML = '';

  for (const t of state.assistant.templates) {
    const opt = document.createElement('option');
    opt.value = t.name;
    opt.textContent = t.name;
    sel.appendChild(opt);
  }

  sel.value = state.assistant.active_template;
  const current = state.assistant.templates.find((t) => t.name === state.assistant.active_template) || state.assistant.templates[0];

  byId('assistantTemplateName').value = current.name;
  byId('assistantPrompt').value = current.prompt;
  state.assistant.prompt = current.prompt;
}

function syncCurrentTemplateFromUi() {
  const currentName = state.assistant.active_template;
  const idx = state.assistant.templates.findIndex((t) => t.name === currentName);
  if (idx < 0) return;

  let nextName = String(byId('assistantTemplateName').value || '').trim();
  if (!nextName) nextName = currentName;

  const duplicated = state.assistant.templates.find((t, i) => i !== idx && t.name.toLowerCase() === nextName.toLowerCase());
  if (duplicated) {
    toast(`模板名重复：${nextName}`);
    byId('assistantTemplateName').value = currentName;
    nextName = currentName;
  }

  let nextPrompt = String(byId('assistantPrompt').value || '').trim();
  if (isBrokenPrompt(nextPrompt)) {
    nextPrompt = defaults().prompt;
  }

  state.assistant.templates[idx].name = nextName;
  state.assistant.templates[idx].prompt = nextPrompt;
  state.assistant.active_template = nextName;
  state.assistant.prompt = nextPrompt;
}

export function applyAssistantState(payload) {
  const fallback = defaults();
  const incoming = payload.assistant || state.assistant || {};

  state.assistant = {
    ...fallback,
    ...incoming
  };
  state.assistant.model_options = normalizeModelOptions(incoming.model_options || state.assistant.model_options);

  if (isBrokenPrompt(state.assistant.prompt)) {
    state.assistant.prompt = fallback.prompt;
  }

  state.assistant.templates = normalizeTemplates(incoming.templates || state.assistant.templates, fallback.prompt);
  ensureActiveTemplate();

  byId('assistantEnabled').checked = Number(state.assistant.enabled || 0) !== 0;
  byId('assistantOpacity').value = toInt(state.assistant.overlay_opacity, 92, 35, 100);
  renderModelOptions(state.assistant.model || 'doubao-seed-2-0-lite-260215');
  byId('assistantEndpoint').value = state.assistant.api_endpoint || 'https://ark.cn-beijing.volces.com/api/v3/responses';
  byId('assistantApiKey').value = Number(state.assistant.has_api_key || 0) !== 0 ? API_KEY_MASK : '';
  byId('assistantDisableCopy').checked = Number(state.assistant.disable_copy ?? 1) !== 0;
  byId('assistantApiKey').placeholder = Number(state.assistant.has_api_key || 0) !== 0
    ? '已保存密钥（星号表示保持不变）'
    : '请输入 API Key';
  byId('assistantRateEnabled').checked = Number(state.assistant.rate_limit_enabled || 0) !== 0;
  byId('assistantRatePerHour').value = toInt(state.assistant.rate_limit_per_hour, 30, 1, 10000);
  renderTemplateControls();
  renderHotkeyExplain();
}

function readAssistantFromUi() {
  syncCurrentTemplateFromUi();

  state.assistant.enabled = byId('assistantEnabled').checked ? 1 : 0;
  state.assistant.overlay_opacity = toInt(byId('assistantOpacity').value, 92, 35, 100);
  state.assistant.model = (byId('assistantModel').value || '').trim() || 'doubao-seed-2-0-lite-260215';
  state.assistant.api_endpoint = (byId('assistantEndpoint').value || '').trim() || 'https://ark.cn-beijing.volces.com/api/v3/responses';
  state.assistant.disable_copy = byId('assistantDisableCopy').checked ? 1 : 0;
  state.assistant.rate_limit_enabled = byId('assistantRateEnabled').checked ? 1 : 0;
  state.assistant.rate_limit_per_hour = toInt(byId('assistantRatePerHour').value, 30, 1, 10000);

  const inputKey = String(byId('assistantApiKey').value || '').trim();
  if (inputKey && inputKey !== API_KEY_MASK) {
    state.assistant.api_key = inputKey;
    state.assistant.keep_api_key = 0;
  } else {
    state.assistant.api_key = '';
    state.assistant.keep_api_key = Number(state.assistant.has_api_key || 0) !== 0 ? 1 : 0;
  }

  ensureActiveTemplate();
}

export async function saveAssistantSettings(options = {}) {
  const silent = !!options.silent;
  readAssistantFromUi();

  const payload = await api('/api/assistant/save-settings', {
    method: 'POST',
    body: JSON.stringify(state.assistant)
  });
  if (!payload.ok) throw new Error(payload.error || 'save assistant failed');

  state.assistant = { ...state.assistant, ...(payload.settings || {}) };
  state.assistant.api_key = '';
  state.assistant.keep_api_key = 0;
  applyAssistantState({ assistant: state.assistant });
  if (!silent) {
    toast('助手设置已保存');
  }
}

export function initAssistantHandlers() {
  byId('assistantTemplateSelect').onchange = () => {
    syncCurrentTemplateFromUi();
    state.assistant.active_template = byId('assistantTemplateSelect').value;
    renderTemplateControls();
    scheduleAssistantAutoSave();
  };

  byId('assistantTemplateName').onchange = () => {
    syncCurrentTemplateFromUi();
    renderTemplateControls();
    scheduleAssistantAutoSave();
  };

  byId('assistantPrompt').oninput = () => {
    syncCurrentTemplateFromUi();
    scheduleAssistantAutoSave();
  };

  byId('assistantAddTplBtn').onclick = () => {
    syncCurrentTemplateFromUi();
    const names = new Set(state.assistant.templates.map((t) => t.name.toLowerCase()));
    let i = 1;
    let name = `template_${i}`;
    while (names.has(name.toLowerCase())) {
      i += 1;
      name = `template_${i}`;
    }
    state.assistant.templates.push({ name, prompt: defaults().prompt });
    state.assistant.active_template = name;
    renderTemplateControls();
    scheduleAssistantAutoSave(true);
  };

  byId('assistantDeleteTplBtn').onclick = () => {
    syncCurrentTemplateFromUi();
    if (state.assistant.templates.length <= 1) {
      toast('至少保留一个模板');
      return;
    }
    const name = state.assistant.active_template;
    if (!confirm(`确认删除模板【${name}】吗？`)) return;
    state.assistant.templates = state.assistant.templates.filter((t) => t.name !== name);
    state.assistant.active_template = state.assistant.templates[0].name;
    renderTemplateControls();
    scheduleAssistantAutoSave(true);
  };

  byId('assistantSaveBtn').onclick = () => saveAssistantSettings().catch((e) => toast(`保存失败: ${e.message}`));
  byId('assistantEnabled').onchange = () => scheduleAssistantAutoSave(true);
  byId('assistantOpacity').oninput = () => scheduleAssistantAutoSave();
  byId('assistantModel').onchange = () => scheduleAssistantAutoSave(true);
  byId('assistantEndpoint').oninput = () => scheduleAssistantAutoSave();
  byId('assistantDisableCopy').onchange = () => scheduleAssistantAutoSave(true);
  byId('assistantApiKey').onchange = () => scheduleAssistantAutoSave(true);
  byId('assistantRateEnabled').onchange = () => scheduleAssistantAutoSave(true);
  byId('assistantRatePerHour').oninput = () => scheduleAssistantAutoSave();

  byId('assistantShowOverlayBtn').onclick = async () => {
    try {
      await saveAssistantSettings();
      const payload = await api('/api/assistant/show-overlay', { method: 'POST', body: '{}' });
      if (!payload.ok) throw new Error(payload.error || 'show overlay failed');
      toast('悬浮窗启动指令已发送');
    } catch (e) {
      toast(`启动失败: ${e.message}`);
    }
  };

  byId('assistantRunBtn').onclick = async () => {
    try {
      await saveAssistantSettings();
      const payload = await api('/api/assistant/trigger-capture', { method: 'POST', body: '{}' });
      if (!payload.ok) throw new Error(payload.error || 'assistant run failed');
      toast('截图问答已触发，请查看悬浮窗');
    } catch (e) {
      toast(`执行失败: ${e.message}`);
    }
  };
}
