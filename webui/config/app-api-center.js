import { state, byId, api, toast, escapeHtml } from './app-common.js';

const UNKNOWN_METRIC = '?';

function trimValue(value, fallback = '') {
  const text = String(value ?? '').trim();
  return text || fallback;
}

function createAssistantRow(assistantState) {
  const endpoint = trimValue(assistantState.api_endpoint, '未填写问答模型 Endpoint');
  const model = trimValue(assistantState.model, '未选择问答模型');
  return {
    id: 'assistant_qa',
    name: '豆包方舟问答 API',
    note: `当前问答模型：${model}`,
    endpoint,
    used: UNKNOWN_METRIC,
    remaining: UNKNOWN_METRIC,
    manage_url: 'https://console.volcengine.com/ark',
    manage_label: '打开方舟控制台'
  };
}

function createVoiceRow(assistantState) {
  const model = trimValue(assistantState.voice_model, 'xunfei_websocket_asr');
  const apiEnabled = Number(assistantState.voice_model_enabled || 0) !== 0;
  return {
    id: 'assistant_voice',
    name: '讯飞语音识别 API',
    note: `当前语音模型：${model}${apiEnabled ? ' · 已激活' : ' · 未激活'}`,
    endpoint: 'WebSocket / 本地链路接入',
    used: UNKNOWN_METRIC,
    remaining: UNKNOWN_METRIC,
    manage_url: 'https://console.xfyun.cn/services/iat',
    manage_label: '打开讯飞控制台'
  };
}

function createCaptureRow(captureState) {
  const endpoint = trimValue(captureState.upload_endpoint, '未填写上传地址');
  let manageUrl = '';
  let manageLabel = '暂无官方中心';
  if (/^https?:\/\//i.test(endpoint)) {
    manageUrl = endpoint;
    manageLabel = '打开上传地址';
  }

  return {
    id: 'capture_upload',
    name: '截图上传 API',
    note: '用于截图发手机链路的上传落点',
    endpoint,
    used: UNKNOWN_METRIC,
    remaining: UNKNOWN_METRIC,
    manage_url: manageUrl,
    manage_label: manageLabel
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
      ? `<a class="api-center-link" href="${escapeHtml(row.manage_url)}" target="_blank" rel="noreferrer">${escapeHtml(row.manage_label)}</a>`
      : `<span class="api-center-link disabled">${escapeHtml(row.manage_label)}</span>`;

    return `
      <tr>
        <td>
          <div class="api-center-api-name">
            <strong>${escapeHtml(row.name)}</strong>
            <span class="api-center-api-note">${escapeHtml(row.note)}</span>
          </div>
        </td>
        <td>
          <div class="api-center-endpoint">
            <code>${escapeHtml(row.endpoint)}</code>
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
  const usageEl = byId('apiCenterUsageStatus');
  const syncEl = byId('apiCenterLastSync');

  if (totalEl) totalEl.textContent = String(Array.isArray(state.apiCenter.rows) ? state.apiCenter.rows.length : 0);
  if (usageEl) usageEl.textContent = trimValue(state.apiCenter.usage_status, '待接入');
  if (syncEl) syncEl.textContent = trimValue(state.apiCenter.last_sync, '未同步');
}

function updateApiCenterState(rows) {
  state.apiCenter.rows = rows;
  state.apiCenter.last_sync = new Date().toLocaleString('zh-CN', { hour12: false });
  state.apiCenter.usage_status = '未接官方读取';
  renderSummary();
  renderRows();
}

export async function refreshApiCenterState(options = {}) {
  const silent = !!options.silent;
  const [assistantPayload, capturePayload] = await Promise.all([
    api('/api/assistant/state'),
    api('/api/capture/state')
  ]);

  const assistantState = assistantPayload?.state?.settings || {};
  const captureState = capturePayload?.state?.settings || {};

  const rows = [
    createAssistantRow(assistantState),
    createVoiceRow(assistantState),
    createCaptureRow(captureState)
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
