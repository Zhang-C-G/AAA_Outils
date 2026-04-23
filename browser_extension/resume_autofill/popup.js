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

document.getElementById('loadBtn').onclick = async () => {
  try {
    const payload = await loadProfile();
    const sectionCount = Array.isArray(payload.profile?.sections) ? payload.profile.sections.length : 0;
    const itemCount = Object.keys(payload.flat_map || {}).length;
    log(`已读取本地简历：sections=${sectionCount} flat_keys=${itemCount}`);
  } catch (e) {
    log(`读取失败：${e.message}`);
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
    log(`自动填写完成：${response?.filled || 0} 项`);
  } catch (e) {
    log(`自动填写失败：${e.message}`);
  }
};
