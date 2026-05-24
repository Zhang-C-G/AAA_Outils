import { state, byId, api, toast, toInt } from './app-common.js';
import { saveAssistantSettings } from './app-assistant.js';

const ASSISTANT_BENCHMARK_HISTORY_LIMIT = 5;
const VOICE_BENCHMARK_HISTORY_LIMIT = 5;
const TESTING_SUBVIEW_ORDER = ['assistant_benchmark', 'voice_benchmark', 'overlay_record'];
const TESTING_SUBVIEW_LABELS = {
  assistant_benchmark: '接口基线',
  voice_benchmark: '语音延迟',
  overlay_record: '录屏捕获'
};
let assistantBenchmarkRunning = false;
let assistantBenchmarkTimer = 0;
let assistantBenchmarkStartedAt = 0;
let assistantBenchmarkPollTimer = 0;
let assistantBenchmarkRunId = '';
let voiceBenchmarkRunning = false;
let voiceBenchmarkTimer = 0;
let voiceBenchmarkStartedAt = 0;

function normalizeTestingSubview(raw) {
  const value = String(raw || '').trim().toLowerCase();
  return TESTING_SUBVIEW_ORDER.includes(value) ? value : 'assistant_benchmark';
}

async function persistTestingSubview() {
  await api('/api/app/testing-subview', {
    method: 'POST',
    body: JSON.stringify({ testing_subview: state.app.testing_subview })
  });
}

function syncTestingSubview() {
  state.app.testing_subview = normalizeTestingSubview(state.app.testing_subview);
  const active = state.app.testing_subview;
  const metaEl = byId('testingSubviewMeta');
  const tabs = [
    ['assistant_benchmark', byId('testingSubviewAssistantBtn'), byId('testingAssistantPanel')],
    ['voice_benchmark', byId('testingSubviewVoiceBtn'), byId('testingVoicePanel')],
    ['overlay_record', byId('testingSubviewOverlayBtn'), byId('testingOverlayPanel')]
  ];

  tabs.forEach(([id, button, panel], index) => {
    const isActive = id === active;
    if (button) {
      button.classList.toggle('active', isActive);
      button.setAttribute('aria-selected', isActive ? 'true' : 'false');
      button.tabIndex = isActive ? 0 : -1;
      button.dataset.testingSubviewIndex = String(index);
    }
    if (panel) {
      panel.classList.toggle('hidden', !isActive);
    }
  });
  if (metaEl) {
    metaEl.textContent = `当前：${TESTING_SUBVIEW_LABELS[active] || '接口基线'}`;
  }
}

function setTestingSubview(nextSubview, options = {}) {
  const persist = options.persist !== false;
  const normalized = normalizeTestingSubview(nextSubview);
  if (state.app.testing_subview === normalized) {
    syncTestingSubview();
    return;
  }
  state.app.testing_subview = normalized;
  syncTestingSubview();
  if (persist) {
    void persistTestingSubview().catch((e) => {
      toast(`testing subview save failed: ${e.message}`);
    });
  }
}

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

function normalizeVoiceBenchmark(incoming = {}, existingHistory = []) {
  const history = Array.isArray(incoming.history)
    ? incoming.history.slice(0, VOICE_BENCHMARK_HISTORY_LIMIT)
    : Array.isArray(existingHistory)
      ? existingHistory.slice(0, VOICE_BENCHMARK_HISTORY_LIMIT)
      : [];

  return {
    engine_id: String(incoming.engine_id || 'xunfei_websocket_asr').trim(),
    engine_label: String(incoming.engine_label || '讯飞 WebSocket 语音识别').trim(),
    sample_text: String(incoming.sample_text || '').trim(),
    note: String(incoming.note || '').trim(),
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

function benchmarkModeLabel(last) {
  return last?.streamed ? '流式输出' : '整段返回';
}

function streamVerdictLabel(last) {
  const value = String(last?.stream_verdict || '').trim();
  if (value === 'answer_streaming_verified') return '答案已验证流式';
  if (value === 'reasoning_only_streaming') return '只有推理在流';
  if (value === 'verified_streaming') return '已验证流式';
  if (value === 'single_chunk_only') return '只有单次更新';
  if (value === 'no_stream_events') return '未观察到流式事件';
  if (value === 'error') return '流式过程出错';
  if (value === 'pending') return '监测中';
  return value || '-';
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

function updateVoiceBenchmarkTimerLabel() {
  const el = byId('voiceBenchmarkTimer');
  if (!el) return;
  if (!voiceBenchmarkRunning || !voiceBenchmarkStartedAt) {
    const totalMs = Number(state.assistant.voice_benchmark?.last_result?.elapsed_ms || 0);
    el.textContent = `${msToSeconds(totalMs)} s`;
    return;
  }
  const elapsed = Date.now() - voiceBenchmarkStartedAt;
  el.textContent = `${(elapsed / 1000).toFixed(1)} s`;
}

function startVoiceBenchmarkTimer() {
  stopVoiceBenchmarkTimer();
  voiceBenchmarkStartedAt = Date.now();
  voiceBenchmarkTimer = window.setInterval(updateVoiceBenchmarkTimerLabel, 100);
  updateVoiceBenchmarkTimerLabel();
}

function stopVoiceBenchmarkTimer() {
  if (voiceBenchmarkTimer) {
    clearInterval(voiceBenchmarkTimer);
    voiceBenchmarkTimer = 0;
  }
  voiceBenchmarkStartedAt = 0;
  updateVoiceBenchmarkTimerLabel();
}

function stopBenchmarkPolling() {
  if (assistantBenchmarkPollTimer) {
    clearInterval(assistantBenchmarkPollTimer);
    assistantBenchmarkPollTimer = 0;
  }
  assistantBenchmarkRunId = '';
}

function applyBenchmarkResult(result, options = {}) {
  const keepHistory = !!options.keepHistory;
  const benchmark = normalizeBenchmark(result.benchmark || state.assistant.benchmark, state.assistant.benchmark?.history || []);
  benchmark.selected_model = state.assistant.benchmark.selected_model || result.model || state.assistant.model || '';

  const normalizedResult = {
    model: String(result.model || benchmark.selected_model || state.assistant.model || '').trim(),
    started_at: String(result.started_at || '').trim(),
    perf: result.perf || {},
    streamed: !!result.streamed,
    stream_metrics: result.stream_metrics || {},
    stream_verdict: String(result.stream_verdict || '').trim(),
    reasoning: String(result.reasoning || '').trim(),
    answer_preview: String(result.answer_preview || '').trim(),
    answer: String(result.answer || '').trim(),
    status: String(result.status || '').trim(),
    error: String(result.error || '').trim()
  };

  benchmark.last_result = normalizedResult;
  if (!keepHistory && normalizedResult.status === 'done' && !normalizedResult.error) {
    benchmark.history = [normalizedResult, ...(benchmark.history || [])].slice(0, ASSISTANT_BENCHMARK_HISTORY_LIMIT);
  }
  state.assistant.benchmark = benchmark;
}

function applyVoiceBenchmarkResult(result, options = {}) {
  const keepHistory = !!options.keepHistory;
  const benchmark = normalizeVoiceBenchmark(result.state || state.assistant.voice_benchmark, state.assistant.voice_benchmark?.history || []);
  const normalizedResult = {
    started_at: String(result.started_at || '').trim(),
    elapsed_ms: Number(result.elapsed_ms || 0),
    exit_code: Number(result.exit_code || 0),
    transcript: String(result.transcript || '').trim(),
    transcript_chars: Number(result.transcript_chars || 0),
    text: String(result.text || '').trim(),
    error: String(result.error || '').trim(),
    status_stage: String(result.status_stage || '').trim(),
    status_detail: String(result.status_detail || '').trim(),
    metrics: result.metrics || {}
  };

  benchmark.last_result = normalizedResult;
  if (!keepHistory && !normalizedResult.error) {
    benchmark.history = [normalizedResult, ...(benchmark.history || [])].slice(0, VOICE_BENCHMARK_HISTORY_LIMIT);
  }
  state.assistant.voice_benchmark = benchmark;
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
      const statusText = last.error
        ? `状态：失败 - ${last.error}`
        : (last.status === 'running' ? '状态：流式返回中...' : '状态：已完成');
      summary.innerHTML = `
        <div><strong>本次结果</strong></div>
        <div>${statusText}</div>
        <div>模型：${last.model || '-'}</div>
        <div>开始时间：${last.started_at || '-'}</div>
        <div>输出模式：${benchmarkModeLabel(last)}</div>
        <div>流式判定：${streamVerdictLabel(last)}</div>
        <div>总耗时：${msToSeconds(perf.total_ms)} s</div>
        <div>请求耗时：${msToSeconds(perf.request_ms)} s</div>
        <div>读图：${msToSeconds(perf.read_ms)} s | Base64：${msToSeconds(perf.base64_ms)} s | 组包：${msToSeconds(perf.json_ms)} s | 解析：${msToSeconds(perf.parse_ms)} s</div>
        <div>图片：${Number(perf.image_kb || 0)} KB | 请求体：${Number(perf.payload_kb || 0)} KB</div>
        <div>首事件：${metricValue(last.stream_metrics || {}, 'first_event_ms')} | 首文本：${metricValue(last.stream_metrics || {}, 'first_answer_ms')} | 首推理：${metricValue(last.stream_metrics || {}, 'first_reasoning_ms')}</div>
        <div>事件数：${Number(last.stream_metrics?.event_count || 0)} | 文本更新：${Number(last.stream_metrics?.answer_updates || 0)} | 推理更新：${Number(last.stream_metrics?.reasoning_updates || 0)} | 最大停顿：${metricValue(last.stream_metrics || {}, 'max_event_gap_ms')}</div>
        <div>答案流式：${last.stream_metrics?.answer_streaming_verified ? '是' : '否'}</div>
      `;
    }
  }

  if (answer) {
    answer.textContent = last?.answer || '这里会显示最近一次测试返回的答案。';
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
            <div><strong>${item.started_at || '-'}</strong> | ${item.model || '-'}</div>
            <div>模式 ${benchmarkModeLabel(item)}</div>
            <div>判定 ${streamVerdictLabel(item)}</div>
            <div>总耗时 ${msToSeconds(perf.total_ms)} s | 请求 ${msToSeconds(perf.request_ms)} s</div>
            <div>首事件 ${metricValue(item.stream_metrics || {}, 'first_event_ms')} | 首文本 ${metricValue(item.stream_metrics || {}, 'first_answer_ms')} | 更新 ${Number(item.stream_metrics?.answer_updates || 0)} | 答案流式 ${item.stream_metrics?.answer_streaming_verified ? '是' : '否'}</div>
            <div>图 ${Number(perf.image_kb || 0)} KB | 包 ${Number(perf.payload_kb || 0)} KB</div>
          </div>
        `;
      }).join('');
    }
  }

  updateBenchmarkTimerLabel();
}

function metricValue(metrics, key) {
  const value = Number(metrics?.[key] ?? 0);
  return value > 0 ? `${value} ms` : '-';
}

function renderVoiceBenchmark() {
  const benchmark = normalizeVoiceBenchmark(state.assistant.voice_benchmark, state.assistant.voice_benchmark?.history || []);
  state.assistant.voice_benchmark = benchmark;

  const engine = byId('voiceBenchmarkEngine');
  const meta = byId('voiceBenchmarkMeta');
  const summary = byId('voiceBenchmarkSummary');
  const metricsEl = byId('voiceBenchmarkMetrics');
  const transcript = byId('voiceBenchmarkTranscript');
  const historyEl = byId('voiceBenchmarkHistory');
  const runBtn = byId('voiceBenchmarkRunBtn');

  if (engine) engine.textContent = benchmark.engine_label || '讯飞 WebSocket 语音识别';
  if (runBtn) {
    runBtn.disabled = voiceBenchmarkRunning;
    runBtn.textContent = voiceBenchmarkRunning ? '测试中...' : '开始测试';
  }

  if (meta) {
    meta.innerHTML = `
      <div><strong>固定测试样本</strong></div>
      <div>${benchmark.sample_text || '未提供样本文字'}</div>
      <div>${benchmark.note || '固定中文样本，仅测试语音识别链路本身。'}</div>
    `;
  }

  const last = benchmark.last_result;
  if (summary) {
    if (!last) {
      summary.innerHTML = '<div>还没有语音延迟测试结果。点击“开始测试”后，这里会显示总耗时与识别状态。</div>';
    } else {
      const statusText = last.error ? `状态：失败 - ${last.error}` : '状态：已完成';
      summary.innerHTML = `
        <div><strong>本次结果</strong></div>
        <div>${statusText}</div>
        <div>开始时间：${last.started_at || '-'}</div>
        <div>总耗时：${msToSeconds(last.elapsed_ms)} s</div>
        <div>识别字数：${Number(last.transcript_chars || 0)}</div>
        <div>阶段：${last.status_stage || '-'} | 细节：${last.status_detail || '-'}</div>
      `;
    }
  }

  if (metricsEl) {
    const metrics = last?.metrics || {};
    metricsEl.innerHTML = `
      <div><strong>链路分段耗时</strong></div>
      <div>音频载入：${metricValue(metrics, 'audio_file_loaded_ms')}</div>
      <div>WebSocket 连接：${metricValue(metrics, 'websocket_connected_ms')}</div>
      <div>首包发送：${metricValue(metrics, 'first_audio_sent_ms')}</div>
      <div>首条响应：${metricValue(metrics, 'first_result_received_ms')}</div>
      <div>首条有效文本：${metricValue(metrics, 'first_nonempty_text_received_ms')}</div>
      <div>末包发送：${metricValue(metrics, 'final_payload_sent_ms')}</div>
      <div>最终完成：${metricValue(metrics, 'completed_ms')}</div>
    `;
  }

  if (transcript) {
    transcript.textContent = last?.transcript || '这里会显示最近一次语音延迟测试返回的识别文本。';
  }

  if (historyEl) {
    const history = Array.isArray(benchmark.history) ? benchmark.history : [];
    if (!history.length) {
      historyEl.innerHTML = '<div class="assistant-benchmark-history-empty">暂无历史记录</div>';
    } else {
      historyEl.innerHTML = history.map((item) => `
        <div class="assistant-benchmark-history-item">
          <div><strong>${item.started_at || '-'}</strong></div>
          <div>总耗时 ${msToSeconds(item.elapsed_ms)} s | 字数 ${Number(item.transcript_chars || 0)}</div>
          <div>首条响应 ${metricValue(item.metrics || {}, 'first_result_received_ms')} | 首条文本 ${metricValue(item.metrics || {}, 'first_nonempty_text_received_ms')}</div>
        </div>
      `).join('');
    }
  }

  updateVoiceBenchmarkTimerLabel();
}

async function pollAssistantBenchmarkRun() {
  if (!assistantBenchmarkRunId) return;
  const payload = await api(`/api/assistant/benchmark-stream-state?run_id=${encodeURIComponent(assistantBenchmarkRunId)}`);
  if (!payload.ok) {
    throw new Error(payload.error || 'assistant benchmark stream state failed');
  }

  applyBenchmarkResult(payload, { keepHistory: payload.status !== 'done' });
  renderAssistantBenchmark();

  if (payload.status === 'done') {
    assistantBenchmarkRunning = false;
    stopBenchmarkTimer();
    stopBenchmarkPolling();
    renderAssistantBenchmark();
    toast(`API 基线测试完成：${msToSeconds(payload.perf?.total_ms)} s`);
  } else if (payload.status === 'error') {
    assistantBenchmarkRunning = false;
    stopBenchmarkTimer();
    stopBenchmarkPolling();
    renderAssistantBenchmark();
    throw new Error(payload.error || 'assistant benchmark stream failed');
  }
}

export async function refreshTestingState() {
  state.app.testing_subview = normalizeTestingSubview(state.app.testing_subview);
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
  try {
    const payload = await api('/api/testing/voice-latency-state');
    if (!payload.ok) throw new Error(payload.error || 'voice latency state failed');
    const benchmark = normalizeVoiceBenchmark(payload.state || {}, state.assistant.voice_benchmark?.history || []);
    benchmark.last_result = state.assistant.voice_benchmark?.last_result || null;
    state.assistant.voice_benchmark = benchmark;
  } catch {
    // Keep testing page usable even if voice latency state fails.
  }
  syncTestingSubview();
  renderAssistantBenchmark();
  renderVoiceBenchmark();
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
  stopBenchmarkPolling();
  state.assistant.benchmark.selected_model = getBenchmarkSelectedModel();
  renderAssistantBenchmark();
  startBenchmarkTimer();

  try {
    await saveAssistantSettings({ silent: true });

    const payload = await api('/api/assistant/benchmark-stream-start', {
      method: 'POST',
      body: JSON.stringify({ model: state.assistant.benchmark.selected_model || '' })
    });
    if (!payload.ok) throw new Error(payload.error || 'assistant benchmark start failed');

    assistantBenchmarkRunId = String(payload.run_id || '').trim();
    if (!assistantBenchmarkRunId) {
      throw new Error('assistant benchmark run id missing');
    }

    if (payload.state) {
      applyBenchmarkResult(payload.state, { keepHistory: true });
      renderAssistantBenchmark();
    }

    assistantBenchmarkPollTimer = window.setInterval(() => {
      pollAssistantBenchmarkRun().catch((e) => {
        assistantBenchmarkRunning = false;
        stopBenchmarkTimer();
        stopBenchmarkPolling();
        renderAssistantBenchmark();
        toast(`测试失败: ${e.message}`);
      });
    }, 350);

    await pollAssistantBenchmarkRun();
  } catch (e) {
    assistantBenchmarkRunning = false;
    stopBenchmarkTimer();
    stopBenchmarkPolling();
    renderAssistantBenchmark();
    toast(`测试失败: ${e.message}`);
  }
}

export async function runVoiceLatencyBenchmark() {
  if (voiceBenchmarkRunning) return;

  voiceBenchmarkRunning = true;
  renderVoiceBenchmark();
  startVoiceBenchmarkTimer();

  try {
    const payload = await api('/api/testing/run-voice-latency-benchmark', {
      method: 'POST',
      body: '{}'
    });
    if (!payload.ok) throw new Error(payload.error || 'voice latency benchmark failed');

    applyVoiceBenchmarkResult(payload);
    stopVoiceBenchmarkTimer();
    voiceBenchmarkRunning = false;
    renderVoiceBenchmark();
    toast(`语音延迟测试完成: ${msToSeconds(payload.elapsed_ms)} s`);
  } catch (e) {
    voiceBenchmarkRunning = false;
    stopVoiceBenchmarkTimer();
    renderVoiceBenchmark();
    toast(`语音测试失败: ${e.message}`);
  }
}

export function initTestingHandlers() {
  const openBtn = byId('openHotkeyProbeBtn');
  const runBtn = byId('runOverlayRecordTestBtn');
  const benchmarkBtn = byId('assistantBenchmarkRunBtn');
  const benchmarkModel = byId('assistantBenchmarkModel');
  const voiceBenchmarkBtn = byId('voiceBenchmarkRunBtn');
  const subviewButtons = [
    ['assistant_benchmark', byId('testingSubviewAssistantBtn')],
    ['voice_benchmark', byId('testingSubviewVoiceBtn')],
    ['overlay_record', byId('testingSubviewOverlayBtn')]
  ];

  if (openBtn) {
    openBtn.onclick = () => openHotkeyProbe().catch((e) => toast(`open probe failed: ${e.message}`));
  }
  if (runBtn) {
    runBtn.onclick = () => runOverlayRecordTest().catch((e) => toast(`run test failed: ${e.message}`));
  }
  if (benchmarkBtn) {
    benchmarkBtn.onclick = () => runAssistantBenchmark().catch((e) => toast(`run test failed: ${e.message}`));
  }
  if (benchmarkModel) {
    benchmarkModel.onchange = () => {
      state.assistant.benchmark.selected_model = benchmarkModel.value;
      renderAssistantBenchmark();
    };
  }
  if (voiceBenchmarkBtn) {
    voiceBenchmarkBtn.onclick = () => runVoiceLatencyBenchmark().catch((e) => toast(`run voice test failed: ${e.message}`));
  }

  subviewButtons.forEach(([id, button]) => {
    if (!button) return;
    button.onclick = () => setTestingSubview(id);
    button.onkeydown = (event) => {
      if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') return;
      event.preventDefault();
      const currentIndex = TESTING_SUBVIEW_ORDER.indexOf(state.app.testing_subview);
      const step = event.key === 'ArrowRight' ? 1 : -1;
      const nextIndex = (currentIndex + step + TESTING_SUBVIEW_ORDER.length) % TESTING_SUBVIEW_ORDER.length;
      const nextId = TESTING_SUBVIEW_ORDER[nextIndex];
      setTestingSubview(nextId);
      const nextButton = subviewButtons.find(([candidate]) => candidate === nextId)?.[1];
      if (nextButton) nextButton.focus();
    };
  });

  syncTestingSubview();
  renderAssistantBenchmark();
  renderVoiceBenchmark();
}
