import { t } from './app-i18n.js';

const DEFAULT_THEME = Object.freeze({
  mode: 'solid',
  primary: '#111111',
  secondary: '#2A2A2A',
  accent: '#F3F3F3'
});

export const THEME_PRESETS = Object.freeze([
  { id: 'mono', label: '黑白', mode: 'solid', primary: '#111111', secondary: '#2A2A2A', accent: '#F3F3F3' },
  { id: 'slate', label: '石墨', mode: 'solid', primary: '#1A2028', secondary: '#2C3542', accent: '#DDE7F2' },
  { id: 'aurora', label: '极光', mode: 'gradient', primary: '#17324A', secondary: '#275C54', accent: '#E7FFF7' },
  { id: 'ember', label: '余烬', mode: 'gradient', primary: '#3E201B', secondary: '#7B3E24', accent: '#FFF1E8' }
]);

function normalizeHex(value, fallback = '#111111') {
  const raw = String(value || '').trim();
  if (/^#[0-9a-f]{6}$/i.test(raw)) return raw.toUpperCase();
  if (/^[0-9a-f]{6}$/i.test(raw)) return `#${raw.toUpperCase()}`;
  return fallback.toUpperCase();
}

function normalizeMode(value) {
  return String(value || '').trim().toLowerCase() === 'gradient' ? 'gradient' : 'solid';
}

export function normalizeThemeSettings(input = {}) {
  const mode = normalizeMode(input.mode);
  const primary = normalizeHex(input.primary, DEFAULT_THEME.primary);
  const secondary = normalizeHex(input.secondary, DEFAULT_THEME.secondary);
  const accent = normalizeHex(input.accent, DEFAULT_THEME.accent);
  return { mode, primary, secondary, accent };
}

export function applyShellTheme(input = {}) {
  const theme = normalizeThemeSettings(input);
  const root = document.documentElement;
  const surfaceGlow = theme.mode === 'gradient'
    ? `radial-gradient(circle at 12% 12%, ${withAlpha(theme.secondary, 0.34)}, transparent 42%), linear-gradient(145deg, ${theme.primary}, ${theme.secondary})`
    : `radial-gradient(circle at 14% 14%, ${mix(theme.primary, '#FFFFFF', 0.10)}, ${mix(theme.primary, '#000000', 0.28)} 58%)`;
  const panelFill = theme.mode === 'gradient'
    ? `linear-gradient(180deg, ${withAlpha(theme.secondary, 0.14)}, ${withAlpha(theme.primary, 0.08)})`
    : `linear-gradient(180deg, rgba(255,255,255,.04), rgba(255,255,255,.01))`;

  root.style.setProperty('--bg', theme.primary);
  root.style.setProperty('--bg2', theme.secondary);
  root.style.setProperty('--line', mix(theme.primary, '#FFFFFF', 0.18));
  root.style.setProperty('--text', '#F5F5F5');
  root.style.setProperty('--muted', mix(theme.accent, '#111111', 0.38));
  root.style.setProperty('--body-bg', surfaceGlow);
  root.style.setProperty('--panel-fill', panelFill);
  root.style.setProperty('--btn-bg', withAlpha(theme.secondary, 0.42));
  root.style.setProperty('--btn-border', withAlpha(theme.accent, 0.18));
  root.style.setProperty('--btn-hover-border', withAlpha(theme.accent, 0.38));
  root.style.setProperty('--chip-bg', withAlpha(theme.primary, 0.54));
  root.style.setProperty('--chip-active-bg', theme.accent);
  root.style.setProperty('--chip-active-text', '#111111');
  root.style.setProperty('--theme-accent', theme.accent);
  return theme;
}

function parseHex(color) {
  const hex = normalizeHex(color, '#111111');
  return {
    r: Number.parseInt(hex.slice(1, 3), 16),
    g: Number.parseInt(hex.slice(3, 5), 16),
    b: Number.parseInt(hex.slice(5, 7), 16)
  };
}

function toHexChannel(value) {
  return Math.max(0, Math.min(255, Math.round(value))).toString(16).padStart(2, '0').toUpperCase();
}

function mix(colorA, colorB, ratio = 0.5) {
  const a = parseHex(colorA);
  const b = parseHex(colorB);
  const t = Math.max(0, Math.min(1, Number(ratio) || 0));
  return `#${toHexChannel(a.r + (b.r - a.r) * t)}${toHexChannel(a.g + (b.g - a.g) * t)}${toHexChannel(a.b + (b.b - a.b) * t)}`;
}

function withAlpha(color, alpha = 1) {
  const { r, g, b } = parseHex(color);
  const a = Math.max(0, Math.min(1, Number(alpha) || 0));
  return `rgba(${r}, ${g}, ${b}, ${a})`;
}

function createPresetButton(preset, onSelect) {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'shell-theme-preset';
  button.dataset.presetId = preset.id;
  button.innerHTML = `
    <span class="shell-theme-preset-swatch"></span>
    <span class="shell-theme-preset-label">${t(preset.label)}</span>
  `;
  const swatch = button.querySelector('.shell-theme-preset-swatch');
  swatch.style.background = preset.mode === 'gradient'
    ? `linear-gradient(135deg, ${preset.primary}, ${preset.secondary})`
    : preset.primary;
  button.onclick = () => onSelect(preset);
  return button;
}

export function mountThemePicker(host, options = {}) {
  if (!host) return null;

  const onChange = typeof options.onChange === 'function' ? options.onChange : () => {};
  const onLanguageChange = typeof options.onLanguageChange === 'function' ? options.onLanguageChange : () => {};
  const initialTheme = normalizeThemeSettings(options.value || DEFAULT_THEME);
  const initialLanguage = String(options.language || 'fr').trim().toLowerCase() === 'zh' ? 'zh' : 'fr';
  let current = { ...initialTheme };

  host.innerHTML = `
    <div class="shell-theme-panel">
      <div class="shell-theme-panel-head">
        <div>
          <strong>${t('主题设置')}</strong>
          <span>${t('预设和色轮修改后立即生效')}</span>
        </div>
        <button type="button" class="btn ghost shell-theme-close">${t('关闭')}</button>
      </div>
      <label class="assistant-topmost-field">
        <span>${t('语言')}</span>
        <select id="shellThemeLanguage">
          <option value="fr">${t('法语')}</option>
          <option value="zh">${t('中文')}</option>
        </select>
      </label>
      <div class="shell-theme-preview" id="shellThemePreview"></div>
      <div class="shell-theme-segment">
        <button type="button" class="shell-theme-segment-btn" data-mode="solid">${t('纯色')}</button>
        <button type="button" class="shell-theme-segment-btn" data-mode="gradient">${t('渐变')}</button>
      </div>
      <div class="shell-theme-preset-grid" id="shellThemePresetGrid"></div>
      <div class="shell-theme-fields">
        <label class="assistant-color-field">
          <span>${t('主色')}</span>
          <div class="assistant-color-picker-row">
            <input id="shellThemePrimary" type="color" />
            <input id="shellThemePrimaryText" type="text" readonly />
          </div>
        </label>
        <label class="assistant-color-field">
          <span>${t('副色')}</span>
          <div class="assistant-color-picker-row">
            <input id="shellThemeSecondary" type="color" />
            <input id="shellThemeSecondaryText" type="text" readonly />
          </div>
        </label>
      </div>
    </div>
  `;

  const preview = host.querySelector('#shellThemePreview');
  const presetGrid = host.querySelector('#shellThemePresetGrid');
  const primary = host.querySelector('#shellThemePrimary');
  const primaryText = host.querySelector('#shellThemePrimaryText');
  const secondary = host.querySelector('#shellThemeSecondary');
  const secondaryText = host.querySelector('#shellThemeSecondaryText');
  const language = host.querySelector('#shellThemeLanguage');
  const segmentButtons = Array.from(host.querySelectorAll('.shell-theme-segment-btn'));

  function syncUi() {
    current = normalizeThemeSettings(current);
    primary.value = current.primary;
    primaryText.value = current.primary;
    secondary.value = current.secondary;
    secondaryText.value = current.secondary;
    secondary.disabled = current.mode !== 'gradient';
    segmentButtons.forEach((btn) => btn.classList.toggle('active', btn.dataset.mode === current.mode));
    preview.style.background = current.mode === 'gradient'
      ? `linear-gradient(135deg, ${current.primary}, ${current.secondary})`
      : current.primary;
    host.querySelectorAll('.shell-theme-preset').forEach((btn) => {
      const preset = THEME_PRESETS.find((item) => item.id === btn.dataset.presetId);
      if (!preset) {
        btn.classList.remove('active');
        return;
      }
      const normalizedPreset = normalizeThemeSettings(preset);
      const isActive = normalizedPreset.mode === current.mode
        && normalizedPreset.primary === current.primary
        && normalizedPreset.secondary === current.secondary;
      btn.classList.toggle('active', isActive);
    });
  }

  function emitChange() {
    current = normalizeThemeSettings(current);
    syncUi();
    onChange({ ...current, live: true });
  }

  for (const preset of THEME_PRESETS) {
    presetGrid.appendChild(createPresetButton(preset, (nextPreset) => {
      current = normalizeThemeSettings(nextPreset);
      emitChange();
    }));
  }

  segmentButtons.forEach((btn) => {
    btn.onclick = () => {
      current.mode = btn.dataset.mode === 'gradient' ? 'gradient' : 'solid';
      emitChange();
    };
  });

  primary.oninput = () => {
    current.primary = normalizeHex(primary.value, current.primary);
    emitChange();
  };
  secondary.oninput = () => {
    current.secondary = normalizeHex(secondary.value, current.secondary);
    emitChange();
  };
  language.value = initialLanguage;
  language.onchange = () => onLanguageChange(language.value);

  host.querySelector('.shell-theme-close').onclick = () => {
    host.classList.add('hidden');
  };

  syncUi();
  return {
    getValue: () => ({ ...current }),
    setValue(nextTheme) {
      current = normalizeThemeSettings(nextTheme);
      syncUi();
    },
    setLanguage(nextLanguage) {
      language.value = String(nextLanguage || 'fr').trim().toLowerCase() === 'zh' ? 'zh' : 'fr';
    },
    open() {
      host.classList.remove('hidden');
      syncUi();
    },
    close() {
      host.classList.add('hidden');
    }
  };
}
