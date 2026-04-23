import { state, byId, api, toast } from './app-common.js';

let resumeAutoSaveTimer = 0;

function normalizeRow(row, index = 0) {
  const type = String(row?.type || 'text').trim().toLowerCase();
  return {
    id: String(row?.id || `field_${index + 1}`).trim() || `field_${index + 1}`,
    label: String(row?.label || `字段${index + 1}`).trim() || `字段${index + 1}`,
    value: String(row?.value || ''),
    aliases: String(row?.aliases || ''),
    type: ['text', 'textarea', 'select', 'date'].includes(type) ? type : 'text'
  };
}

function normalizeSection(section, index = 0) {
  return {
    id: String(section?.id || `section_${index + 1}`).trim() || `section_${index + 1}`,
    title: String(section?.title || `分区${index + 1}`).trim() || `分区${index + 1}`,
    description: String(section?.description || ''),
    rows: Array.isArray(section?.rows) ? section.rows.map((row, i) => normalizeRow(row, i)) : []
  };
}

function ensureSelectedSection() {
  const sections = state.resume.profile.sections || [];
  if (!sections.length) {
    state.resume.selectedSectionId = '';
    return null;
  }
  const found = sections.find((s) => s.id === state.resume.selectedSectionId);
  if (found) return found;
  state.resume.selectedSectionId = sections[0].id;
  return sections[0];
}

function scheduleAutoSave() {
  if (resumeAutoSaveTimer) clearTimeout(resumeAutoSaveTimer);
  resumeAutoSaveTimer = window.setTimeout(() => {
    void saveResumeProfile({ silent: true });
  }, 700);
}

function updatePreview() {
  const el = byId('resumeJsonPreview');
  if (!el) return;
  el.value = JSON.stringify(state.resume.profile, null, 2);
}

function escAttr(text) {
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function escText(text) {
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function syncRowFromDom(sectionId, rowIndex, tr) {
  const section = state.resume.profile.sections.find((item) => item.id === sectionId);
  if (!section || !section.rows[rowIndex]) return;
  section.rows[rowIndex] = normalizeRow({
    ...section.rows[rowIndex],
    label: tr.querySelector('[data-k="label"]').value,
    value: tr.querySelector('[data-k="value"]').value,
    aliases: tr.querySelector('[data-k="aliases"]').value,
    type: tr.querySelector('[data-k="type"]').value
  }, rowIndex);
}

function renderSectionList() {
  const host = byId('resumeSections');
  host.innerHTML = '';

  for (const section of state.resume.profile.sections || []) {
    const btn = document.createElement('button');
    btn.className = 'resume-section-btn';
    if (section.id === state.resume.selectedSectionId) {
      btn.classList.add('active');
    }
    btn.textContent = section.title;
    btn.onclick = () => {
      state.resume.selectedSectionId = section.id;
      renderResumeEditor();
    };
    host.appendChild(btn);
  }
}

function renderRows(section) {
  const body = byId('resumeRows');
  body.innerHTML = '';

  section.rows.forEach((row, index) => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td><input type="text" data-k="label" value="${escAttr(row.label)}" /></td>
      <td>${row.type === 'textarea'
        ? `<textarea data-k="value">${escText(row.value)}</textarea>`
        : `<input type="text" data-k="value" value="${escAttr(row.value)}" />`}</td>
      <td><input type="text" data-k="aliases" value="${escAttr(row.aliases)}" /></td>
      <td>
        <select data-k="type">
          ${['text', 'textarea', 'date', 'select'].map((type) => `<option value="${type}"${type === row.type ? ' selected' : ''}>${type}</option>`).join('')}
        </select>
      </td>
      <td><button class="btn ghost" type="button" data-k="delete">删除</button></td>
    `;

    tr.querySelectorAll('input, textarea').forEach((el) => {
      el.addEventListener('input', () => {
        syncRowFromDom(section.id, index, tr);
        updatePreview();
        scheduleAutoSave();
      });
    });

    tr.querySelector('[data-k="type"]').addEventListener('change', () => {
      syncRowFromDom(section.id, index, tr);
      renderResumeEditor();
      scheduleAutoSave();
    });

    tr.querySelector('[data-k="delete"]').onclick = () => {
      section.rows.splice(index, 1);
      renderResumeEditor();
      scheduleAutoSave();
    };

    body.appendChild(tr);
  });
}

function renderResumeEditor() {
  const section = ensureSelectedSection();
  renderSectionList();

  const title = byId('resumeSectionTitle');
  const desc = byId('resumeSectionDesc');
  if (!section) {
    title.textContent = '简历自动填写';
    desc.textContent = '当前没有可编辑分区。';
    byId('resumeRows').innerHTML = '';
    updatePreview();
    return;
  }

  title.textContent = section.title;
  desc.textContent = section.description || '维护当前分区的字段。浏览器插件会按“字段名 + 别名”尝试匹配网页表单。';
  renderRows(section);
  updatePreview();
}

export function applyResumeState(payload) {
  const incoming = payload.resume || payload.state || {};
  const profile = incoming.profile || { version: 1, updated_at: '', sections: [] };

  state.resume.profile = {
    version: Number(profile.version || 1),
    updated_at: String(profile.updated_at || ''),
    sections: Array.isArray(profile.sections) ? profile.sections.map((section, index) => normalizeSection(section, index)) : []
  };
  state.resume.flat_map = incoming.flat_map || {};
  ensureSelectedSection();
  renderResumeEditor();
}

export async function saveResumeProfile(options = {}) {
  const silent = !!options.silent;
  const payload = await api('/api/resume/save', {
    method: 'POST',
    body: JSON.stringify({ profile: state.resume.profile })
  });
  if (!payload.ok) {
    throw new Error(payload.error || 'save resume failed');
  }
  applyResumeState({ resume: payload.state || state.resume });
  if (!silent) {
    toast('简历资料已保存');
  }
}

export function initResumeHandlers() {
  const addBtn = byId('resumeAddRowBtn');
  if (addBtn) {
    addBtn.onclick = () => {
      const section = ensureSelectedSection();
      if (!section) return;
      section.rows.push(normalizeRow({}, section.rows.length));
      renderResumeEditor();
      scheduleAutoSave();
    };
  }

  const saveBtn = byId('resumeSaveBtn');
  if (saveBtn) {
    saveBtn.onclick = () => saveResumeProfile().catch((e) => toast(`保存失败: ${e.message}`));
  }

  const copyBtn = byId('resumeCopyJsonBtn');
  if (copyBtn) {
    copyBtn.onclick = async () => {
      try {
        await navigator.clipboard.writeText(JSON.stringify(state.resume.profile, null, 2));
        toast('已复制 JSON');
      } catch (e) {
        toast(`复制失败: ${e.message}`);
      }
    };
  }
}
