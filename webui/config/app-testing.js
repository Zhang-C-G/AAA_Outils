import { byId, api, toast, toInt } from './app-common.js';

function appendOutput(line) {
  const el = byId('testOutput');
  const now = new Date();
  const stamp = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}:${String(now.getSeconds()).padStart(2, '0')}`;
  const text = `[${stamp}] ${line}`;
  el.value = el.value ? `${el.value}\n${text}` : text;
  el.scrollTop = el.scrollHeight;
}

export async function openHotkeyProbe() {
  const payload = await api('/api/testing/open-hotkey-probe', {
    method: 'POST',
    body: '{}'
  });
  if (!payload.ok) {
    throw new Error(payload.error || 'open hotkey probe failed');
  }
  appendOutput(`已打开按键焦点探针: ${payload.path || ''}`);
  toast('已打开按键焦点探针');
}

export async function runOverlayRecordTest() {
  const durationSec = toInt(byId('testDurationSec').value, 6, 4, 30);
  const fps = toInt(byId('testFps').value, 10, 5, 30);

  appendOutput(`开始执行录屏捕获检测: duration=${durationSec}s fps=${fps}`);

  const payload = await api('/api/testing/run-overlay-record-capture', {
    method: 'POST',
    body: JSON.stringify({ duration_sec: durationSec, fps })
  });

  if (!payload.ok) {
    throw new Error(payload.error || 'run overlay record capture failed');
  }

  const summary = payload.summary || '';
  const output = (payload.output || '').trim();
  appendOutput(summary || '测试执行完成');
  if (output) {
    appendOutput('--- 输出开始 ---');
    appendOutput(output);
    appendOutput('--- 输出结束 ---');
  }
  toast('录屏捕获检测已完成');
}

export function initTestingHandlers() {
  const openBtn = byId('openHotkeyProbeBtn');
  const runBtn = byId('runOverlayRecordTestBtn');

  if (openBtn) {
    openBtn.onclick = () => openHotkeyProbe().catch((e) => toast(`打开探针失败: ${e.message}`));
  }
  if (runBtn) {
    runBtn.onclick = () => runOverlayRecordTest().catch((e) => toast(`执行测试失败: ${e.message}`));
  }
}
