const outputEl = document.getElementById('output');
const apiBaseEl = document.getElementById('apiBase');

function log(line) {
  const now = new Date().toLocaleTimeString();
  outputEl.value = outputEl.value ? `${outputEl.value}\n[${now}] ${line}` : `[${now}] ${line}`;
  outputEl.scrollTop = outputEl.scrollHeight;
}

async function getActiveTab() {
  const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
  return tabs[0];
}

async function loadProfile() {
  const base = String(apiBaseEl.value || 'http://127.0.0.1:8798').trim().replace(/\/+$/, '');
  const res = await fetch(`${base}/api/resume/profile`);
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}`);
  }
  const payload = await res.json();
  if (!payload.ok) {
    throw new Error(payload.error || 'load profile failed');
  }
  return payload;
}

function logStrategyDetails(items) {
  const list = Array.isArray(items) ? items : [];
  if (!list.length) {
    log('站点策略：本页未命中专用策略，已只走通用填表。');
    return;
  }

  list.forEach((item) => {
    log(`站点策略：${item.label || item.id}，专用动作命中 ${item.filled || 0} 项`);
    for (const note of item.notes || []) {
      log(`  - ${note}`);
    }
    for (const action of item.actions || []) {
      log(`  - action: ${action}`);
    }
  });
}

document.getElementById('loadBtn').onclick = async () => {
  try {
    const payload = await loadProfile();
    const sectionCount = Array.isArray(payload.profile?.sections) ? payload.profile.sections.length : 0;
    const itemCount = Object.keys(payload.flat_map || {}).length;
    log(`已读取本地简历：sections=${sectionCount} flat_keys=${itemCount}`);
  } catch (e) {
    log(`读取失败: ${e.message}`);
  }
};

document.getElementById('fillBtn').onclick = async () => {
  try {
    const payload = await loadProfile();
    const tab = await getActiveTab();
    if (!tab?.id) {
      throw new Error('未找到当前标签页');
    }
    const response = await chrome.tabs.sendMessage(tab.id, {
      type: 'ZCG_RESUME_FILL',
      profile: payload.profile,
      flatMap: payload.flat_map
    });
    if (!response?.ok) {
      throw new Error(response?.error || 'resume fill failed');
    }

    log(`自动填表完成：总命中 ${response.filled || 0} 项`);
    log(`  - 站点策略命中：${response.strategyFilled || 0} 项`);
    log(`  - 通用回退命中：${response.genericFilled || 0} 项`);
    logStrategyDetails(response.matchedStrategies);
  } catch (e) {
    log(`自动填表失败: ${e.message}`);
  }
};
