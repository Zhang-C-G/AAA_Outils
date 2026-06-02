export const DEFAULT_PROMPT = '编程题：直接给完整可运行代码，并在代码框中输出；随后对核心思路做简短说明。选择题：先写15字以内题目总结，再直接给答案。';
export const OPACITY_LEVELS = [20, 50, 75, 100];
export const DEFAULT_OVERLAY_BALL_COLOR = '#111111';

export function assistantDefaults() {
  return {
    enabled: 1,
    api_endpoint: 'https://ark.cn-beijing.volces.com/api/v3/responses',
    api_key: '',
    has_api_key: 0,
    xunfei_app_id: '',
    xunfei_api_key: '',
    has_xunfei_api_key: 0,
    xunfei_api_secret: '',
    has_xunfei_api_secret: 0,
    model: 'doubao-seed-2-0-lite-260215',
    model_options: [
      { id: 'doubao-seed-2-0-lite-260215', name: 'Doubao Seed 2.0 Lite (Vision)', enabled: 1 },
      { id: 'doubao-seed-2-0-pro-260215', name: 'Doubao Seed 2.0 Pro (Vision)', enabled: 1 },
      { id: 'doubao-seed-2-0-mini-260215', name: 'Doubao Seed 2.0 Mini (ASR Fast | 语音识别特别快)', enabled: 1 }
    ],
    voice_model: 'local_windows_default',
    voice_model_options: [
      { id: 'local_windows_default', name: '本地默认语音识别', enabled: 1 },
      { id: 'xunfei_websocket_asr', name: '讯飞 WebSocket 语音识别', enabled: 1 }
    ],
    voice_model_enabled: 0,
    voice_model_api_key: '',
    has_voice_model_api_key: 0,
    prompt: DEFAULT_PROMPT,
    personal_profile: '',
    active_template: 'default_template',
    templates: [{ name: 'default_template', prompt: DEFAULT_PROMPT }],
    overlay_opacity: 75,
    overlay_ball_color: DEFAULT_OVERLAY_BALL_COLOR,
    enhanced_capture_mode: 0,
    disable_copy: 1,
    voice_input_enabled: 0,
    voice_context_enabled: 0,
    voice_context_rounds: 3,
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

export function normalizeAssistantOpacity(value, fallback = 75) {
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

export function normalizeAssistantColor(value, fallback = DEFAULT_OVERLAY_BALL_COLOR) {
  const raw = String(value || '').trim();
  if (/^#[0-9a-f]{6}$/i.test(raw)) return raw.toUpperCase();
  if (/^[0-9a-f]{6}$/i.test(raw)) return `#${raw.toUpperCase()}`;
  return fallback.toUpperCase();
}

export function normalizeAssistantModelOptions(options, fallbackOptions = assistantDefaults().model_options) {
  const src = Array.isArray(options) ? options : [];
  const out = [];
  const seen = new Set();
  for (const model of src) {
    const id = String(model?.id || '').trim();
    if (!id) continue;
    const key = id.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({
      id,
      name: String(model?.name || id).trim() || id,
      enabled: Number(model?.enabled ?? 1) === 0 ? 0 : 1
    });
  }
  return out.length ? out : fallbackOptions;
}

export function normalizeAssistantVoiceModelOptions(options, fallbackOptions = assistantDefaults().voice_model_options) {
  return normalizeAssistantModelOptions(options, fallbackOptions);
}

export function isBrokenAssistantPrompt(text) {
  const t = String(text || '').trim();
  if (!t) return true;
  if (/^[?？]+$/.test(t)) return true;
  if (t.includes('???') || t.includes('？？？')) return true;
  return false;
}

export function normalizeAssistantTemplates(inputTemplates, fallbackPrompt = DEFAULT_PROMPT) {
  const list = [];
  const seen = new Set();
  const source = Array.isArray(inputTemplates) ? inputTemplates : [];

  for (const template of source) {
    const name = String(template?.name || '').trim();
    let prompt = String(template?.prompt || '').trim();
    if (!name) continue;
    const key = name.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    if (isBrokenAssistantPrompt(prompt)) prompt = fallbackPrompt;
    list.push({ name, prompt });
  }

  if (!list.length) {
    list.push({ name: 'default_template', prompt: fallbackPrompt });
  }
  return list;
}

export function ensureAssistantActiveTemplate(settings, fallback = assistantDefaults()) {
  if (!Array.isArray(settings.templates) || !settings.templates.length) {
    settings.templates = [...fallback.templates];
  }

  const active = String(settings.active_template || '').trim();
  const found = settings.templates.find((template) => template.name === active);
  settings.active_template = found ? found.name : settings.templates[0].name;

  const current = settings.templates.find((template) => template.name === settings.active_template);
  settings.prompt = current?.prompt || fallback.prompt;
  return settings;
}
