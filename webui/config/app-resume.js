import { state, byId, api, toast } from './app-common.js';

let resumeAutoSaveTimer = 0;

const RESUME_EDITOR_MODES = {
  PROFILE: 'profile',
  COMPANIES: 'companies'
};

const COMPANY_TYPE_OPTIONS = [
  { value: '', label: '未选择' },
  { value: 'state_owned', label: '国企' },
  { value: 'private', label: '民企' },
  { value: 'foreign', label: '外企' }
];

const COMPANY_SCALE_OPTIONS = [
  { value: '', label: '未选择' },
  { value: 'large', label: '大' },
  { value: 'medium', label: '中' },
  { value: 'small', label: '小' }
];

const COMPANY_JOB_TYPE_OPTIONS = [
  { value: '', label: '未选择' },
  { value: 'daily_intern', label: '日常实习' },
  { value: 'conversion_intern', label: '转正实习' },
  { value: 'full_time', label: '正式工作' }
];

const COMPANY_PROGRESS_OPTIONS = [
  { value: 'not_applied', label: '未投递' },
  { value: 'applied', label: '已投递' },
  { value: 'rejected', label: '已挂' },
  { value: 'first_interview', label: '已经一面' },
  { value: 'second_interview', label: '已经二面' },
  { value: 'offer', label: 'OFFER' },
  { value: 'paused', label: '暂不投递' }
];

const resumeCompanyFilters = {
  keyword: '',
  company_type: '',
  company_scale: '',
  job_type: '',
  progress: ''
};

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
    rows: Array.isArray(section?.rows) ? section.rows.map((row, i) => normalizeRow(row, i)) : []
  };
}

function normalizeCompanyLink(row, index = 0) {
  const type = String(row?.company_type || '').trim().toLowerCase();
  const scale = String(row?.company_scale || '').trim().toLowerCase();
  const jobType = String(row?.job_type || '').trim().toLowerCase();
  const progress = String(row?.progress || 'not_applied').trim().toLowerCase();
  return {
    id: String(row?.id || `company_${index + 1}`).trim() || `company_${index + 1}`,
    company: String(row?.company || '').trim(),
    url: String(row?.url || '').trim(),
    company_type: COMPANY_TYPE_OPTIONS.some((item) => item.value === type) ? type : '',
    company_scale: COMPANY_SCALE_OPTIONS.some((item) => item.value === scale) ? scale : '',
    job_type: COMPANY_JOB_TYPE_OPTIONS.some((item) => item.value === jobType) ? jobType : '',
    progress: COMPANY_PROGRESS_OPTIONS.some((item) => item.value === progress) ? progress : 'not_applied'
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
  el.style.height = `${Math.max(el.scrollHeight, 72)}px`;
}

function normalizeExternalUrl(rawUrl) {
  const value = String(rawUrl || '').trim();
  if (!value) return '';
  return /^https?:\/\//i.test(value) ? value : `https://${value}`;
}

function renderOptionList(options, selectedValue) {
  return options
    .map((item) => `<option value="${escAttr(item.value)}" ${item.value === selectedValue ? 'selected' : ''}>${escText(item.label)}</option>`)
    .join('');
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
      <td><button class="btn ghost" type="button" data-k="delete">删除</button></td>
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
    company_type: tr.querySelector('[data-k="company_type"]').value,
    company_scale: tr.querySelector('[data-k="company_scale"]').value,
    job_type: tr.querySelector('[data-k="job_type"]').value,
    progress: tr.querySelector('[data-k="progress"]').value
  }, index);
}

function syncCompanyUrlPreview(tr, rawUrl) {
  const linkEl = tr.querySelector('[data-k="url-preview"]');
  if (!linkEl) return;
  const finalUrl = normalizeExternalUrl(rawUrl);
  if (!finalUrl) {
    linkEl.textContent = '暂无链接';
    linkEl.removeAttribute('href');
    linkEl.setAttribute('aria-disabled', 'true');
    linkEl.classList.add('disabled');
    return;
  }
  linkEl.textContent = finalUrl;
  linkEl.href = finalUrl;
  linkEl.removeAttribute('aria-disabled');
  linkEl.classList.remove('disabled');
}

function getSelectedCompanyRows() {
  return Array.from(document.querySelectorAll('#resumeCompanyRows [data-k="selected"]:checked'))
    .map((el) => Number(el.getAttribute('data-index')))
    .filter((index) => Number.isInteger(index) && index >= 0 && index < (state.resume.company_links || []).length);
}

function syncCompanyFilterBar() {
  const keywordEl = byId('resumeCompanyFilterKeyword');
  const typeEl = byId('resumeCompanyFilterType');
  const scaleEl = byId('resumeCompanyFilterScale');
  const jobTypeEl = byId('resumeCompanyFilterJobType');
  const progressEl = byId('resumeCompanyFilterProgress');
  if (keywordEl) keywordEl.value = resumeCompanyFilters.keyword;
  if (typeEl) typeEl.value = resumeCompanyFilters.company_type;
  if (scaleEl) scaleEl.value = resumeCompanyFilters.company_scale;
  if (jobTypeEl) jobTypeEl.value = resumeCompanyFilters.job_type;
  if (progressEl) progressEl.value = resumeCompanyFilters.progress;
}

function renderCompanyFilterOptions() {
  const typeEl = byId('resumeCompanyFilterType');
  const scaleEl = byId('resumeCompanyFilterScale');
  const jobTypeEl = byId('resumeCompanyFilterJobType');
  const progressEl = byId('resumeCompanyFilterProgress');
  if (typeEl && !typeEl.dataset.ready) {
    typeEl.innerHTML = renderOptionList([{ value: '', label: '全部类型' }, ...COMPANY_TYPE_OPTIONS.slice(1)], resumeCompanyFilters.company_type);
    typeEl.dataset.ready = '1';
  }
  if (scaleEl && !scaleEl.dataset.ready) {
    scaleEl.innerHTML = renderOptionList([{ value: '', label: '全部规模' }, ...COMPANY_SCALE_OPTIONS.slice(1)], resumeCompanyFilters.company_scale);
    scaleEl.dataset.ready = '1';
  }
  if (jobTypeEl && !jobTypeEl.dataset.ready) {
    jobTypeEl.innerHTML = renderOptionList([{ value: '', label: '全部岗位类型' }, ...COMPANY_JOB_TYPE_OPTIONS.slice(1)], resumeCompanyFilters.job_type);
    jobTypeEl.dataset.ready = '1';
  }
  if (progressEl && !progressEl.dataset.ready) {
    progressEl.innerHTML = renderOptionList([{ value: '', label: '全部进度' }, ...COMPANY_PROGRESS_OPTIONS], resumeCompanyFilters.progress);
    progressEl.dataset.ready = '1';
  }
}

function getFilteredCompanyLinks() {
  const keyword = String(resumeCompanyFilters.keyword || '').trim().toLowerCase();
  return (state.resume.company_links || [])
    .map((row, index) => ({ row, index }))
    .filter(({ row }) => {
      if (resumeCompanyFilters.company_type && row.company_type !== resumeCompanyFilters.company_type) return false;
      if (resumeCompanyFilters.company_scale && row.company_scale !== resumeCompanyFilters.company_scale) return false;
      if (resumeCompanyFilters.job_type && row.job_type !== resumeCompanyFilters.job_type) return false;
      if (resumeCompanyFilters.progress && row.progress !== resumeCompanyFilters.progress) return false;
      if (!keyword) return true;
      const haystack = [row.company, row.url].join(' ').toLowerCase();
      return haystack.includes(keyword);
    });
}

function renderCompanyRows() {
  const body = byId('resumeCompanyRows');
  if (!body) return;
  body.innerHTML = '';
  renderCompanyFilterOptions();
  syncCompanyFilterBar();

  const visibleRows = getFilteredCompanyLinks();
  if (!visibleRows.length) {
    body.innerHTML = '<tr><td colspan="8" class="resume-company-empty">当前筛选条件下没有公司记录</td></tr>';
    return;
  }

  for (const { index, row } of visibleRows) {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td class="resume-company-select-cell"><input type="checkbox" data-k="selected" data-index="${index}" aria-label="选择公司 ${escAttr(row.company || `公司${index + 1}`)}" /></td>
      <td><textarea data-k="company" placeholder="公司名称">${escText(row.company)}</textarea></td>
      <td>
        <select data-k="company_type" class="resume-company-select">
          ${renderOptionList(COMPANY_TYPE_OPTIONS, row.company_type)}
        </select>
      </td>
      <td>
        <select data-k="company_scale" class="resume-company-select">
          ${renderOptionList(COMPANY_SCALE_OPTIONS, row.company_scale)}
        </select>
      </td>
      <td>
        <select data-k="job_type" class="resume-company-select">
          ${renderOptionList(COMPANY_JOB_TYPE_OPTIONS, row.job_type)}
        </select>
      </td>
      <td>
        <select data-k="progress" class="resume-company-select">
          ${renderOptionList(COMPANY_PROGRESS_OPTIONS, row.progress)}
        </select>
      </td>
      <td>
        <div class="resume-company-url-cell">
          <a data-k="url-preview" class="resume-company-url-link ${row.url ? '' : 'disabled'}" ${row.url ? `href="${escAttr(normalizeExternalUrl(row.url))}" target="_blank" rel="noopener noreferrer"` : 'aria-disabled="true"'}>${escText(row.url ? normalizeExternalUrl(row.url) : '暂无链接')}</a>
          <textarea data-k="url" placeholder="公司投递或招聘链接">${escText(row.url)}</textarea>
        </div>
      </td>
      <td><button class="btn ghost" type="button" data-k="delete">删除</button></td>
    `;

    tr.querySelectorAll('textarea').forEach((el) => {
      autoResizeResumeTextarea(el);
    });

    tr.querySelectorAll('textarea, select').forEach((el) => {
      el.addEventListener(el.tagName === 'SELECT' ? 'change' : 'input', () => {
        if (el.tagName === 'TEXTAREA') {
          autoResizeResumeTextarea(el);
        }
        syncCompanyRowFromDom(index, tr);
        if (el.getAttribute('data-k') === 'url') {
          syncCompanyUrlPreview(tr, el.value);
        }
        scheduleAutoSave();
      });
    });

    tr.querySelector('[data-k="delete"]').onclick = () => {
      state.resume.company_links.splice(index, 1);
      renderResumeEditor();
      scheduleAutoSave();
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
    if (title) title.textContent = '简历自动填写';
    byId('resumeRows').innerHTML = '';
    renderCompanyRows();
    renderResumeSubview();
    return;
  }

  if (title) title.textContent = section.title;
  renderRows(section);
  renderCompanyRows();
  renderResumeSubview();
}

function initCompanyFilterHandlers() {
  const bindings = [
    ['resumeCompanyFilterKeyword', 'keyword', 'input'],
    ['resumeCompanyFilterType', 'company_type', 'change'],
    ['resumeCompanyFilterScale', 'company_scale', 'change'],
    ['resumeCompanyFilterJobType', 'job_type', 'change'],
    ['resumeCompanyFilterProgress', 'progress', 'change']
  ];

  bindings.forEach(([id, key, evt]) => {
    const el = byId(id);
    if (!el || el.dataset.bound === '1') return;
    el.dataset.bound = '1';
    el.addEventListener(evt, () => {
      resumeCompanyFilters[key] = String(el.value || '');
      renderCompanyRows();
    });
  });

  const resetBtn = byId('resumeCompanyFilterResetBtn');
  if (resetBtn && resetBtn.dataset.bound !== '1') {
    resetBtn.dataset.bound = '1';
    resetBtn.onclick = () => {
      resumeCompanyFilters.keyword = '';
      resumeCompanyFilters.company_type = '';
      resumeCompanyFilters.company_scale = '';
      resumeCompanyFilters.job_type = '';
      resumeCompanyFilters.progress = '';
      renderCompanyRows();
    };
  }
}

function openSelectedCompanyLinks() {
  ensureCompanyLinks();
  const indexes = getSelectedCompanyRows();
  if (!indexes.length) {
    toast('请先选择要投递的公司');
    return;
  }

  const selectedRows = indexes
    .map((index) => state.resume.company_links[index])
    .filter(Boolean);
  const validRows = selectedRows.filter((row) => String(row.url || '').trim());
  if (!validRows.length) {
    toast('选中的公司里还没有可用链接');
    return;
  }

  validRows.forEach((row) => {
    const finalUrl = normalizeExternalUrl(row.url);
    window.open(finalUrl, '_blank', 'noopener');
  });

  let hasChanged = false;
  selectedRows.forEach((row) => {
    if (row.progress !== 'applied') {
      row.progress = 'applied';
      hasChanged = true;
    }
  });

  renderCompanyRows();
  if (hasChanged) {
    scheduleAutoSave();
  }
  toast(`已打开 ${validRows.length} 个投递链接`);
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
  state.resume.company_links = Array.isArray(incoming.company_links)
    ? incoming.company_links.map((row, index) => normalizeCompanyLink(row, index))
    : (Array.isArray(state.resume.company_links) ? state.resume.company_links.map((row, index) => normalizeCompanyLink(row, index)) : []);
  state.resume.editor_mode = String(incoming.editor_mode || state.resume.editor_mode || RESUME_EDITOR_MODES.PROFILE);
  ensureSelectedSection();
  renderResumeEditor();
}

export async function saveResumeProfile(options = {}) {
  const silent = !!options.silent;
  ensureCompanyLinks();
  const payload = await api('/api/resume/save', {
    method: 'POST',
    body: JSON.stringify({
      profile: state.resume.profile,
      company_links: state.resume.company_links,
      editor_mode: state.resume.editor_mode
    })
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
  initCompanyFilterHandlers();
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
      scheduleAutoSave();
    };
  }

  const applyBtn = byId('resumeApplySelectedCompaniesBtn');
  if (applyBtn) {
    applyBtn.onclick = () => {
      openSelectedCompanyLinks();
    };
  }
}
