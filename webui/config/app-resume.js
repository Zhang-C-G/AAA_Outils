import { state, byId, api, toast } from './app-common.js';

let resumeAutoSaveTimer = 0;
const RESUME_EDITOR_MODES = {
  PROFILE: 'profile',
  COMPANIES: 'companies'
};

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
    rows: Array.isArray(section?.rows) ? section.rows.map((row, i) => normalizeRow(row, i)) : []
  };
}

function normalizeCompanyLink(row, index = 0) {
  return {
    id: String(row?.id || `company_${index + 1}`).trim() || `company_${index + 1}`,
    company: String(row?.company || '').trim(),
    url: String(row?.url || '').trim(),
    enabled: Number(row?.enabled ?? 1) === 0 ? 0 : 1
  };
}

function ensureResumeEditorMode() {
  const mode = String(state.resume.editor_mode || '').trim().toLowerCase();
  state.resume.editor_mode = mode === RESUME_EDITOR_MODES.COMPANIES
    ? RESUME_EDITOR_MODES.COMPANIES
    : RESUME_EDITOR_MODES.PROFILE;
}

function ensureCompanyLinks() {
  const list = Array.isArray(state.resume.company_links) ? state.resume.company_links : [];
  state.resume.company_links = list.map((item, index) => normalizeCompanyLink(item, index));
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

function autoResizeResumeTextarea(el) {
  if (!el) return;
  el.style.height = 'auto';
  el.style.height = `${Math.max(el.scrollHeight, 38)}px`;
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

    autoResizeResumeTextarea(tr.querySelector('[data-k="value"]'));

    tr.querySelectorAll('input, textarea').forEach((el) => {
      el.addEventListener('input', () => {
        if (el.tagName === 'TEXTAREA') {
          autoResizeResumeTextarea(el);
        }
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

function syncCompanyRowFromDom(index, tr) {
  if (!Array.isArray(state.resume.company_links) || !state.resume.company_links[index]) return;
  state.resume.company_links[index] = normalizeCompanyLink({
    ...state.resume.company_links[index],
    company: tr.querySelector('[data-k="company"]').value,
    url: tr.querySelector('[data-k="url"]').value,
    enabled: tr.querySelector('[data-k="enabled"]').checked ? 1 : 0
  }, index);
}

function renderCompanyRows() {
  const body = byId('resumeCompanyRows');
  if (!body) return;
  body.innerHTML = '';

  for (const [index, row] of (state.resume.company_links || []).entries()) {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td><input type="text" data-k="company" value="${escAttr(row.company)}" placeholder="公司名" /></td>
      <td><input type="text" data-k="url" value="${escAttr(row.url)}" placeholder="公司投递或招聘链接" /></td>
      <td><label class="resume-company-toggle"><input type="checkbox" data-k="enabled" ${row.enabled ? 'checked' : ''} /><span>可填充</span></label></td>
      <td><button class="btn ghost" type="button" data-k="delete">删除</button></td>
    `;

    tr.querySelectorAll('input').forEach((el) => {
      const evt = el.type === 'checkbox' ? 'change' : 'input';
      el.addEventListener(evt, () => {
        syncCompanyRowFromDom(index, tr);
      });
    });

    tr.querySelector('[data-k="delete"]').onclick = () => {
      state.resume.company_links.splice(index, 1);
      renderResumeEditor();
    };

    body.appendChild(tr);
  }
}

function renderResumeSubview() {
  ensureResumeEditorMode();
  const isCompanies = state.resume.editor_mode === RESUME_EDITOR_MODES.COMPANIES;
  byId('resumeProfilePanel')?.classList.toggle('hidden', isCompanies);
  byId('resumeCompanyPanel')?.classList.toggle('hidden', !isCompanies);

  const label = byId('resumeEntryBarLabel');
  const btn = byId('resumeToggleCompanyViewBtn');
  const title = byId('resumeSectionTitle');

  if (label) {
    label.textContent = isCompanies ? '返回简历字段界面：' : '进入公司链接界面：';
  }
  if (btn) {
    btn.textContent = isCompanies ? '点击返回' : '点击进入';
    btn.classList.toggle('active', isCompanies);
  }
  if (title && isCompanies) {
    title.textContent = '公司链接维护';
  }
}

function renderResumeEditor() {
  const section = ensureSelectedSection();
  ensureCompanyLinks();
  ensureResumeEditorMode();
  renderSectionList();

  const title = byId('resumeSectionTitle');
  if (!section) {
    title.textContent = '\u7b80\u5386\u81ea\u52a8\u586b\u5199';
    byId('resumeRows').innerHTML = '';
    renderCompanyRows();
    renderResumeSubview();
    return;
  }

  title.textContent = section.title;
  renderRows(section);
  renderCompanyRows();
  renderResumeSubview();
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
  state.resume.company_links = Array.isArray(state.resume.company_links) ? state.resume.company_links : [];
  state.resume.editor_mode = String(state.resume.editor_mode || RESUME_EDITOR_MODES.PROFILE);
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
  const toggleCompanyBtn = byId('resumeToggleCompanyViewBtn');
  if (toggleCompanyBtn) {
    toggleCompanyBtn.onclick = () => {
      ensureResumeEditorMode();
      state.resume.editor_mode = state.resume.editor_mode === RESUME_EDITOR_MODES.COMPANIES
        ? RESUME_EDITOR_MODES.PROFILE
        : RESUME_EDITOR_MODES.COMPANIES;
      renderResumeEditor();
    };
  }

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

  const addCompanyBtn = byId('resumeAddCompanyRowBtn');
  if (addCompanyBtn) {
    addCompanyBtn.onclick = () => {
      ensureCompanyLinks();
      state.resume.company_links.push(normalizeCompanyLink({}, state.resume.company_links.length));
      renderResumeEditor();
    };
  }
}
