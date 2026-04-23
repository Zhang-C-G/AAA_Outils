import { byId, api, toast, isTruthy } from './app-common.js';

function setStatusBadge(el, text, cls) {
  el.className = `badge ${cls}`;
  el.textContent = text;
}

function applyCaptureState(payload) {
  const s = payload.state || {};
  const settings = s.settings || {};

  byId('capPort').value = settings.bridge_port ?? 8787;
  byId('capEndpoint').value = settings.upload_endpoint ?? 'https://0x0.st';
  byId('capOpenQr').checked = isTruthy(settings.open_qr_after_upload);

  byId('capBridgeUrl').value = s.bridge_url || '';
  byId('capLatest').value = s.latest_capture || '';

  if (s.pc_connected) {
    setStatusBadge(byId('capPcStatus'), 'PC: CONNECTED', 'on');
  } else {
    setStatusBadge(byId('capPcStatus'), 'PC: DISCONNECTED', 'off');
  }

  const phone = (s.phone_state || 'WAITING').toUpperCase();
  if (phone === 'CONNECTED') {
    setStatusBadge(byId('capPhoneStatus'), 'PHONE: CONNECTED', 'on');
  } else if (phone === 'WAITING') {
    setStatusBadge(byId('capPhoneStatus'), 'PHONE: WAITING', 'wait');
  } else {
    setStatusBadge(byId('capPhoneStatus'), 'PHONE: DISCONNECTED', 'off');
  }
}

export async function refreshCaptureState() {
  const payload = await api('/api/capture/state');
  if (!payload.ok) throw new Error(payload.error || 'load capture state failed');
  applyCaptureState(payload);
}

async function saveCaptureSettings() {
  const payload = await api('/api/capture/save-settings', {
    method: 'POST',
    body: JSON.stringify({
      bridge_port: byId('capPort').value,
      upload_endpoint: byId('capEndpoint').value,
      open_qr_after_upload: byId('capOpenQr').checked ? 1 : 0
    })
  });
  if (!payload.ok) throw new Error(payload.error || 'save capture settings failed');
  toast('截图设置已保存');
  await refreshCaptureState();
}

export function initCaptureHandlers() {
  byId('capSaveSettingsBtn').onclick = () => saveCaptureSettings().catch(e => toast(`保存失败: ${e.message}`));

  byId('capStartBtn').onclick = async () => {
    const payload = await api('/api/capture/start-link', { method: 'POST', body: '{}' });
    if (!payload.ok) throw new Error(payload.error || 'start failed');
    applyCaptureState(payload);
    toast('连接服务已启动');
  };

  byId('capStopBtn').onclick = async () => {
    const payload = await api('/api/capture/stop-link', { method: 'POST', body: '{}' });
    if (!payload.ok) throw new Error(payload.error || 'stop failed');
    applyCaptureState(payload);
    toast('连接服务已停止');
  };

  byId('capCaptureBtn').onclick = async () => {
    const payload = await api('/api/capture/capture-screen', { method: 'POST', body: '{}' });
    if (!payload.ok) throw new Error(payload.error || 'capture failed');
    applyCaptureState(payload);
    toast('截图完成');
  };

  byId('capUploadBtn').onclick = async () => {
    await saveCaptureSettings();
    const payload = await api('/api/capture/upload', { method: 'POST', body: '{}' });
    if (!payload.ok) throw new Error(payload.error || 'upload failed');
    byId('capPhoneUrl').value = payload.url || '';
    toast('上传成功，链接已生成');
  };

  byId('capOpenPhoneBtn').onclick = async () => {
    await saveCaptureSettings();
    const payload = await api('/api/capture/open-phone', { method: 'POST', body: '{}' });
    if (!payload.ok) throw new Error(payload.error || 'open phone failed');
    byId('capPhoneUrl').value = payload.url || '';
    applyCaptureState(payload);
  };

  byId('capOpenFolderBtn').onclick = async () => {
    const payload = await api('/api/capture/open-folder', { method: 'POST', body: '{}' });
    if (!payload.ok) throw new Error(payload.error || 'open folder failed');
  };
}
