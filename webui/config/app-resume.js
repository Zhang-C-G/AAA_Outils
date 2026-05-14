import { state, byId, api, toast } from './app-common.js';

let resumeAutoSaveTimer = 0;
let resumeAutoSaveNotifyPending = false;

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
  applied_date: '',
  openKeys: []
};

const DEFAULT_COMPANY_PAGE_SIZE = 10;
const COMPANY_PAGE_SIZE_OPTIONS = [5, 10, 20];
let resumeExtensionInstallState = null;
let resumeExtensionGuideLoaded = false;

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
  const appliedDate = String(row?.applied_date || '').trim();
  return {
    id: String(row?.id || `company_${index + 1}`).trim() || `company_${index + 1}`,
    company: String(row?.company || '').trim(),
    url: String(row?.url || '').trim(),
    company_type: COMPANY_TYPE_OPTIONS.some((item) => item.value === type) ? type : '',
    company_scale: COMPANY_SCALE_OPTIONS.some((item) => item.value === scale) ? scale : '',
    job_type: COMPANY_JOB_TYPE_OPTIONS.some((item) => item.value === jobType) ? jobType : '',
    progress: COMPANY_PROGRESS_OPTIONS.some((item) => item.value === progress) ? progress : 'not_applied',
    applied_date: /^\d{4}-\d{2}-\d{2}$/.test(appliedDate) ? appliedDate : ''
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

function ensureCompanyTableView() {
  const view = state.resume.company_table_view || {};
  const pageSize = Number(view.page_size || DEFAULT_COMPANY_PAGE_SIZE);
  state.resume.company_table_view = {
    page: Math.max(1, Number(view.page || 1) || 1),
    page_size: COMPANY_PAGE_SIZE_OPTIONS.includes(pageSize) ? pageSize : DEFAULT_COMPANY_PAGE_SIZE
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

function notifyResumeChange(message = '简历信息已变更，正在自动保存...') {
  resumeAutoSaveNotifyPending = true;
  toast.info(message, {
    dedupeKey: 'resume-autosave-pending',
    duration: 1400
  });
}

function scheduleAutoSave(options = {}) {
  if (options.notify) {
    notifyResumeChange(options.message);
  }
  if (resumeAutoSaveTimer) clearTimeout(resumeAutoSaveTimer);
  resumeAutoSaveTimer = window.setTimeout(() => {
    const shouldNotify = resumeAutoSaveNotifyPending;
    resumeAutoSaveNotifyPending = false;
    void saveResumeProfile({ silent: true, autoNotify: shouldNotify }).catch((error) => {
      toast.error(`简历自动保存失败: ${error.message}`, {
        dedupeKey: 'resume-autosave-failed'
      });
    });
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

function autoResizeResumeTextarea(el, minHeight = 72) {
  if (!el) return;
  el.style.height = 'auto';
  el.style.height = `${Math.max(el.scrollHeight, minHeight)}px`;
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

function fallbackCopyText(text) {
  const temp = document.createElement('textarea');
  temp.value = String(text || '');
  temp.setAttribute('readonly', 'readonly');
  temp.style.position = 'fixed';
  temp.style.opacity = '0';
  temp.style.pointerEvents = 'none';
  document.body.appendChild(temp);
  temp.select();
  temp.setSelectionRange(0, temp.value.length);
  let copied = false;
  try {
    copied = document.execCommand('copy');
  } catch {
    copied = false;
  }
  document.body.removeChild(temp);
  return copied;
}

function renderResumeExtensionGuideState() {
  const pathEl = byId('resumeExtensionGuidePath');
  const statusEl = byId('resumeExtensionGuidePathStatus');
  const copyBtn = byId('resumeExtensionGuideCopyBtn');
  if (!pathEl || !statusEl || !copyBtn) return;

  const detectedPath = String(resumeExtensionInstallState?.extension_dir || '').trim();
  const exists = resumeExtensionInstallState?.exists !== false;
  pathEl.textContent = detectedPath || '未识别到插件目录';
  statusEl.textContent = detectedPath
    ? (exists ? '已自动识别到本机扩展目录，直接复制后在 Chrome 里选择这个文件夹即可。' : '已给出推测目录，但当前目录不存在，请先检查项目文件是否完整。')
    : '暂时没有拿到本机扩展目录，请稍后重试或手动定位 browser_extension/resume_autofill。';
  copyBtn.disabled = !detectedPath;
}

async function loadResumeExtensionInstallState(forceReload = false) {
  if (!forceReload && resumeExtensionInstallState) return resumeExtensionInstallState;
  const payload = await api('/api/resume/extension-install');
  if (!payload.ok) {
    throw new Error(payload.error || 'load extension install state failed');
  }
  resumeExtensionInstallState = payload.state || {};
  renderResumeExtensionGuideState();
  return resumeExtensionInstallState;
}

function closeResumeExtensionGuide() {
  byId('resumeExtensionGuideHost')?.classList.add('hidden');
}

async function openResumeExtensionGuide() {
  byId('resumeExtensionGuideHost')?.classList.remove('hidden');
  renderResumeExtensionGuideState();
  try {
    await loadResumeExtensionInstallState(true);
  } catch (error) {
    renderResumeExtensionGuideState();
    toast.error(`插件目录识别失败: ${error.message}`);
  }
}

async function copyResumeExtensionDir() {
  const text = String(resumeExtensionInstallState?.extension_dir || '').trim();
  if (!text) {
    toast.warning('当前没有可复制的插件目录');
    return;
  }

  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
    } else if (!fallbackCopyText(text)) {
      throw new Error('clipboard unavailable');
    }
    toast.success('插件目录已复制');
  } catch (error) {
    if (fallbackCopyText(text)) {
      toast.success('插件目录已复制');
      return;
    }
    toast.error(`复制失败: ${error.message}`);
  }
}

function openChromeExtensionsPage() {
  void (async () => {
    try {
      const payload = await api('/api/resume/open-extension-page', { method: 'POST', body: '{}' });
      if (!payload.ok) {
        throw new Error(payload.error || 'open extension page failed');
      }
      toast.success('已尝试打开 Chrome 扩展页');
    } catch (error) {
      toast.error(`打开扩展页失败: ${error.message}`);
    }
  })();
}

async function openResumeExtensionFolder() {
  try {
    const payload = await api('/api/resume/open-extension-folder', { method: 'POST', body: '{}' });
    if (!payload.ok) {
      throw new Error(payload.error || 'open extension folder failed');
    }
    toast.success('已打开插件目录');
  } catch (error) {
    toast.error(`打开插件目录失败: ${error.message}`);
  }
}

function syncRowFromDom(sectionId, rowIndex, tr) {
  const section = state.resume.profile.sections.find((item) => item.id === sectionId);
  if (!section || !section.rows[rowIndex]) return;
  const valueEl = tr.querySelector(`[data-k="value"][data-row-index="${rowIndex}"]`);
  if (!valueEl) return;
  section.rows[rowIndex] = normalizeRow({
    ...section.rows[rowIndex],
    label: section.rows[rowIndex].label,
    value: valueEl.value
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

function shouldUseResumeMultilineValue(row) {
  if (!row) return false;

  const rowId = String(row.id || '').trim().toLowerCase();
  const type = String(row.type || 'text').trim().toLowerCase();
  const label = String(row.label || '').trim();
  const value = String(row.value || '');

  if (type === 'textarea') return true;
  if (type === 'text' || type === 'date' || type === 'select') return false;

  if (value.includes('\n')) return true;
  if (/(^|_)(desc|intro|summary|content|courses?)$/i.test(rowId)) return true;
  if (/(描述|介绍|说明|内容|职责|亮点|总结|课程|经历)/.test(label)) {
    return true;
  }
  if (value.length >= 80) return true;
  return false;
}

function renderResumeValueControl(row, index) {
  const value = escText(row?.value || '');
  const multiline = shouldUseResumeMultilineValue(row);
  if (multiline) {
    return `<textarea class="resume-profile-value resume-profile-value-multiline" data-k="value" data-row-index="${index}">${value}</textarea>`;
  }
  return `<input class="resume-profile-value resume-profile-value-singleline" data-k="value" data-row-index="${index}" type="text" value="${escAttr(row?.value || '')}" />`;
}

function isEducationSection(sectionId) {
  return String(sectionId || '').trim().toLowerCase() === 'education';
}

function isEducationEntryRow(row) {
  return String(row?.id || '').startsWith('education_entry_');
}

function buildEducationEntryTemplate(index) {
  return [
    `学校名称：`,
    `学院名称：`,
    `学校所在城市：`,
    `入学日期：`,
    `毕业日期：`,
    `学历：`,
    `专业：`,
    `GPA：`,
    `成绩排名：`,
    `次专业：`,
    `研究方向：`,
    `导师：`,
    `专业主要课程：`
  ].join('\n');
}

function reindexEducationEntryRows(section) {
  if (!section || !Array.isArray(section.rows)) return;
  let count = 0;
  section.rows = section.rows.map((row, index) => {
    if (!isEducationEntryRow(row)) return normalizeRow(row, index);
    count += 1;
    return normalizeRow({
      ...row,
      id: `education_entry_${String(count).padStart(2, '0')}`,
      label: `教育经历${String(count).padStart(2, '0')}`
    }, index);
  });
}

function addEducationEntry() {
  const section = state.resume.profile.sections.find((item) => item.id === 'education');
  if (!section) return;
  const currentCount = section.rows.filter((row) => isEducationEntryRow(row)).length;
  section.rows.push(normalizeRow({
    id: `education_entry_${String(currentCount + 1).padStart(2, '0')}`,
    label: `教育经历${String(currentCount + 1).padStart(2, '0')}`,
    value: buildEducationEntryTemplate(currentCount + 1),
    aliases: `教育经历${String(currentCount + 1).padStart(2, '0')}`,
    type: 'textarea'
  }, section.rows.length));
  reindexEducationEntryRows(section);
  renderResumeEditor();
  scheduleAutoSave({ notify: true, message: '已新增一条教育经历，正在自动保存...' });
}

function removeEducationEntry(rowIndex) {
  const section = state.resume.profile.sections.find((item) => item.id === 'education');
  if (!section || !section.rows[rowIndex] || !isEducationEntryRow(section.rows[rowIndex])) return;
  section.rows.splice(rowIndex, 1);
  reindexEducationEntryRows(section);
  renderResumeEditor();
  scheduleAutoSave({ notify: true, message: '已删除一条教育经历，正在自动保存...' });
}

function renderSectionActions(section) {
  const host = byId('resumeSectionActions');
  if (!host) return;
  if (!section || !isEducationSection(section.id)) {
    host.classList.add('hidden');
    host.innerHTML = '';
    return;
  }
  host.classList.remove('hidden');
  host.innerHTML = `
    <div class="resume-section-inline-tools">
      <button id="resumeAddEducationEntryBtn" class="btn ghost" type="button">新增教育经历</button>
    </div>
  `;
  host.querySelector('#resumeAddEducationEntryBtn')?.addEventListener('click', () => {
    addEducationEntry();
  });
}

function renderRows(section) {
  const body = byId('resumeRows');
  body.innerHTML = '';
  renderSectionActions(section);

  for (let index = 0; index < section.rows.length; index += 2) {
    const left = section.rows[index];
    const right = section.rows[index + 1] || null;
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td class="resume-profile-label-cell">
        <div class="resume-profile-label-row">
          <div class="resume-profile-label">${escText(left.label)}</div>
          ${isEducationEntryRow(left) ? `<button class="resume-row-action-btn" data-k="delete-education-entry" data-row-index="${index}" type="button">删除</button>` : ''}
        </div>
      </td>
      <td class="resume-profile-value-cell">${renderResumeValueControl(left, index)}</td>
      ${right ? `
      <td class="resume-profile-label-cell">
        <div class="resume-profile-label-row">
          <div class="resume-profile-label">${escText(right.label)}</div>
          ${isEducationEntryRow(right) ? `<button class="resume-row-action-btn" data-k="delete-education-entry" data-row-index="${index + 1}" type="button">删除</button>` : ''}
        </div>
      </td>
      <td class="resume-profile-value-cell">${renderResumeValueControl(right, index + 1)}</td>
      ` : `
      <td class="resume-profile-label-cell resume-profile-empty-cell"></td>
      <td class="resume-profile-value-cell resume-profile-empty-cell"></td>
      `}
    `;

    tr.querySelectorAll('[data-k="value"]').forEach((el) => {
      el.addEventListener('input', () => {
        const rowIndex = Number(el.dataset.rowIndex || -1);
        if (Number.isInteger(rowIndex) && rowIndex >= 0) {
          syncRowFromDom(section.id, rowIndex, tr);
        }
        scheduleAutoSave({ notify: true, message: '简历字段内容已更新，正在自动保存...' });
      });
    });
    tr.querySelectorAll('[data-k="delete-education-entry"]').forEach((el) => {
      el.addEventListener('click', () => {
        const rowIndex = Number(el.dataset.rowIndex || -1);
        if (Number.isInteger(rowIndex) && rowIndex >= 0) {
          removeEducationEntry(rowIndex);
        }
      });
    });

    body.appendChild(tr);
  }
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
    progress: tr.querySelector('[data-k="progress"]').value,
    applied_date: tr.querySelector('[data-k="applied_date"]').value
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
  const role = String(selectEl.dataset.role || '').trim().toLowerCase();
  const indicator = selectEl.closest('.resume-company-select-wrap')?.querySelector('.resume-company-select-indicator');
  if (indicator) {
    indicator.dataset.role = role;
    indicator.dataset.value = value || 'empty';
  }
}

function getSelectedCompanyRows() {
  return Array.from(document.querySelectorAll('#resumeCompanyRows [data-k="selected"]:checked'))
    .map((el) => Number(el.getAttribute('data-index')))
    .filter((index) => Number.isInteger(index) && index >= 0 && index < (state.resume.company_links || []).length);
}

function syncResumeCompanySelectAllState() {
  const master = byId('resumeCompanySelectAll');
  if (!master) return;
  const rowChecks = Array.from(document.querySelectorAll('#resumeCompanyRows [data-k="selected"]'));
  if (!rowChecks.length) {
    master.checked = false;
    master.indeterminate = false;
    return;
  }
  const checkedCount = rowChecks.filter((el) => el.checked).length;
  master.checked = checkedCount === rowChecks.length;
  master.indeterminate = checkedCount > 0 && checkedCount < rowChecks.length;
}

function syncCompanyFilterUi() {
  const filterDefs = [
    ['company', 'resumeCompanyFilterCompanyBtn'],
    ['company_type', 'resumeCompanyFilterTypeBtn'],
    ['company_scale', 'resumeCompanyFilterScaleBtn'],
    ['job_type', 'resumeCompanyFilterJobTypeBtn'],
    ['progress', 'resumeCompanyFilterProgressBtn'],
    ['applied_date', 'resumeCompanyFilterAppliedDateBtn'],
    ['url', 'resumeCompanyFilterUrlBtn']
  ];

  filterDefs.forEach(([key, btnId]) => {
    const btn = byId(btnId);
    const hasValue = !!String(resumeCompanyFilters[key] || '').trim();
    const isOpen = Array.isArray(resumeCompanyFilters.openKeys) && resumeCompanyFilters.openKeys.includes(key);
    if (btn) {
      btn.classList.toggle('active', hasValue || isOpen);
      btn.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
    }
  });

  renderResumeCompanyFilterBar();
}

function getCompanyPaginationState(totalItems) {
  ensureCompanyTableView();
  const pageSize = state.resume.company_table_view.page_size;
  const totalPages = Math.max(1, Math.ceil(totalItems / pageSize));
  const page = Math.min(Math.max(1, state.resume.company_table_view.page), totalPages);
  state.resume.company_table_view.page = page;
  return { page, pageSize, totalPages };
}

function renderCompanyPagination(totalItems) {
  const host = byId('resumeCompanyPagination');
  const meta = byId('resumeCompanyPaginationMeta');
  const pageSizeEl = byId('resumeCompanyPageSize');
  const prevBtn = byId('resumeCompanyPrevPageBtn');
  const nextBtn = byId('resumeCompanyNextPageBtn');
  if (!host || !meta || !pageSizeEl || !prevBtn || !nextBtn) return;

  const { page, pageSize, totalPages } = getCompanyPaginationState(totalItems);
  const start = totalItems ? (page - 1) * pageSize + 1 : 0;
  const end = totalItems ? Math.min(page * pageSize, totalItems) : 0;
  host.classList.toggle('hidden', totalItems <= pageSize);
  meta.textContent = totalItems
    ? `第 ${page} / ${totalPages} 页 · 第 ${start}-${end} 条 · 共 ${totalItems} 条`
    : '第 1 / 1 页 · 共 0 条';
  pageSizeEl.value = String(pageSize);
  prevBtn.disabled = page <= 1;
  nextBtn.disabled = page >= totalPages;
}

function renderCompanyFilterOptions() {
}

function getResumeCompanyFilterMeta() {
  return {
    company: {
      title: '公司名称筛选',
      render: () => `
        <label>
          <input id="resumeCompanyFilterCompany" type="text" aria-label="公司名称筛选" placeholder="输入公司名称" value="${escAttr(resumeCompanyFilters.company)}" />
        </label>
      `
    },
    company_type: {
      title: '公司类型筛选',
      render: () => `
        <label>
          <select id="resumeCompanyFilterType" aria-label="公司类型筛选">
            ${renderOptionList([{ value: '', label: '全部类型' }, ...COMPANY_TYPE_OPTIONS.slice(1)], resumeCompanyFilters.company_type)}
          </select>
        </label>
      `
    },
    company_scale: {
      title: '公司规模筛选',
      render: () => `
        <label>
          <select id="resumeCompanyFilterScale" aria-label="公司规模筛选">
            ${renderOptionList([{ value: '', label: '全部规模' }, ...COMPANY_SCALE_OPTIONS.slice(1)], resumeCompanyFilters.company_scale)}
          </select>
        </label>
      `
    },
    job_type: {
      title: '岗位类型筛选',
      render: () => `
        <label>
          <select id="resumeCompanyFilterJobType" aria-label="岗位类型筛选">
            ${renderOptionList([{ value: '', label: '全部岗位类型' }, ...COMPANY_JOB_TYPE_OPTIONS.slice(1)], resumeCompanyFilters.job_type)}
          </select>
        </label>
      `
    },
    progress: {
      title: '投递进度筛选',
      render: () => `
        <label>
          <select id="resumeCompanyFilterProgress" aria-label="投递进度筛选">
            ${renderOptionList([{ value: '', label: '全部进度' }, ...COMPANY_PROGRESS_OPTIONS], resumeCompanyFilters.progress)}
          </select>
        </label>
      `
    },
    applied_date: {
      title: '投递日期筛选',
      render: () => `
        <label>
          <input id="resumeCompanyFilterAppliedDate" type="date" aria-label="投递日期筛选" value="${escAttr(resumeCompanyFilters.applied_date)}" />
        </label>
      `
    },
    url: {
      title: '链接地址筛选',
      render: () => `
        <label>
          <input id="resumeCompanyFilterUrl" type="text" aria-label="链接地址筛选" placeholder="输入链接关键词" value="${escAttr(resumeCompanyFilters.url)}" />
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
  const filteredCount = getFilteredCompanyLinks().length;
  const openKeys = Array.isArray(resumeCompanyFilters.openKeys)
    ? resumeCompanyFilters.openKeys.filter((key) => meta[key])
    : [];
  if (!openKeys.length) {
    host.classList.add('hidden');
    body.innerHTML = '';
    return;
  }

  host.classList.remove('hidden');
  title.textContent = `筛选中 (${openKeys.length}) · 共 ${filteredCount} 个`;
  body.innerHTML = openKeys
    .map((key) => `
      <section class="resume-company-filter-card" data-filter-key="${escAttr(key)}">
        <strong class="resume-company-filter-card-title">${escText(meta[key].title)}</strong>
        ${meta[key].render()}
      </section>
    `)
    .join('');

  const bindings = [
    ['resumeCompanyFilterCompany', 'company', 'input'],
    ['resumeCompanyFilterType', 'company_type', 'change'],
    ['resumeCompanyFilterScale', 'company_scale', 'change'],
    ['resumeCompanyFilterJobType', 'job_type', 'change'],
    ['resumeCompanyFilterProgress', 'progress', 'change'],
    ['resumeCompanyFilterAppliedDate', 'applied_date', 'change'],
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
      if (resumeCompanyFilters.applied_date && row.applied_date !== resumeCompanyFilters.applied_date) return false;
      if (companyKeyword && !String(row.company || '').toLowerCase().includes(companyKeyword)) return false;
      if (urlKeyword && !String(row.url || '').toLowerCase().includes(urlKeyword)) return false;
      return true;
    });
}

function getPagedCompanyLinks() {
  const visibleRows = getFilteredCompanyLinks();
  const { page, pageSize } = getCompanyPaginationState(visibleRows.length);
  const start = (page - 1) * pageSize;
  return {
    all: visibleRows,
    pageRows: visibleRows.slice(start, start + pageSize)
  };
}

function renderCompanyRows() {
  const body = byId('resumeCompanyRows');
  if (!body) return;
  body.innerHTML = '';
  syncCompanyFilterUi();

  const { all: visibleRows, pageRows } = getPagedCompanyLinks();
  renderCompanyPagination(visibleRows.length);
  if (!visibleRows.length) {
    body.innerHTML = '<tr><td colspan="9" class="resume-company-empty">当前筛选条件下没有公司记录</td></tr>';
    syncResumeCompanySelectAllState();
    return;
  }

  for (const { index, row } of pageRows) {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td class="resume-company-select-cell"><input type="checkbox" data-k="selected" data-index="${index}" aria-label="选择公司 ${escAttr(row.company || `公司${index + 1}`)}" /></td>
      <td class="resume-company-name-cell"><textarea data-k="company" class="resume-company-inline-textarea resume-company-name-input" wrap="off" placeholder="公司名称">${escText(row.company)}</textarea></td>
      <td>
        <div class="resume-company-select-wrap">
          <span class="resume-company-select-indicator" aria-hidden="true"></span>
          <select data-k="company_type" class="resume-company-select">
            ${renderOptionList(COMPANY_TYPE_OPTIONS, row.company_type)}
          </select>
        </div>
      </td>
      <td>
        <div class="resume-company-select-wrap">
          <span class="resume-company-select-indicator" aria-hidden="true"></span>
          <select data-k="company_scale" class="resume-company-select">
            ${renderOptionList(COMPANY_SCALE_OPTIONS, row.company_scale)}
          </select>
        </div>
      </td>
      <td>
        <div class="resume-company-select-wrap">
          <span class="resume-company-select-indicator" aria-hidden="true"></span>
          <select data-k="job_type" class="resume-company-select">
            ${renderOptionList(COMPANY_JOB_TYPE_OPTIONS, row.job_type)}
          </select>
        </div>
      </td>
      <td>
        <div class="resume-company-select-wrap">
          <span class="resume-company-select-indicator" aria-hidden="true"></span>
          <select data-k="progress" class="resume-company-select">
            ${renderOptionList(COMPANY_PROGRESS_OPTIONS, row.progress)}
          </select>
        </div>
      </td>
      <td class="resume-company-date-cell">
        <input data-k="applied_date" class="resume-company-date-input" type="date" value="${escAttr(row.applied_date || '')}" />
      </td>
      <td>
        <div class="resume-company-url-cell">
          <textarea data-k="url" class="resume-company-inline-textarea" wrap="off" placeholder="公司投递或招聘链接">${escText(row.url)}</textarea>
          <button class="resume-company-url-open" type="button" data-k="open-url" ${row.url ? '' : 'disabled'}>开</button>
        </div>
      </td>
      <td><button class="btn ghost" type="button" data-k="delete">删除</button></td>
    `;

    tr.querySelectorAll('textarea').forEach((el) => {
      autoResizeResumeTextarea(el, el.classList.contains('resume-company-inline-textarea') ? 44 : 72);
    });
    tr.querySelector('[data-k="company_type"]').dataset.role = 'company_type';
    tr.querySelector('[data-k="company_scale"]').dataset.role = 'company_scale';
    tr.querySelector('[data-k="job_type"]').dataset.role = 'job_type';
    tr.querySelector('[data-k="progress"]').dataset.role = 'progress';
    tr.querySelectorAll('.resume-company-select').forEach((el) => {
      syncCompanySelectTheme(el);
    });
    syncCompanyUrlButtonState(tr, row.url);

    tr.querySelectorAll('textarea, select, input[type="date"]').forEach((el) => {
      const eventName = el.tagName === 'SELECT' || el.type === 'date' ? 'change' : 'input';
      el.addEventListener(eventName, () => {
        if (el.tagName === 'TEXTAREA') {
          autoResizeResumeTextarea(el, el.classList.contains('resume-company-inline-textarea') ? 44 : 72);
        } else {
          if (el.tagName === 'SELECT') {
            syncCompanySelectTheme(el);
          }
        }
        syncCompanyRowFromDom(index, tr);
        if (el.getAttribute('data-k') === 'url') {
          syncCompanyUrlButtonState(tr, el.value);
        }
        scheduleAutoSave({ notify: true, message: '公司投递信息已更新，正在自动保存...' });
      });
    });

    const selectedBox = tr.querySelector('[data-k="selected"]');
    if (selectedBox) {
      selectedBox.addEventListener('change', () => {
        syncResumeCompanySelectAllState();
      });
    }

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
      scheduleAutoSave({ notify: true, message: '公司记录已删除，正在自动保存...' });
    };

    body.appendChild(tr);
  }
  syncResumeCompanySelectAllState();
}

function renderResumeSubview() {
  ensureResumeEditorMode();
  const isCompanies = state.resume.editor_mode === RESUME_EDITOR_MODES.COMPANIES;
  const layout = byId('resumeView')?.querySelector('.resume-layout');
  const profileLayout = byId('resumeProfileLayout');
  const sidebar = byId('resumeSidebar');
  const titleBlock = byId('resumeTitleBlock');
  byId('resumeProfilePanel')?.classList.toggle('hidden', isCompanies);
  byId('resumeCompanyPanel')?.classList.toggle('hidden', !isCompanies);
  layout?.classList.toggle('companies-mode', isCompanies);
  profileLayout?.classList.toggle('hidden', isCompanies);
  sidebar?.classList.toggle('hidden', isCompanies);
  titleBlock?.classList.add('hidden');

  const profileBtn = byId('resumePageProfileBtn');
  const companiesBtn = byId('resumePageCompaniesBtn');

  if (profileBtn) {
    profileBtn.classList.toggle('active', !isCompanies);
    profileBtn.setAttribute('aria-selected', !isCompanies ? 'true' : 'false');
  }
  if (companiesBtn) {
    companiesBtn.classList.toggle('active', isCompanies);
    companiesBtn.setAttribute('aria-selected', isCompanies ? 'true' : 'false');
  }
}
function renderResumeEditor() {
  const section = ensureSelectedSection();
  ensureCompanyLinks();
  ensureResumeEditorMode();
  renderSectionList();

  if (!section) {
    byId('resumeRows').innerHTML = '';
    renderCompanyRows();
    renderResumeSubview();
    return;
  }

  renderRows(section);
  renderCompanyRows();
  renderResumeSubview();
}

function setResumeCompanyFilterOpen(key) {
  const current = Array.isArray(resumeCompanyFilters.openKeys) ? [...resumeCompanyFilters.openKeys] : [];
  const next = current.includes(key)
    ? current.filter((item) => item !== key)
    : [...current, key];
  resumeCompanyFilters.openKeys = next;
  syncCompanyFilterUi();
}

function initCompanyFilterHandlers() {
  [
    ['resumeCompanyFilterCompanyBtn', 'company'],
    ['resumeCompanyFilterTypeBtn', 'company_type'],
    ['resumeCompanyFilterScaleBtn', 'company_scale'],
    ['resumeCompanyFilterJobTypeBtn', 'job_type'],
    ['resumeCompanyFilterProgressBtn', 'progress'],
    ['resumeCompanyFilterAppliedDateBtn', 'applied_date'],
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
      resumeCompanyFilters.applied_date = '';
      resumeCompanyFilters.openKeys = [];
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
    scheduleAutoSave({ notify: true, message: '投递进度已更新，正在自动保存...' });
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
  state.resume.company_table_view = incoming.company_table_view || state.resume.company_table_view || { page: 1, page_size: DEFAULT_COMPANY_PAGE_SIZE };
  ensureCompanyTableView();
  ensureSelectedSection();
  renderResumeEditor();
}

export async function saveResumeProfile(options = {}) {
  const silent = !!options.silent;
  const autoNotify = options.autoNotify === true;
  ensureCompanyLinks();
  const payload = await api('/api/resume/save', {
    method: 'POST',
    body: JSON.stringify({
      profile: state.resume.profile,
      company_links: state.resume.company_links,
      editor_mode: state.resume.editor_mode,
      company_table_view: state.resume.company_table_view
    })
  });
  if (!payload.ok) {
    throw new Error(payload.error || 'save resume failed');
  }
  applyResumeState({ resume: payload.state || state.resume });
  if (!silent) {
    toast('\u7b80\u5386\u8d44\u6599\u5df2\u4fdd\u5b58');
  } else if (autoNotify) {
    toast.success('\u7b80\u5386\u4fe1\u606f\u5df2\u81ea\u52a8\u4fdd\u5b58', {
      dedupeKey: 'resume-autosave-success',
      duration: 1600
    });
  }
}

export function initResumeHandlers() {
  initCompanyFilterHandlers();
  const profileBtn = byId('resumePageProfileBtn');
  if (profileBtn) {
    profileBtn.onclick = () => {
      state.resume.editor_mode = RESUME_EDITOR_MODES.PROFILE;
      renderResumeEditor();
      scheduleAutoSave();
    };
  }
  const companiesBtn = byId('resumePageCompaniesBtn');
  if (companiesBtn) {
    companiesBtn.onclick = () => {
      state.resume.editor_mode = RESUME_EDITOR_MODES.COMPANIES;
      renderResumeEditor();
      scheduleAutoSave();
    };
  }

  if (!resumeExtensionGuideLoaded) {
    resumeExtensionGuideLoaded = true;

    const openBtn = byId('resumeInstallChromeExtensionBtn');
    if (openBtn) {
      openBtn.onclick = () => {
        void openResumeExtensionGuide();
      };
    }

    const closeBtn = byId('resumeExtensionGuideCloseBtn');
    if (closeBtn) {
      closeBtn.onclick = () => closeResumeExtensionGuide();
    }

    const okBtn = byId('resumeExtensionGuideOkBtn');
    if (okBtn) {
      okBtn.onclick = () => closeResumeExtensionGuide();
    }

    const host = byId('resumeExtensionGuideHost');
    const overlay = host?.querySelector('.resume-guide-overlay');
    if (overlay) {
      overlay.onclick = () => closeResumeExtensionGuide();
    }
    host?.querySelector('.resume-guide-dialog')?.addEventListener('click', (event) => {
      event.stopPropagation();
    });

    const copyBtn = byId('resumeExtensionGuideCopyBtn');
    if (copyBtn) {
      copyBtn.onclick = () => {
        void copyResumeExtensionDir();
      };
    }

    const openFolderBtn = byId('resumeExtensionGuideOpenFolderBtn');
    if (openFolderBtn) {
      openFolderBtn.onclick = () => {
        void openResumeExtensionFolder();
      };
    }

    const openChromeBtn = byId('resumeExtensionGuideOpenChromeBtn');
    if (openChromeBtn) {
      openChromeBtn.onclick = () => openChromeExtensionsPage();
    }
  }

  const addCompanyBtn = byId('resumeAddCompanyRowBtn');
  if (addCompanyBtn) {
    addCompanyBtn.onclick = () => {
      ensureCompanyLinks();
      state.resume.company_links.push(normalizeCompanyLink({}, state.resume.company_links.length));
      const total = state.resume.company_links.length;
      const { pageSize } = getCompanyPaginationState(total);
      state.resume.company_table_view.page = Math.max(1, Math.ceil(total / pageSize));
      renderResumeEditor();
      scheduleAutoSave({ notify: true, message: '公司记录已新增，正在自动保存...' });
    };
  }

  const pageSizeEl = byId('resumeCompanyPageSize');
  if (pageSizeEl && pageSizeEl.dataset.bound !== '1') {
    pageSizeEl.dataset.bound = '1';
    pageSizeEl.onchange = () => {
      ensureCompanyTableView();
      const pageSize = Number(pageSizeEl.value || DEFAULT_COMPANY_PAGE_SIZE);
      state.resume.company_table_view.page_size = COMPANY_PAGE_SIZE_OPTIONS.includes(pageSize) ? pageSize : DEFAULT_COMPANY_PAGE_SIZE;
      state.resume.company_table_view.page = 1;
      renderCompanyRows();
      scheduleAutoSave();
    };
  }

  const prevBtn = byId('resumeCompanyPrevPageBtn');
  if (prevBtn && prevBtn.dataset.bound !== '1') {
    prevBtn.dataset.bound = '1';
    prevBtn.onclick = () => {
      ensureCompanyTableView();
      state.resume.company_table_view.page = Math.max(1, state.resume.company_table_view.page - 1);
      renderCompanyRows();
      scheduleAutoSave();
    };
  }

  const nextBtn = byId('resumeCompanyNextPageBtn');
  if (nextBtn && nextBtn.dataset.bound !== '1') {
    nextBtn.dataset.bound = '1';
    nextBtn.onclick = () => {
      const total = getFilteredCompanyLinks().length;
      const { totalPages } = getCompanyPaginationState(total);
      state.resume.company_table_view.page = Math.min(totalPages, state.resume.company_table_view.page + 1);
      renderCompanyRows();
      scheduleAutoSave();
    };
  }

  const applyBtn = byId('resumeApplySelectedCompaniesBtn');
  if (applyBtn) {
    applyBtn.onclick = () => {
      openSelectedCompanyLinks();
    };
  }

  const selectAllBox = byId('resumeCompanySelectAll');
  if (selectAllBox && selectAllBox.dataset.bound !== '1') {
    selectAllBox.dataset.bound = '1';
    selectAllBox.onchange = () => {
      const shouldCheck = !!selectAllBox.checked;
      document.querySelectorAll('#resumeCompanyRows [data-k="selected"]').forEach((el) => {
        el.checked = shouldCheck;
      });
      syncResumeCompanySelectAllState();
    };
  }
}
