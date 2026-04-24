import { state, byId, api, toast } from './app-common.js';

let resumeAutoSaveTimer = 0;

function normalizeRow(row, index = 0) {
  const type = String(row?.type || 'text').trim().toLowerCase();
  return {
    id: String(row?.id || `field_${index + 1}`).trim() || `field_${index + 1}`,
    label: String(row?.label || `\u5b57\u6bb5${index + 1}`).trim() || `\u5b57\u6bb5${index + 1}`,
    value: String(row?.value || ''),
    aliases: String(row?.aliases || ''),
    type: ['text', 'textarea', 'select', 'date'].includes(type) ? type : 'text'
  };
}

function normalizeSection(section, index = 0) {
  return {
    id: String(section?.id || `section_${index + 1}`).trim() || `section_${index + 1}`,
    title: String(section?.title || `\u5206\u533a${index + 1}`).trim() || `\u5206\u533a${index + 1}`,
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
    value: tr.querySelector('[data-k="value"]').value
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
      <td><textarea data-k="value">${escText(row.value)}</textarea></td>
      <td><button class="btn ghost" type="button" data-k="delete">\u5220\u9664</button></td>
    `;

    tr.querySelectorAll('input, textarea').forEach((el) => {
      el.addEventListener('input', () => {
        syncRowFromDom(section.id, index, tr);
        scheduleAutoSave();
      });
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
    title.textContent = '\u7b80\u5386\u81ea\u52a8\u586b\u5199';
    desc.textContent = '\u5f53\u524d\u6ca1\u6709\u53ef\u7f16\u8f91\u5206\u533a\u3002';
    byId('resumeRows').innerHTML = '';
    return;
  }

  title.textContent = section.title;
  desc.textContent = section.description || '\u7ef4\u62a4\u5f53\u524d\u5206\u533a\u7684\u5b57\u6bb5\u540d\u548c\u503c\uff0c\u522b\u540d\u4e0e\u5339\u914d\u89c4\u5219\u7531\u540e\u7aef\u8868\u7ef4\u62a4\u3002';
  renderRows(section);
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
    toast('\u7b80\u5386\u8d44\u6599\u5df2\u4fdd\u5b58');
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
    saveBtn.onclick = () => saveResumeProfile().catch((e) => toast(`\u4fdd\u5b58\u5931\u8d25: ${e.message}`));
  }
}
