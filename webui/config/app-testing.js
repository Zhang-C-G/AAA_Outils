import { state, byId, api, toast, toInt } from './app-common.js';
import { saveAssistantSettings } from './app-assistant.js';

const ASSISTANT_BENCHMARK_HISTORY_LIMIT = 5;
let assistantBenchmarkRunning = false;
let assistantBenchmarkTimer = 0;
let assistantBenchmarkStartedAt = 0;

function appendOutput(line) {
  const el = byId('testOutput');
  const now = new Date();
  const stamp = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}:${String(now.getSeconds()).padStart(2, '0')}`;
  const text = `[${stamp}] ${line}`;
  el.value = el.value ? `${el.value}\n${text}` : text;
  el.scrollTop = el.scrollHeight;
}

function msToSeconds(ms) {
  return (Number(ms || 0) / 1000).toFixed(2);
}

function normalizeBenchmark(incoming = {}, existingHistory = []) {
  const history = Array.isArray(incoming.history)
    ? incoming.history.slice(0, ASSISTANT_BENCHMARK_HISTORY_LIMIT)
    : Array.isArray(existingHistory)
      ? existingHistory.slice(0, ASSISTANT_BENCHMARK_HISTORY_LIMIT)
      : [];
  return {
    image_url: String(incoming.image_url || '').trim(),
    image_name: String(incoming.image_name || '').trim(),
    image_kb: Number(incoming.image_kb || 0),
    note: String(incoming.note || '').trim(),
    selected_model: String(incoming.selected_model || '').trim(),
    last_result: incoming.last_result || null,
    history
  };
}

function getBenchmarkSelectedModel() {
  const select = byId('assistantBenchmarkModel');
  const fromUi = String(select?.value || '').trim();
  if (fromUi) return fromUi;
  const fromBenchmark = String(state.assistant.benchmark?.selected_model || '').trim();
  if (fromBenchmark) return fromBenchmark;
  return String(state.assistant.model || '').trim();
}

function renderBenchmarkModelOptions() {
  const select = byId('assistantBenchmarkModel');
  if (!select) return;

  const options = Array.isArray(state.assistant.model_options) ? state.assistant.model_options : [];
  const current = getBenchmarkSelectedModel();
  select.innerHTML = '';

  for (const item of options) {
    if (Number(item?.enabled ?? 1) === 0) continue;
    const id = String(item?.id || '').trim();
    if (!id) continue;
    const opt = document.createElement('option');
    opt.value = id;
    opt.textContent = `${String(item?.name || id).trim()} (${id})`;
    select.appendChild(opt);
  }

  const hasCurrent = Array.from(select.options).some((o) => o.value === current);
  select.value = hasCurrent ? current : (select.options[0]?.value || '');
  state.assistant.benchmark.selected_model = select.value;
}

function updateBenchmarkTimerLabel() {
  const el = byId('assistantBenchmarkTimer');
  if (!el) return;
  if (!assistantBenchmarkRunning || !assistantBenchmarkStartedAt) {
    const totalMs = Number(state.assistant.benchmark?.last_result?.perf?.total_ms || 0);
    el.textContent = `${msToSeconds(totalMs)} s`;
    return;
  }
  const elapsed = Date.now() - assistantBenchmarkStartedAt;
  el.textContent = `${(elapsed / 1000).toFixed(1)} s`;
}

function startBenchmarkTimer() {
  stopBenchmarkTimer();
  assistantBenchmarkStartedAt = Date.now();
  assistantBenchmarkTimer = window.setInterval(updateBenchmarkTimerLabel, 100);
  updateBenchmarkTimerLabel();
}

function stopBenchmarkTimer() {
  if (assistantBenchmarkTimer) {
    clearInterval(assistantBenchmarkTimer);
    assistantBenchmarkTimer = 0;
  }
  assistantBenchmarkStartedAt = 0;
  updateBenchmarkTimerLabel();
}

function renderAssistantBenchmark() {
  const benchmark = normalizeBenchmark(state.assistant.benchmark, state.assistant.benchmark?.history || []);
  state.assistant.benchmark = benchmark;

  renderBenchmarkModelOptions();

  const img = byId('assistantBenchmarkImage');
  const meta = byId('assistantBenchmarkMeta');
  const summary = byId('assistantBenchmarkSummary');
  const answer = byId('assistantBenchmarkAnswer');
  const historyEl = byId('assistantBenchmarkHistory');
  const runBtn = byId('assistantBenchmarkRunBtn');

  if (runBtn) {
    runBtn.disabled = assistantBenchmarkRunning;
    runBtn.textContent = assistantBenchmarkRunning ? '测试中...' : '开始测试';
  }

  if (img) {
    if (benchmark.image_url) {
      img.src = benchmark.image_url;
      img.classList.remove('hidden');
    } else {
      img.removeAttribute('src');
      img.classList.add('hidden');
    }
  }

  if (meta) {
    meta.innerHTML = `
      <div><strong>默认题图</strong></div>
      <div>文件：${benchmark.image_name || '(未准备好)'}</div>
      <div>大小：${benchmark.image_kb ? `${benchmark.image_kb} KB` : '-'}</div>
      <div>${benchmark.note || '固定默认题图，用来判断图片问答 API 的基础耗时。'}</div>
    `;
  }

  const last = benchmark.last_result;
  if (summary) {
    if (!last) {
      summary.innerHTML = '<div>还没有测试结果。点击“开始测试”后，这里会显示本次基础耗时。</div>';
    } else {
      const perf = last.perf || {};
      summary.innerHTML = `
        <div><strong>本次结果</strong></div>
        <div>模型：${last.model || '-'}</div>
        <div>开始时间：${last.started_at || '-'}</div>
        <div>总耗时：${msToSeconds(perf.total_ms)} s</div>
        <div>请求耗时：${msToSeconds(perf.request_ms)} s</div>
        <div>读图：${msToSeconds(perf.read_ms)} s | Base64：${msToSeconds(perf.base64_ms)} s | 组包：${msToSeconds(perf.json_ms)} s | 解析：${msToSeconds(perf.parse_ms)} s</div>
        <div>图片：${Number(perf.image_kb || 0)} KB | 请求体：${Number(perf.payload_kb || 0)} KB</div>
      `;
    }
  }

  if (answer) {
    answer.textContent = last?.answer_preview || '这里会显示最近一次测试返回的答案预览。';
  }

  if (historyEl) {
    const history = Array.isArray(benchmark.history) ? benchmark.history : [];
    if (!history.length) {
      historyEl.innerHTML = '<div class="assistant-benchmark-history-empty">暂无历史记录</div>';
    } else {
      historyEl.innerHTML = history.map((item) => {
        const perf = item.perf || {};
        return `
          <div class="assistant-benchmark-history-item">
            <div><strong>${item.started_at || '-'}</strong> · ${item.model || '-'}</div>
            <div>总耗时 ${msToSeconds(perf.total_ms)} s · 请求 ${msToSeconds(perf.request_ms)} s</div>
            <div>图 ${Number(perf.image_kb || 0)} KB · 包 ${Number(perf.payload_kb || 0)} KB</div>
          </div>
        `;
      }).join('');
    }
  }

  updateBenchmarkTimerLabel();
}

export async function refreshTestingState() {
  try {
    const payload = await api('/api/assistant/benchmark-state');
    if (!payload.ok) throw new Error(payload.error || 'assistant benchmark state failed');
    const benchmark = normalizeBenchmark(payload.benchmark || {}, state.assistant.benchmark?.history || []);
    benchmark.last_result = state.assistant.benchmark?.last_result || null;
    benchmark.selected_model = state.assistant.benchmark?.selected_model || state.assistant.model || '';
    state.assistant.benchmark = benchmark;
  } catch {
    // Keep testing page usable even if preview state fails.
  }
  renderAssistantBenchmark();
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

export async function runAssistantBenchmark() {
  if (assistantBenchmarkRunning) return;
  assistantBenchmarkRunning = true;
  state.assistant.benchmark.selected_model = getBenchmarkSelectedModel();
  renderAssistantBenchmark();
  startBenchmarkTimer();
  try {
    await saveAssistantSettings({ silent: true });
    const payload = await api('/api/assistant/benchmark-run', {
      method: 'POST',
      body: JSON.stringify({ model: state.assistant.benchmark.selected_model || '' })
    });
    if (!payload.ok) throw new Error(payload.error || 'assistant benchmark failed');

    const result = {
      model: String(payload.model || state.assistant.benchmark.selected_model || state.assistant.model || '').trim(),
      started_at: String(payload.started_at || '').trim(),
      perf: payload.perf || {},
      answer_preview: String(payload.answer_preview || '').trim(),
      answer: String(payload.answer || '').trim()
    };
    const benchmark = normalizeBenchmark(payload.benchmark || state.assistant.benchmark, state.assistant.benchmark?.history || []);
    benchmark.selected_model = state.assistant.benchmark.selected_model || result.model;
    benchmark.last_result = result;
    benchmark.history = [result, ...(benchmark.history || [])].slice(0, ASSISTANT_BENCHMARK_HISTORY_LIMIT);
    state.assistant.benchmark = benchmark;
    renderAssistantBenchmark();
    toast(`API 基线测试完成：${msToSeconds(result.perf?.total_ms)} s`);
  } catch (e) {
    toast(`测试失败: ${e.message}`);
  } finally {
    assistantBenchmarkRunning = false;
    stopBenchmarkTimer();
    renderAssistantBenchmark();
  }
}

export function initTestingHandlers() {
  const openBtn = byId('openHotkeyProbeBtn');
  const runBtn = byId('runOverlayRecordTestBtn');
  const benchmarkBtn = byId('assistantBenchmarkRunBtn');
  const benchmarkModel = byId('assistantBenchmarkModel');

  if (openBtn) {
    openBtn.onclick = () => openHotkeyProbe().catch((e) => toast(`打开探针失败: ${e.message}`));
  }
  if (runBtn) {
    runBtn.onclick = () => runOverlayRecordTest().catch((e) => toast(`执行测试失败: ${e.message}`));
  }
  if (benchmarkBtn) {
    benchmarkBtn.onclick = () => runAssistantBenchmark().catch((e) => toast(`执行测试失败: ${e.message}`));
  }
  if (benchmarkModel) {
    benchmarkModel.onchange = () => {
      state.assistant.benchmark.selected_model = benchmarkModel.value;
      renderAssistantBenchmark();
    };
  }

  renderAssistantBenchmark();
}
