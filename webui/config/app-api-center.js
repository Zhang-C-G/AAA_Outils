import { state, byId, api, toast, escapeHtml } from './app-common.js';

const UNKNOWN_METRIC = '?';
const MASKED_KEY = '****************';
const UNCONFIGURED_KEY = '未配置';
const VOLCENGINE_CONSOLE_URL = 'https://www.volcengine.com/experience/ark?csid=excs-202604211456-%5BItohAUJtw7vOeuF1P6gfR%5D&mode=chat&modelId=doubao-seed-2-0-lite-260215';
const XUNFEI_CONSOLE_URL = 'https://console.xfyun.cn/services/bmc';

function trimValue(value, fallback = '') {
  const text = String(value ?? '').trim();
  return text || fallback;
}

function getMaskedAccess(hasKey) {
  return Number(hasKey || 0) !== 0 ? MASKED_KEY : UNCONFIGURED_KEY;
}

function createPlatformTag(platform) {
  if (platform === 'volcengine') {
    return { text: '豆包 / 火山引擎', cls: 'volcengine' };
  }
  return { text: '讯飞', cls: 'xunfei' };
}

function normalizeDoubaoRows(assistantState) {
  const options = Array.isArray(assistantState.model_options) ? assistantState.model_options : [];
  const doubaoOptions = options.filter((item) => {
    const id = String(item?.id || '').trim().toLowerCase();
    const provider = String(item?.provider || '').trim().toLowerCase();
    return Number(item?.enabled ?? 1) !== 0 && (provider === 'volcengine-ark' || id.startsWith('doubao-'));
  });

  const activeModel = trimValue(assistantState.model, '');
  const accessText = getMaskedAccess(assistantState.has_api_key);
  const platform = createPlatformTag('volcengine');

  return doubaoOptions.map((item, index) => {
    const id = trimValue(item?.id, `doubao_${index + 1}`);
    const name = trimValue(item?.name, id);
    const isActive = activeModel === id;
    return {
      id: `doubao_${id}`,
      platform,
      name,
      note: isActive ? `模型 ID：${id} · 当前启用` : `模型 ID：${id}`,
      access: accessText,
      accessState: accessText === MASKED_KEY ? 'configured' : 'unconfigured',
      used: UNKNOWN_METRIC,
      remaining: UNKNOWN_METRIC,
      manage_url: VOLCENGINE_CONSOLE_URL,
      manage_label: '进入控制台'
    };
  });
}

function createXunfeiRow(assistantState) {
  const model = trimValue(assistantState.voice_model, 'xunfei_websocket_asr');
  const isActive = Number(assistantState.voice_model_enabled || 0) !== 0;
  const hasAppId = trimValue(assistantState.xunfei_app_id, '') !== '';
  const hasKey = Number(assistantState.has_xunfei_api_key || 0) !== 0;
  const hasSecret = Number(assistantState.has_xunfei_api_secret || 0) !== 0;
  const accessText = hasAppId && hasKey && hasSecret ? MASKED_KEY : UNCONFIGURED_KEY;
  return {
    id: 'xunfei_voice',
    platform: createPlatformTag('xunfei'),
    name: '讯飞语音识别 API',
    note: isActive
      ? `模型 ID：${model} · 当前启用`
      : `模型 ID：${model}`,
    access: accessText,
    accessState: accessText === MASKED_KEY ? 'configured' : 'unconfigured',
    used: UNKNOWN_METRIC,
    remaining: UNKNOWN_METRIC,
    manage_url: XUNFEI_CONSOLE_URL,
    manage_label: '进入控制台'
  };
}

function renderRows() {
  const body = byId('apiCenterRows');
  if (!body) return;

  const rows = Array.isArray(state.apiCenter.rows) ? state.apiCenter.rows : [];
  if (!rows.length) {
    body.innerHTML = '<tr><td colspan="5" class="api-center-empty">当前未识别到已登记 API。</td></tr>';
    return;
  }

  body.innerHTML = rows.map((row) => {
    const linkHtml = row.manage_url
      ? `<a class="api-center-link-btn" href="${escapeHtml(row.manage_url)}" target="_blank" rel="noreferrer">${escapeHtml(row.manage_label)}</a>`
      : `<span class="api-center-link-btn disabled">${escapeHtml(row.manage_label)}</span>`;

    return `
      <tr>
        <td>
          <div class="api-center-api-name">
            <span class="api-center-platform-tag ${escapeHtml(row.platform.cls)}">${escapeHtml(row.platform.text)}</span>
            <strong>${escapeHtml(row.name)}</strong>
            <span class="api-center-api-note">${escapeHtml(row.note)}</span>
          </div>
        </td>
        <td>
          <div class="api-center-access ${escapeHtml(row.accessState)}">
            <code>${escapeHtml(row.access)}</code>
          </div>
        </td>
        <td><span class="api-center-metric">${escapeHtml(row.used)}</span></td>
        <td><span class="api-center-metric">${escapeHtml(row.remaining)}</span></td>
        <td>${linkHtml}</td>
      </tr>
    `;
  }).join('');
}

function renderSummary() {
  const totalEl = byId('apiCenterTotalCount');
  const configuredEl = byId('apiCenterConfiguredCount');
  const usageEl = byId('apiCenterUsageStatus');

  const rows = Array.isArray(state.apiCenter.rows) ? state.apiCenter.rows : [];
  const configuredCount = rows.filter((row) => row.accessState === 'configured').length;

  if (totalEl) totalEl.textContent = String(rows.length);
  if (configuredEl) configuredEl.textContent = String(configuredCount);
  if (usageEl) usageEl.textContent = trimValue(state.apiCenter.usage_status, '待接入');
}

function updateApiCenterState(rows) {
  state.apiCenter.rows = rows;
  state.apiCenter.last_sync = new Date().toLocaleString('zh-CN', { hour12: false });
  state.apiCenter.usage_status = `待接入 · ${state.apiCenter.last_sync}`;
  renderSummary();
  renderRows();
}

export async function refreshApiCenterState(options = {}) {
  const silent = !!options.silent;
  const assistantPayload = await api('/api/assistant/state');
  const assistantState = assistantPayload?.state?.settings || {};

  const rows = [
    ...normalizeDoubaoRows(assistantState),
    createXunfeiRow(assistantState)
  ];

  updateApiCenterState(rows);
  if (!silent) {
    toast('API 管理中心已刷新');
  }
}

export function initApiCenterHandlers() {
  const refreshBtn = byId('apiCenterRefreshBtn');
  if (!refreshBtn) return;

  refreshBtn.onclick = async () => {
    try {
      await refreshApiCenterState();
    } catch (error) {
      toast(`刷新失败: ${error.message}`);
    }
  };
}
