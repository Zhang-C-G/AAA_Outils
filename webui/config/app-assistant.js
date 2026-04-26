import { state, byId, api, toast } from './app-common.js';
import { enhanceTopLayerSelect, refreshTopLayerSelect } from './top-layer-select.js';

const API_KEY_MASK = '****************';
const DEFAULT_PROMPT = '\u7f16\u7a0b\u9898\uff1a\u76f4\u63a5\u7ed9\u5b8c\u6574\u53ef\u8fd0\u884c\u4ee3\u7801\uff0c\u5e76\u5728\u4ee3\u7801\u6846\u4e2d\u8f93\u51fa\uff1b\u968f\u540e\u5bf9\u6838\u5fc3\u601d\u8def\u505a\u7b80\u77ed\u8bf4\u660e\u3002\u9009\u62e9\u9898\uff1a\u5148\u519915\u5b57\u4ee5\u5185\u9898\u76ee\u603b\u7ed3\uff0c\u518d\u76f4\u63a5\u7ed9\u7b54\u6848\u3002';
const OPACITY_LEVELS = [20, 50, 75, 100];
const ADVANCED_VISIBLE_STORAGE_KEY = 'assistant_advanced_visible';

let assistantAutoSaveTimer = 0;
let assistantAutoSaveInFlight = false;
let assistantAutoSaveQueued = false;
let assistantAdvancedVisible = false;
let assistantVoiceDevicesLoaded = false;

function loadAssistantAdvancedVisible() {
  try {
    return window.localStorage.getItem(ADVANCED_VISIBLE_STORAGE_KEY) === '1';
  } catch {
    return false;
  }
}

function saveAssistantAdvancedVisible(visible) {
  try {
    window.localStorage.setItem(ADVANCED_VISIBLE_STORAGE_KEY, visible ? '1' : '0');
  } catch {
    // Ignore storage failures and keep UI usable.
  }
}

function normalizeOpacity(value, fallback = 75) {
  const raw = Number(value);
  const target = Number.isFinite(raw) ? raw : fallback;
  let best = OPACITY_LEVELS[0];
  let diff = Math.abs(target - best);
  for (const level of OPACITY_LEVELS) {
    const nextDiff = Math.abs(target - level);
    if (nextDiff < diff || (nextDiff === diff && level > best)) {
      best = level;
      diff = nextDiff;
    }
  }
  return best;
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
      { id: 'doubao-seed-2-0-pro-260215', name: 'Doubao Seed 2.0 Pro (Vision)', enabled: 1 },
      { id: 'doubao-seed-2-0-mini-260215', name: 'Doubao Seed 2.0 Mini (ASR Fast | 语音识别特别快)', enabled: 1 }
    ],
    voice_model: 'xunfei_websocket_asr',
    voice_model_options: [
      { id: 'xunfei_websocket_asr', name: '讯飞 WebSocket 语音识别', enabled: 1 }
    ],
    voice_model_enabled: 0,
    voice_model_api_key: '',
    has_voice_model_api_key: 0,
    prompt: DEFAULT_PROMPT,
    active_template: 'default_template',
    templates: [{ name: 'default_template', prompt: DEFAULT_PROMPT }],
    overlay_opacity: 75,
    enhanced_capture_mode: 0,
    disable_copy: 1,
    voice_input_enabled: 0,
    voice_input_device_id: '',
    voice_input_devices: [],
    rate_limit_enabled: 1,
    rate_limit_per_hour: 100,
    capture_dir: '',
    benchmark: {
      image_url: '',
      image_name: '',
      image_kb: 0,
      note: '',
      last_result: null,
      history: []
    }
  };
}

function setAssistantAdvancedVisible(visible) {
  assistantAdvancedVisible = !!visible;
  saveAssistantAdvancedVisible(assistantAdvancedVisible);
  const body = byId('assistantAdvancedBody');
  const btn = byId('assistantAdvancedToggleBtn');
  const text = byId('assistantAdvancedToggleText');
  const section = byId('assistantAdvancedSection');

  if (body) {
    body.classList.toggle('hidden', !assistantAdvancedVisible);
  }
  if (section) {
    section.classList.toggle('hidden', !assistantAdvancedVisible);
  }
  if (btn) {
    btn.classList.toggle('active', assistantAdvancedVisible);
    btn.setAttribute('aria-pressed', assistantAdvancedVisible ? 'true' : 'false');
  }
  if (text) {
    text.textContent = assistantAdvancedVisible
      ? '\u9ad8\u7ea7\u8bbe\u7f6e\u5df2\u5f00\u542f'
      : '\u9ad8\u7ea7\u8bbe\u7f6e\u5df2\u5173\u95ed';
  }
}

function hotkeyToFriendly(hk) {
  const raw = String(hk || '').trim();
  if (!raw) return '(\u672a\u8bbe\u7f6e)';

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
  const hkOpen = hotkeyToFriendly(state.hotkeys?.assistant_capture || '!+A');
  const hkRun = hotkeyToFriendly(state.hotkeys?.assistant_capture_now || 'F1');
  const hkVoice = hotkeyToFriendly(state.hotkeys?.assistant_voice_input || 'F3');
  const hkUp = hotkeyToFriendly(state.hotkeys?.assistant_overlay_up || '!Up');
  const hkDown = hotkeyToFriendly(state.hotkeys?.assistant_overlay_down || '!Down');
  el.textContent = `\u5feb\u6377\u952e\u8bf4\u660e\uff08\u81ea\u52a8\u540c\u6b65\u914d\u7f6e\uff09\uff1a\u542f\u52a8\u60ac\u6d6e\u7a97 ${hkOpen}\uff1b\u622a\u56fe\u5e76\u95ee\u7b54 ${hkRun}\uff1b\u6309\u4f4f\u8bed\u97f3\u8f93\u5165 ${hkVoice}\uff1b\u7b54\u6848\u4e0a\u6eda ${hkUp}\uff1b\u7b54\u6848\u4e0b\u6eda ${hkDown}\u3002`;
}

function setAssistantOpacityChoice(value) {
  const normalized = normalizeOpacity(value, state.assistant.overlay_opacity);
  state.assistant.overlay_opacity = normalized;
  document.querySelectorAll('.assistant-opacity-choice').forEach((btn) => {
    const current = Number(btn.dataset.value || 0);
    btn.classList.toggle('active', current === normalized);
  });
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
    // Auto-save failures should not block editing.
  } finally {
    assistantAutoSaveInFlight = false;
    if (assistantAutoSaveQueued) {
      assistantAutoSaveQueued = false;
      scheduleAssistantAutoSave(true);
    }
  }
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
  return out.length ? out : defaults().model_options;
}

function normalizeVoiceModelOptions(options) {
  const list = normalizeModelOptions(options);
  return list.length ? list : defaults().voice_model_options;
}

function renderSelectOptions(selectId, options, selectedValue, fallbackValue) {
  const sel = byId(selectId);
  sel.innerHTML = '';

  const list = Array.isArray(options) ? options : [];
  for (const item of list) {
    if (Number(item.enabled || 0) === 0) continue;
    const opt = document.createElement('option');
    opt.value = item.id;
    opt.textContent = `${item.name} (${item.id})`;
    sel.appendChild(opt);
  }

  const hasSelected = Array.from(sel.options).some((o) => o.value === selectedValue);
  sel.value = hasSelected ? selectedValue : (sel.options[0]?.value || fallbackValue);
  return sel.value;
}

function renderModelOptions(selectedModel) {
  const list = normalizeModelOptions(state.assistant.model_options);
  state.assistant.model = renderSelectOptions('assistantModel', list, selectedModel, 'doubao-seed-2-0-lite-260215');
}

function renderVoiceModelOptions(selectedModel) {
  const list = normalizeVoiceModelOptions(state.assistant.voice_model_options);
  state.assistant.voice_model = renderSelectOptions('assistantVoiceModel', list, selectedModel, 'xunfei_websocket_asr');
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

function getVoiceDeviceSelect() {
  return byId('assistantVoiceDevice');
}

function buildVoiceDeviceLabel(device, index) {
  const label = String(device?.label || '').trim();
  if (label) {
    return Number(device?.is_default || 0) !== 0 ? `${label}（当前系统默认）` : label;
  }
  return Number(device?.is_default || 0) !== 0
    ? `麦克风 ${index + 1}（当前系统默认）`
    : `麦克风 ${index + 1}`;
}

function renderVoiceDeviceOptions() {
  const select = getVoiceDeviceSelect();
  if (!select) return;

  const incomingDevices = Array.isArray(state.assistant.voice_input_devices)
    ? state.assistant.voice_input_devices
    : [];
  const devices = incomingDevices
    .map((item, index) => ({
      id: String(item?.id || '').trim(),
      label: buildVoiceDeviceLabel(item, index)
    }))
    .filter((item) => item.id !== '');

  const currentValue = String(state.assistant.voice_input_device_id || '').trim();
  select.innerHTML = '';

  const defaultOpt = document.createElement('option');
  defaultOpt.value = '';
  defaultOpt.textContent = devices.length
    ? '系统默认麦克风'
    : '系统默认麦克风（当前未枚举到独立设备）';
  select.appendChild(defaultOpt);

  for (const device of devices) {
    const opt = document.createElement('option');
    opt.value = device.id;
    opt.textContent = device.label;
    select.appendChild(opt);
  }

  const hasCurrent = Array.from(select.options).some((opt) => opt.value === currentValue);
  select.value = hasCurrent ? currentValue : '';
  state.assistant.voice_input_device_id = select.value;
  refreshTopLayerSelect(select);
}

async function refreshAssistantVoiceDevices() {
  const select = getVoiceDeviceSelect();
  if (!select) return;

  let devices = [];
  try {
    const payload = await api('/api/assistant/audio-input-devices');
    const rawDevices = Array.isArray(payload?.devices) ? payload.devices : [];
    devices = rawDevices
      .map((item, index) => ({
        id: String(item?.id || '').trim(),
        label: buildVoiceDeviceLabel(item, index),
        is_default: Number(item?.is_default || 0) !== 0
      }))
      .filter((item) => item.id !== '');
  } catch (error) {
    toast(`麦克风列表读取失败: ${error.message}`, { type: 'warning', dedupeKey: 'assistant-voice-devices-failed' });
  }

  state.assistant.voice_input_devices = devices;
  assistantVoiceDevicesLoaded = true;
  renderVoiceDeviceOptions();
}

function syncCurrentTemplateFromUi() {
  const currentName = state.assistant.active_template;
  const idx = state.assistant.templates.findIndex((t) => t.name === currentName);
  if (idx < 0) return;

  let nextName = String(byId('assistantTemplateName').value || '').trim();
  if (!nextName) nextName = currentName;

  const duplicated = state.assistant.templates.find((t, i) => i !== idx && t.name.toLowerCase() === nextName.toLowerCase());
  if (duplicated) {
    toast(`\u6a21\u677f\u540d\u91cd\u590d\uff1a${nextName}`);
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
  state.assistant.voice_model_options = normalizeVoiceModelOptions(
    incoming.voice_model_options || state.assistant.voice_model_options
  );

  if (isBrokenPrompt(state.assistant.prompt)) {
    state.assistant.prompt = fallback.prompt;
  }

  state.assistant.templates = normalizeTemplates(incoming.templates || state.assistant.templates, fallback.prompt);
  state.assistant.overlay_opacity = normalizeOpacity(incoming.overlay_opacity ?? state.assistant.overlay_opacity, fallback.overlay_opacity);
  state.assistant.enhanced_capture_mode = Number(incoming.enhanced_capture_mode ?? state.assistant.enhanced_capture_mode ?? 0) === 0 ? 0 : 1;
  state.assistant.voice_input_enabled = Number(incoming.voice_input_enabled ?? state.assistant.voice_input_enabled ?? 0) === 0 ? 0 : 1;
  state.assistant.voice_input_device_id = String(incoming.voice_input_device_id ?? state.assistant.voice_input_device_id ?? '').trim();
  state.assistant.voice_input_devices = Array.isArray(incoming.voice_input_devices)
    ? incoming.voice_input_devices
    : (Array.isArray(state.assistant.voice_input_devices) ? state.assistant.voice_input_devices : []);
  state.assistant.enabled = 1;
  ensureActiveTemplate();

  renderModelOptions(state.assistant.model || 'doubao-seed-2-0-lite-260215');
  renderVoiceModelOptions(state.assistant.voice_model || 'xunfei_websocket_asr');
  byId('assistantApiKey').value = Number(state.assistant.has_api_key || 0) !== 0 ? API_KEY_MASK : '';
  byId('assistantVoiceApiKey').value = Number(state.assistant.has_voice_model_api_key || 0) !== 0 ? API_KEY_MASK : '';
  byId('assistantDisableCopy').checked = Number(state.assistant.disable_copy ?? 1) !== 0;
  byId('assistantEnhancedCaptureMode').checked = Number(state.assistant.enhanced_capture_mode ?? 0) !== 0;
  byId('assistantVoiceEnabled').checked = Number(state.assistant.voice_input_enabled ?? 0) !== 0;
  byId('assistantVoiceModelEnabled').checked = Number(state.assistant.voice_model_enabled ?? 0) !== 0;
  byId('assistantApiKey').placeholder = Number(state.assistant.has_api_key || 0) !== 0
    ? '\u5df2\u4fdd\u5b58\u5bc6\u94a5\uff08\u4fdd\u6301\u661f\u53f7\u8868\u793a\u4e0d\u53d8\uff09'
    : '\u8bf7\u8f93\u5165 API Key';
  byId('assistantVoiceApiKey').placeholder = Number(state.assistant.has_voice_model_api_key || 0) !== 0
    ? '\u5df2\u4fdd\u5b58\u8bed\u97f3\u6a21\u578b\u5bc6\u94a5\uff08\u4fdd\u6301\u661f\u53f7\u8868\u793a\u4e0d\u53d8\uff09'
    : '\u8bf7\u8f93\u5165\u8bed\u97f3\u6a21\u578b API';
  byId('assistantRateEnabled').checked = Number(state.assistant.rate_limit_enabled || 0) !== 0;
  byId('assistantRatePerHour').value = Math.max(1, Number(state.assistant.rate_limit_per_hour || 100));
  byId('assistantCaptureDir').value = state.assistant.capture_dir || '';

  renderTemplateControls();
  renderHotkeyExplain();
  setAssistantOpacityChoice(state.assistant.overlay_opacity);
  renderVoiceDeviceOptions();
  setAssistantAdvancedVisible(loadAssistantAdvancedVisible());
  if (!assistantVoiceDevicesLoaded) {
    void refreshAssistantVoiceDevices();
  }
}

function readAssistantFromUi() {
  syncCurrentTemplateFromUi();

  state.assistant.enabled = 1;
  state.assistant.overlay_opacity = normalizeOpacity(state.assistant.overlay_opacity, 75);
  state.assistant.model = (byId('assistantModel').value || '').trim() || 'doubao-seed-2-0-lite-260215';
  state.assistant.voice_model = (byId('assistantVoiceModel').value || '').trim() || 'xunfei_websocket_asr';
  state.assistant.enhanced_capture_mode = byId('assistantEnhancedCaptureMode').checked ? 1 : 0;
  state.assistant.disable_copy = byId('assistantDisableCopy').checked ? 1 : 0;
  state.assistant.voice_input_enabled = byId('assistantVoiceEnabled').checked ? 1 : 0;
  state.assistant.voice_model_enabled = byId('assistantVoiceModelEnabled').checked ? 1 : 0;
  state.assistant.voice_input_device_id = String(getVoiceDeviceSelect()?.value || '').trim();
  state.assistant.rate_limit_enabled = byId('assistantRateEnabled').checked ? 1 : 0;
  state.assistant.rate_limit_per_hour = Math.min(10000, Math.max(1, Math.round(Number(byId('assistantRatePerHour').value || 100))));
  state.assistant.api_endpoint = (state.assistant.api_endpoint || defaults().api_endpoint).trim() || defaults().api_endpoint;

  const inputKey = String(byId('assistantApiKey').value || '').trim();
  if (inputKey && inputKey !== API_KEY_MASK) {
    state.assistant.api_key = inputKey;
    state.assistant.keep_api_key = 0;
  } else {
    state.assistant.api_key = '';
    state.assistant.keep_api_key = Number(state.assistant.has_api_key || 0) !== 0 ? 1 : 0;
  }

  const inputVoiceKey = String(byId('assistantVoiceApiKey').value || '').trim();
  if (inputVoiceKey && inputVoiceKey !== API_KEY_MASK) {
    state.assistant.voice_model_api_key = inputVoiceKey;
    state.assistant.keep_voice_model_api_key = 0;
  } else {
    state.assistant.voice_model_api_key = '';
    state.assistant.keep_voice_model_api_key = Number(state.assistant.has_voice_model_api_key || 0) !== 0 ? 1 : 0;
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
  state.assistant.voice_model_api_key = '';
  state.assistant.keep_voice_model_api_key = 0;
  applyAssistantState({ assistant: state.assistant });
  if (!silent) {
    toast('\u52a9\u624b\u8bbe\u7f6e\u5df2\u4fdd\u5b58');
  }
}

async function openAssistantFolder() {
  const payload = await api('/api/assistant/open-folder', { method: 'POST', body: '{}' });
  if (!payload.ok) throw new Error(payload.error || 'open folder failed');
}

async function pickAssistantFolder() {
  const payload = await api('/api/assistant/pick-folder', { method: 'POST', body: '{}' });
  if (payload.cancelled) return;
  if (!payload.ok) throw new Error(payload.error || 'pick folder failed');

  const settings = payload.settings || payload.state?.settings || null;
  if (settings) {
    state.assistant = { ...state.assistant, ...settings };
    applyAssistantState({ assistant: state.assistant });
  } else if (payload.path) {
    state.assistant.capture_dir = String(payload.path || '');
    byId('assistantCaptureDir').value = state.assistant.capture_dir;
  }

  if (payload.path) {
    toast(`截图目录已更新: ${payload.path}`);
  }
}

export function initAssistantHandlers() {
  enhanceTopLayerSelect('assistantVoiceModel');
  enhanceTopLayerSelect('assistantVoiceDevice', { placeholder: '系统默认麦克风' });

  const advancedToggleBtn = byId('assistantAdvancedToggleBtn');
  if (advancedToggleBtn) {
    advancedToggleBtn.onclick = () => {
      setAssistantAdvancedVisible(!assistantAdvancedVisible);
    };
  }

  const templateSelect = byId('assistantTemplateSelect');
  if (templateSelect) {
    templateSelect.onchange = () => {
      syncCurrentTemplateFromUi();
      state.assistant.active_template = byId('assistantTemplateSelect').value;
      renderTemplateControls();
      scheduleAssistantAutoSave();
    };
  }

  const templateName = byId('assistantTemplateName');
  if (templateName) {
    templateName.onchange = () => {
      syncCurrentTemplateFromUi();
      renderTemplateControls();
      scheduleAssistantAutoSave();
    };
  }

  const prompt = byId('assistantPrompt');
  if (prompt) {
    prompt.oninput = () => {
      syncCurrentTemplateFromUi();
      scheduleAssistantAutoSave();
    };
  }

  const addTplBtn = byId('assistantAddTplBtn');
  if (addTplBtn) {
    addTplBtn.onclick = () => {
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
  }

  const deleteTplBtn = byId('assistantDeleteTplBtn');
  if (deleteTplBtn) {
    deleteTplBtn.onclick = () => {
      syncCurrentTemplateFromUi();
      if (state.assistant.templates.length <= 1) {
        toast('\u81f3\u5c11\u4fdd\u7559\u4e00\u4e2a\u6a21\u677f');
        return;
      }
      const name = state.assistant.active_template;
      if (!confirm(`\u786e\u8ba4\u5220\u9664\u6a21\u677f\u3010${name}\u3011\u5417\uff1f`)) return;
      state.assistant.templates = state.assistant.templates.filter((t) => t.name !== name);
      state.assistant.active_template = state.assistant.templates[0].name;
      renderTemplateControls();
      scheduleAssistantAutoSave(true);
    };
  }

  document.querySelectorAll('.assistant-opacity-choice').forEach((btn) => {
    btn.onclick = () => {
      setAssistantOpacityChoice(Number(btn.dataset.value || 100));
      scheduleAssistantAutoSave(true);
    };
  });

  const saveBtn = byId('assistantSaveBtn');
  if (saveBtn) {
    saveBtn.onclick = () => saveAssistantSettings().catch((e) => toast(`\u4fdd\u5b58\u5931\u8d25: ${e.message}`));
  }
  const model = byId('assistantModel');
  if (model) model.onchange = () => scheduleAssistantAutoSave(true);
  const voiceModel = byId('assistantVoiceModel');
  if (voiceModel) voiceModel.onchange = () => scheduleAssistantAutoSave(true);
  const disableCopy = byId('assistantDisableCopy');
  if (disableCopy) disableCopy.onchange = () => scheduleAssistantAutoSave(true);
  const enhancedCaptureMode = byId('assistantEnhancedCaptureMode');
  if (enhancedCaptureMode) enhancedCaptureMode.onchange = () => scheduleAssistantAutoSave(true);
  const voiceEnabled = byId('assistantVoiceEnabled');
  if (voiceEnabled) voiceEnabled.onchange = () => scheduleAssistantAutoSave(true);
  const voiceModelEnabled = byId('assistantVoiceModelEnabled');
  if (voiceModelEnabled) voiceModelEnabled.onchange = () => scheduleAssistantAutoSave(true);
  const voiceDevice = getVoiceDeviceSelect();
  if (voiceDevice) {
    voiceDevice.onchange = () => scheduleAssistantAutoSave(true);
    void refreshAssistantVoiceDevices();
  }
  const apiKey = byId('assistantApiKey');
  if (apiKey) apiKey.onchange = () => scheduleAssistantAutoSave(true);
  const voiceApiKey = byId('assistantVoiceApiKey');
  if (voiceApiKey) voiceApiKey.onchange = () => scheduleAssistantAutoSave(true);
  const rateEnabled = byId('assistantRateEnabled');
  if (rateEnabled) rateEnabled.onchange = () => scheduleAssistantAutoSave(true);
  const ratePerHour = byId('assistantRatePerHour');
  if (ratePerHour) ratePerHour.oninput = () => scheduleAssistantAutoSave();

  const showOverlayBtn = byId('assistantShowOverlayBtn');
  if (showOverlayBtn) {
    showOverlayBtn.onclick = async () => {
      try {
        await saveAssistantSettings();
        const payload = await api('/api/assistant/show-overlay', { method: 'POST', body: '{}' });
        if (!payload.ok) throw new Error(payload.error || 'show overlay failed');
        toast('\u60ac\u6d6e\u7a97\u542f\u52a8\u6307\u4ee4\u5df2\u53d1\u9001');
      } catch (e) {
        toast(`\u542f\u52a8\u5931\u8d25: ${e.message}`);
      }
    };
  }

  const runBtn = byId('assistantRunBtn');
  if (runBtn) {
    runBtn.onclick = async () => {
      try {
        await saveAssistantSettings();
        const payload = await api('/api/assistant/trigger-capture', { method: 'POST', body: '{}' });
        if (!payload.ok) throw new Error(payload.error || 'assistant run failed');
        toast('\u622a\u56fe\u95ee\u7b54\u5df2\u89e6\u53d1\uff0c\u8bf7\u67e5\u770b\u60ac\u6d6e\u7a97');
      } catch (e) {
        toast(`\u6267\u884c\u5931\u8d25: ${e.message}`);
      }
    };
  }

  const openFolderBtn = byId('assistantOpenFolderBtn');
  if (openFolderBtn) {
    openFolderBtn.onclick = async () => {
      try {
        await openAssistantFolder();
      } catch (e) {
        toast(`\u6253\u5f00\u5931\u8d25: ${e.message}`);
      }
    };
  }

  const openFolderInlineBtn = byId('assistantOpenFolderInlineBtn');
  if (openFolderInlineBtn) {
    openFolderInlineBtn.onclick = async () => {
      try {
        await openAssistantFolder();
      } catch (e) {
        toast(`\u6253\u5f00\u5931\u8d25: ${e.message}`);
      }
    };
  }

  const pickFolderBtn = byId('assistantPickFolderBtn');
  if (pickFolderBtn) {
    pickFolderBtn.onclick = async () => {
      try {
        await pickAssistantFolder();
      } catch (e) {
        toast(`修改目录失败: ${e.message}`);
      }
    };
  }
}
