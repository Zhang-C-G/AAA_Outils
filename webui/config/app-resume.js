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
  company: '',
  url: '',
  company_type: '',
  company_scale: '',
  job_type: '',
  progress: '',
  openKey: ''
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

function syncCompanyUrlButtonState(tr, rawUrl) {
  const buttonEl = tr.querySelector('[data-k="open-url"]');
  if (!buttonEl) return;
  const finalUrl = normalizeExternalUrl(rawUrl);
  buttonEl.disabled = !finalUrl;
  buttonEl.classList.toggle('disabled', !finalUrl);
}

function syncCompanySelectTheme(selectEl) {
  if (!selectEl) return;
  const value = String(selectEl.value || '').trim().toLowerCase();
  selectEl.dataset.value = value || 'empty';
}

function getSelectedCompanyRows() {
  return Array.from(document.querySelectorAll('#resumeCompanyRows [data-k="selected"]:checked'))
    .map((el) => Number(el.getAttribute('data-index')))
    .filter((index) => Number.isInteger(index) && index >= 0 && index < (state.resume.company_links || []).length);
}

function syncCompanyFilterUi() {
  const filterDefs = [
    ['company', 'resumeCompanyFilterCompanyBtn'],
    ['company_type', 'resumeCompanyFilterTypeBtn'],
    ['company_scale', 'resumeCompanyFilterScaleBtn'],
    ['job_type', 'resumeCompanyFilterJobTypeBtn'],
    ['progress', 'resumeCompanyFilterProgressBtn'],
    ['url', 'resumeCompanyFilterUrlBtn']
  ];

  filterDefs.forEach(([key, btnId]) => {
    const btn = byId(btnId);
    const hasValue = !!String(resumeCompanyFilters[key] || '').trim();
    const isOpen = resumeCompanyFilters.openKey === key;
    if (btn) {
      btn.classList.toggle('active', hasValue || isOpen);
      btn.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
    }
  });

  renderResumeCompanyFilterBar();
}

function renderCompanyFilterOptions() {
}

function getResumeCompanyFilterMeta() {
  return {
    company: {
      title: '公司名称筛选',
      render: () => `
        <label>
          <span>公司名称</span>
          <input id="resumeCompanyFilterCompany" type="text" placeholder="输入公司名称" value="${escAttr(resumeCompanyFilters.company)}" />
        </label>
      `
    },
    company_type: {
      title: '公司类型筛选',
      render: () => `
        <label>
          <span>公司类型</span>
          <select id="resumeCompanyFilterType">
            ${renderOptionList([{ value: '', label: '全部类型' }, ...COMPANY_TYPE_OPTIONS.slice(1)], resumeCompanyFilters.company_type)}
          </select>
        </label>
      `
    },
    company_scale: {
      title: '公司规模筛选',
      render: () => `
        <label>
          <span>公司规模</span>
          <select id="resumeCompanyFilterScale">
            ${renderOptionList([{ value: '', label: '全部规模' }, ...COMPANY_SCALE_OPTIONS.slice(1)], resumeCompanyFilters.company_scale)}
          </select>
        </label>
      `
    },
    job_type: {
      title: '岗位类型筛选',
      render: () => `
        <label>
          <span>岗位类型</span>
          <select id="resumeCompanyFilterJobType">
            ${renderOptionList([{ value: '', label: '全部岗位类型' }, ...COMPANY_JOB_TYPE_OPTIONS.slice(1)], resumeCompanyFilters.job_type)}
          </select>
        </label>
      `
    },
    progress: {
      title: '投递进度筛选',
      render: () => `
        <label>
          <span>投递进度</span>
          <select id="resumeCompanyFilterProgress">
            ${renderOptionList([{ value: '', label: '全部进度' }, ...COMPANY_PROGRESS_OPTIONS], resumeCompanyFilters.progress)}
          </select>
        </label>
      `
    },
    url: {
      title: '链接地址筛选',
      render: () => `
        <label>
          <span>链接地址</span>
          <input id="resumeCompanyFilterUrl" type="text" placeholder="输入链接关键词" value="${escAttr(resumeCompanyFilters.url)}" />
        </label>
      `
    }
  };
}

function renderResumeCompanyFilterBar() {
  const host = byId('resumeCompanyFilterBar');
  const title = byId('resumeCompanyFilterBarTitle');
  const body = byId('resumeCompanyFilterBarBody');
  if (!host || !title || !body) return;

  const meta = getResumeCompanyFilterMeta();
  const openKey = String(resumeCompanyFilters.openKey || '');
  if (!openKey || !meta[openKey]) {
    host.classList.add('hidden');
    body.innerHTML = '';
    return;
  }

  host.classList.remove('hidden');
  title.textContent = meta[openKey].title;
  body.innerHTML = meta[openKey].render();

  const bindings = [
    ['resumeCompanyFilterCompany', 'company', 'input'],
    ['resumeCompanyFilterType', 'company_type', 'change'],
    ['resumeCompanyFilterScale', 'company_scale', 'change'],
    ['resumeCompanyFilterJobType', 'job_type', 'change'],
    ['resumeCompanyFilterProgress', 'progress', 'change'],
    ['resumeCompanyFilterUrl', 'url', 'input']
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
}

function getFilteredCompanyLinks() {
  const companyKeyword = String(resumeCompanyFilters.company || '').trim().toLowerCase();
  const urlKeyword = String(resumeCompanyFilters.url || '').trim().toLowerCase();
  return (state.resume.company_links || [])
    .map((row, index) => ({ row, index }))
    .filter(({ row }) => {
      if (resumeCompanyFilters.company_type && row.company_type !== resumeCompanyFilters.company_type) return false;
      if (resumeCompanyFilters.company_scale && row.company_scale !== resumeCompanyFilters.company_scale) return false;
      if (resumeCompanyFilters.job_type && row.job_type !== resumeCompanyFilters.job_type) return false;
      if (resumeCompanyFilters.progress && row.progress !== resumeCompanyFilters.progress) return false;
      if (companyKeyword && !String(row.company || '').toLowerCase().includes(companyKeyword)) return false;
      if (urlKeyword && !String(row.url || '').toLowerCase().includes(urlKeyword)) return false;
      return true;
    });
}

function renderCompanyRows() {
  const body = byId('resumeCompanyRows');
  if (!body) return;
  body.innerHTML = '';
  syncCompanyFilterUi();

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
          <textarea data-k="url" placeholder="公司投递或招聘链接">${escText(row.url)}</textarea>
          <button class="resume-company-url-open" type="button" data-k="open-url" ${row.url ? '' : 'disabled'}>开</button>
        </div>
      </td>
      <td><button class="btn ghost" type="button" data-k="delete">删除</button></td>
    `;

    tr.querySelectorAll('textarea').forEach((el) => {
      autoResizeResumeTextarea(el);
    });
    tr.querySelector('[data-k="company_type"]').dataset.role = 'company_type';
    tr.querySelector('[data-k="company_scale"]').dataset.role = 'company_scale';
    tr.querySelector('[data-k="job_type"]').dataset.role = 'job_type';
    tr.querySelector('[data-k="progress"]').dataset.role = 'progress';
    tr.querySelectorAll('.resume-company-select').forEach((el) => {
      syncCompanySelectTheme(el);
    });
    syncCompanyUrlButtonState(tr, row.url);

    tr.querySelectorAll('textarea, select').forEach((el) => {
      el.addEventListener(el.tagName === 'SELECT' ? 'change' : 'input', () => {
        if (el.tagName === 'TEXTAREA') {
          autoResizeResumeTextarea(el);
        } else {
          syncCompanySelectTheme(el);
        }
        syncCompanyRowFromDom(index, tr);
        if (el.getAttribute('data-k') === 'url') {
          syncCompanyUrlButtonState(tr, el.value);
        }
        scheduleAutoSave();
      });
    });

    tr.querySelector('[data-k="open-url"]').onclick = () => {
      const currentUrl = tr.querySelector('[data-k="url"]')?.value;
      const finalUrl = normalizeExternalUrl(currentUrl);
      if (!finalUrl) {
        toast('当前还没有可用链接');
        return;
      }
      window.open(finalUrl, '_blank', 'noopener');
    };

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

function setResumeCompanyFilterOpen(key) {
  resumeCompanyFilters.openKey = resumeCompanyFilters.openKey === key ? '' : key;
  syncCompanyFilterUi();
}

function initCompanyFilterHandlers() {
  [
    ['resumeCompanyFilterCompanyBtn', 'company'],
    ['resumeCompanyFilterTypeBtn', 'company_type'],
    ['resumeCompanyFilterScaleBtn', 'company_scale'],
    ['resumeCompanyFilterJobTypeBtn', 'job_type'],
    ['resumeCompanyFilterProgressBtn', 'progress'],
    ['resumeCompanyFilterUrlBtn', 'url']
  ].forEach(([id, key]) => {
    const el = byId(id);
    if (!el || el.dataset.bound === '1') return;
    el.dataset.bound = '1';
    el.onclick = (event) => {
      event.stopPropagation();
      setResumeCompanyFilterOpen(key);
    };
  });

  const resetBtn = byId('resumeCompanyFilterResetBtn');
  if (resetBtn && resetBtn.dataset.bound !== '1') {
    resetBtn.dataset.bound = '1';
    resetBtn.onclick = () => {
      resumeCompanyFilters.company = '';
      resumeCompanyFilters.url = '';
      resumeCompanyFilters.company_type = '';
      resumeCompanyFilters.company_scale = '';
      resumeCompanyFilters.job_type = '';
      resumeCompanyFilters.progress = '';
      resumeCompanyFilters.openKey = '';
      renderCompanyRows();
    };
  }

  const closeBtn = byId('resumeCompanyFilterBarCloseBtn');
  if (closeBtn && closeBtn.dataset.bound !== '1') {
    closeBtn.dataset.bound = '1';
    closeBtn.onclick = () => {
      resumeCompanyFilters.openKey = '';
      syncCompanyFilterUi();
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
