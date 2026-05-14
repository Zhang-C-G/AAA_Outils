(function () {
  const strategies = [];

  function register(strategy) {
    if (!strategy || typeof strategy !== 'object') return;
    strategies.push(strategy);
  }

  function normalize(text) {
    return String(text || '').trim().toLowerCase().replace(/\s+/g, '');
  }

  function textOf(node) {
    return String(node?.textContent || '').replace(/\s+/g, ' ').trim();
  }

  function isVisible(node) {
    if (!node || !node.isConnected) return false;
    const rect = node.getBoundingClientRect();
    const style = window.getComputedStyle(node);
    return style.display !== 'none'
      && style.visibility !== 'hidden'
      && style.opacity !== '0'
      && rect.width > 0
      && rect.height > 0;
  }

  function isUsableField(node) {
    const type = String(node?.type || '').toLowerCase();
    return !!node
      && !node.disabled
      && !['hidden', 'button', 'submit', 'reset', 'file'].includes(type)
      && isVisible(node);
  }

  function listVisible(selector, root = document) {
    return Array.from(root.querySelectorAll(selector)).filter(isVisible);
  }

  function flattenProfileRows(profile) {
    const rows = [];
    for (const section of Array.isArray(profile?.sections) ? profile.sections : []) {
      for (const row of Array.isArray(section?.rows) ? section.rows : []) {
        rows.push({
          sectionId: String(section?.id || ''),
          sectionTitle: String(section?.title || ''),
          id: String(row?.id || ''),
          label: String(row?.label || ''),
          value: String(row?.value || '')
        });
      }
    }
    return rows;
  }

  function buildRowMap(profile) {
    const map = new Map();
    for (const row of flattenProfileRows(profile)) {
      if (!row.id) continue;
      map.set(row.id, row.value);
    }
    return map;
  }

  function getRowValue(rowMap, id) {
    return String(rowMap.get(String(id || '')) || '').trim();
  }

  function parseStructuredText(text) {
    const map = new Map();
    const lines = String(text || '')
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(Boolean);

    for (const line of lines) {
      const matched = line.match(/^([^:：]+)\s*[:：]\s*(.+)$/);
      if (!matched) continue;
      const key = normalize(matched[1]);
      const value = String(matched[2] || '').trim();
      if (key && value && !map.has(key)) {
        map.set(key, value);
      }
    }
    return map;
  }

  function parseDateRange(text) {
    const matches = String(text || '').match(/\d{4}-\d{2}-\d{2}/g) || [];
    return {
      start: matches[0] || '',
      end: matches[1] || ''
    };
  }

  function toMonthValue(dateText) {
    const matched = String(dateText || '').match(/(\d{4})-(\d{2})/);
    return matched ? `${matched[1]}-${matched[2]}` : '';
  }

  function toDateParts(dateText) {
    const matched = String(dateText || '').match(/(\d{4})-(\d{2})-(\d{2})/);
    if (!matched) return null;
    return {
      year: Number(matched[1]),
      month: Number(matched[2]),
      day: Number(matched[3])
    };
  }

  function mapValue(structured, keys) {
    for (const key of keys) {
      const value = structured.get(normalize(key));
      if (value) return value;
    }
    return '';
  }

  function collectEntryRows(rowMap, prefix) {
    return Array.from(rowMap.entries())
      .map(([id, value]) => ({ id, value: String(value || '') }))
      .filter((item) => item.id.startsWith(prefix) && item.value.trim())
      .sort((a, b) => a.id.localeCompare(b.id, undefined, { numeric: true }));
  }

  function parseEducationEntries(rowMap) {
    const entries = collectEntryRows(rowMap, 'education_entry_').map((item) => {
      const structured = parseStructuredText(item.value);
      const startDate = mapValue(structured, ['入学日期', '开始日期']);
      const endDate = mapValue(structured, ['毕业日期', '结束日期']);
      const range = startDate || endDate
        ? { start: startDate, end: endDate }
        : parseDateRange(mapValue(structured, ['起止日期', '起止时间', '在校时间']) || item.value);
      return {
        school: mapValue(structured, ['学校名称', '学校', '院校']),
        major: mapValue(structured, ['专业']),
        degree: mapValue(structured, ['学历']),
        startMonth: toMonthValue(range.start),
        endMonth: toMonthValue(range.end),
        isCurrent: !range.end
      };
    }).filter((item) => item.school || item.major || item.degree || item.startMonth || item.endMonth);

    if (entries.length) return entries;

    const range = parseDateRange(getRowValue(rowMap, 'education_time'));
    const fallback = {
      school: getRowValue(rowMap, 'school'),
      major: getRowValue(rowMap, 'major'),
      degree: getRowValue(rowMap, 'degree'),
      startMonth: toMonthValue(range.start),
      endMonth: toMonthValue(range.end),
      isCurrent: !range.end
    };
    return (fallback.school || fallback.major || fallback.degree) ? [fallback] : [];
  }

  function parseInternshipEntries(rowMap) {
    const entries = collectEntryRows(rowMap, 'intern_entry_').map((item) => {
      const range = parseDateRange(item.value);
      return {
        company: getRowValue(rowMap, 'intern_company'),
        role: getRowValue(rowMap, 'intern_role'),
        desc: item.value.trim(),
        startMonth: toMonthValue(range.start),
        endMonth: toMonthValue(range.end),
        isCurrent: !range.end
      };
    }).filter((item) => item.company || item.role || item.desc);

    if (entries.length) return entries;

    const range = parseDateRange(getRowValue(rowMap, 'intern_time'));
    const fallback = {
      company: getRowValue(rowMap, 'intern_company'),
      role: getRowValue(rowMap, 'intern_role'),
      desc: getRowValue(rowMap, 'intern_desc'),
      startMonth: toMonthValue(range.start),
      endMonth: toMonthValue(range.end),
      isCurrent: !range.end
    };
    return (fallback.company || fallback.role || fallback.desc) ? [fallback] : [];
  }

  function parseProjectEntries(rowMap) {
    const entries = collectEntryRows(rowMap, 'project_entry_').map((item) => {
      const structured = parseStructuredText(item.value);
      const range = parseDateRange(mapValue(structured, ['起止日期', '起止时间', '项目时间']) || item.value);
      return {
        name: mapValue(structured, ['项目名称']),
        role: mapValue(structured, ['担任角色', '项目角色']),
        desc: mapValue(structured, ['详细信息', '项目中职责', '项目描述']) || item.value.trim(),
        link: mapValue(structured, ['项目链接']),
        startMonth: toMonthValue(range.start),
        endMonth: toMonthValue(range.end),
        isCurrent: !range.end
      };
    }).filter((item) => item.name || item.role || item.desc || item.link);

    if (entries.length) return entries;

    const baseDesc = getRowValue(rowMap, 'project_desc');
    const structured = parseStructuredText(baseDesc);
    const range = parseDateRange(getRowValue(rowMap, 'project_time') || baseDesc);
    const fallback = {
      name: getRowValue(rowMap, 'project_name') || mapValue(structured, ['项目名称']),
      role: getRowValue(rowMap, 'project_role') || mapValue(structured, ['项目角色', '担任角色']),
      desc: baseDesc,
      link: mapValue(structured, ['项目链接']),
      startMonth: toMonthValue(range.start),
      endMonth: toMonthValue(range.end),
      isCurrent: !range.end
    };
    return (fallback.name || fallback.role || fallback.desc || fallback.link) ? [fallback] : [];
  }

  function findVisibleElementByText(text, selector = '*') {
    const target = normalize(text);
    return Array.from(document.querySelectorAll(selector)).find((node) => {
      if (!isVisible(node)) return false;
      return normalize(textOf(node)) === target;
    }) || null;
  }

  function findCommonAncestor(a, b) {
    if (!a || !b) return null;
    const seen = new Set();
    let cursor = a;
    while (cursor) {
      seen.add(cursor);
      cursor = cursor.parentElement;
    }
    cursor = b;
    while (cursor) {
      if (seen.has(cursor)) return cursor;
      cursor = cursor.parentElement;
    }
    return null;
  }

  function findSectionRoot(headingText, addButtonText) {
    const heading = findVisibleElementByText(headingText);
    const addButton = findVisibleElementByText(addButtonText, 'button, [role="button"], .btn, .button, span, div');
    const common = findCommonAncestor(heading, addButton);
    if (common) return common;
    return heading?.parentElement || document.body;
  }

  function fieldCandidateTexts(field) {
    const texts = [
      field.getAttribute('aria-label') || '',
      field.getAttribute('placeholder') || '',
      field.getAttribute('name') || '',
      field.getAttribute('id') || '',
      field.dataset?.label || ''
    ];

    const fieldId = field.getAttribute('id');
    if (fieldId) {
      const label = document.querySelector(`label[for="${CSS.escape(fieldId)}"]`);
      if (label) texts.push(textOf(label));
    }

    let cursor = field.parentElement;
    for (let depth = 0; cursor && depth < 5; depth += 1, cursor = cursor.parentElement) {
      const prev = cursor.previousElementSibling;
      if (prev) texts.push(textOf(prev));
      texts.push(textOf(cursor));
    }

    return texts.filter(Boolean);
  }

  function collectFieldsByLabel(root, labels) {
    const targets = labels.map(normalize);
    const fields = Array.from(root.querySelectorAll('input, textarea, select')).filter(isUsableField);
    return fields.filter((field) => {
      const candidates = fieldCandidateTexts(field);
      return candidates.some((candidate) => {
        const norm = normalize(candidate);
        return targets.some((target) => norm.includes(target));
      });
    });
  }

  function collectCheckboxesNearText(root, labelText) {
    const target = normalize(labelText);
    return Array.from(root.querySelectorAll('input[type="checkbox"]')).filter((field) => {
      if (!isUsableField(field)) return false;
      const candidates = fieldCandidateTexts(field);
      return candidates.some((candidate) => normalize(candidate).includes(target));
    });
  }

  function setNativeValue(field, value) {
    const tag = String(field?.tagName || '').toLowerCase();
    const proto = tag === 'textarea'
      ? window.HTMLTextAreaElement?.prototype
      : tag === 'select'
        ? window.HTMLSelectElement?.prototype
        : window.HTMLInputElement?.prototype;
    const setter = proto ? Object.getOwnPropertyDescriptor(proto, 'value')?.set : null;
    if (setter) {
      setter.call(field, value);
    } else {
      field.value = value;
    }
  }

  function dispatchFieldEvents(field) {
    ['input', 'change', 'blur'].forEach((type) => {
      field.dispatchEvent(new Event(type, { bubbles: true }));
    });
  }

  function forceFillField(field, value) {
    if (!field || value == null || value === '') return false;
    setNativeValue(field, value);
    dispatchFieldEvents(field);
    return true;
  }

  function visibleOptionByText(text) {
    const target = normalize(text);
    const candidates = Array.from(document.querySelectorAll(
      '[role="option"], li, .el-select-dropdown__item, .ant-select-item-option, .ivu-select-item, .el-date-table td, .el-month-table td, button, span, div'
    )).filter(isVisible);
    return candidates.find((node) => {
      const norm = normalize(textOf(node));
      return norm === target || norm.includes(target);
    }) || null;
  }

  async function chooseVisibleOption(text) {
    const option = visibleOptionByText(text);
    if (!option) return false;
    option.click();
    await wait(80);
    return true;
  }

  async function setChoiceField(field, value) {
    if (!field || !value) return false;
    const tag = String(field.tagName || '').toLowerCase();
    if (tag === 'select') {
      const options = Array.from(field.options || []);
      const target = normalize(value);
      const matched = options.find((opt) => {
        const optText = normalize(opt.textContent);
        const optValue = normalize(opt.value);
        return optText === target || optValue === target || optText.includes(target);
      });
      if (!matched) return false;
      setNativeValue(field, matched.value);
      dispatchFieldEvents(field);
      return true;
    }

    field.click();
    await wait(100);
    if (await chooseVisibleOption(value)) {
      return true;
    }
    return forceFillField(field, value);
  }

  async function setDateField(field, dateText) {
    if (!field || !dateText) return false;
    const target = String(dateText).trim();
    if (forceFillField(field, target)) {
      await wait(40);
      if (normalize(field.value).includes(normalize(target))) {
        return true;
      }
    }
    const parts = toDateParts(target);
    if (!parts) return false;
    field.click();
    await wait(120);
    const dayCell = visibleOptionByText(String(parts.day));
    if (dayCell) {
      dayCell.click();
      await wait(80);
      return true;
    }
    return false;
  }

  async function setMonthField(field, monthText) {
    if (!field || !monthText) return false;
    const target = String(monthText).trim();
    if (forceFillField(field, target)) {
      await wait(40);
      if (normalize(field.value).includes(normalize(target))) {
        return true;
      }
    }
    return false;
  }

  async function setCheckbox(field, checked) {
    if (!field || field.checked === checked) return false;
    field.click();
    await wait(40);
    return true;
  }

  function wait(ms) {
    return new Promise((resolve) => window.setTimeout(resolve, ms));
  }

  async function ensureBlockCount(sectionRoot, addButtonText, fieldLabels, expectedCount) {
    const labels = Array.isArray(fieldLabels) ? fieldLabels : [fieldLabels];
    const addButton = findVisibleElementByText(addButtonText, 'button, [role="button"], .btn, .button, span, div');
    if (!addButton) return 0;

    let clicks = 0;
    for (let i = 0; i < 8; i += 1) {
      const current = collectFieldsByLabel(sectionRoot, labels).length;
      if (current >= expectedCount) break;
      addButton.click();
      clicks += 1;
      await wait(160);
    }
    return clicks;
  }

  async function fillBasicInfo(ctx, rowMap) {
    let filled = 0;
    const touched = [];
    const notes = [];

    const nameField = collectFieldsByLabel(document.body, ['姓名'])[0];
    if (nameField && forceFillField(nameField, getRowValue(rowMap, 'full_name'))) {
      filled += 1;
      touched.push(nameField);
    }

    const genderField = collectFieldsByLabel(document.body, ['性别'])[0];
    if (genderField && await setChoiceField(genderField, getRowValue(rowMap, 'gender'))) {
      filled += 1;
      touched.push(genderField);
    }

    const birthField = collectFieldsByLabel(document.body, ['出生日期', '生日'])[0];
    if (birthField && await setDateField(birthField, getRowValue(rowMap, 'birth_date'))) {
      filled += 1;
      touched.push(birthField);
    }

    const cityField = collectFieldsByLabel(document.body, ['所在城市', '现居城市'])[0];
    if (cityField && forceFillField(cityField, getRowValue(rowMap, 'current_city'))) {
      filled += 1;
      touched.push(cityField);
    }

    const phoneFields = collectFieldsByLabel(document.body, ['手机号', '手机号码']);
    const phoneField = phoneFields.find((field) => String(field.type || '').toLowerCase() !== 'select' && (field.maxLength <= 0 || field.maxLength >= 11)) || phoneFields[phoneFields.length - 1];
    if (phoneField && forceFillField(phoneField, getRowValue(rowMap, 'phone'))) {
      filled += 1;
      touched.push(phoneField);
    }

    const emailField = collectFieldsByLabel(document.body, ['邮箱', '邮箱地址', '电子邮箱'])[0];
    if (emailField && forceFillField(emailField, getRowValue(rowMap, 'email'))) {
      filled += 1;
      touched.push(emailField);
    }

    notes.push('基本信息策略：已尝试姓名、性别、出生日期、城市、手机号、邮箱。');
    return { filled, touched, notes, actions: [`basic_info_filled:${filled}`] };
  }

  async function fillEducation(ctx, rowMap) {
    const records = parseEducationEntries(rowMap);
    const touched = [];
    const actions = [];
    if (!records.length) {
      return { filled: 0, touched, notes: ['教育经历策略：本地无可用记录。'], actions };
    }

    const root = findSectionRoot('教育经历', '添加教育经历');
    const added = await ensureBlockCount(root, '添加教育经历', ['学校名称'], records.length);
    if (added) actions.push(`education_added:${added}`);

    const schoolFields = collectFieldsByLabel(root, ['学校名称']);
    const majorFields = collectFieldsByLabel(root, ['专业']);
    const degreeFields = collectFieldsByLabel(root, ['学历']);
    const timeFields = collectFieldsByLabel(root, ['起止时间']);
    const currentFields = collectCheckboxesNearText(root, '至今');

    let filled = 0;
    for (let i = 0; i < records.length; i += 1) {
      const record = records[i];
      if (schoolFields[i] && forceFillField(schoolFields[i], record.school)) { filled += 1; touched.push(schoolFields[i]); }
      if (majorFields[i] && forceFillField(majorFields[i], record.major)) { filled += 1; touched.push(majorFields[i]); }
      if (degreeFields[i] && await setChoiceField(degreeFields[i], record.degree)) { filled += 1; touched.push(degreeFields[i]); }
      if (timeFields[i * 2] && await setMonthField(timeFields[i * 2], record.startMonth)) { filled += 1; touched.push(timeFields[i * 2]); }
      if (record.isCurrent) {
        if (currentFields[i] && await setCheckbox(currentFields[i], true)) { filled += 1; touched.push(currentFields[i]); }
      } else if (timeFields[i * 2 + 1] && await setMonthField(timeFields[i * 2 + 1], record.endMonth)) {
        filled += 1;
        touched.push(timeFields[i * 2 + 1]);
      }
    }

    return {
      filled,
      touched,
      notes: [`教育经历策略：已按 ${records.length} 条记录尝试填写。`],
      actions
    };
  }

  async function fillExperience(ctx, rowMap) {
    const records = parseInternshipEntries(rowMap);
    const touched = [];
    const actions = [];
    if (!records.length) {
      return { filled: 0, touched, notes: ['实习/工作经历策略：本地无可用记录。'], actions };
    }

    const root = findSectionRoot('实习/工作经历', '添加实习/工作经历');
    const added = await ensureBlockCount(root, '添加实习/工作经历', ['公司名称'], records.length);
    if (added) actions.push(`experience_added:${added}`);

    const companyFields = collectFieldsByLabel(root, ['公司名称', '实习单位']);
    const roleFields = collectFieldsByLabel(root, ['职位名称', '岗位', '实习岗位']);
    const descFields = collectFieldsByLabel(root, ['工作描述', '工作内容', '职责描述']);
    const timeFields = collectFieldsByLabel(root, ['起止时间']);
    const currentFields = collectCheckboxesNearText(root, '至今');

    let filled = 0;
    for (let i = 0; i < records.length; i += 1) {
      const record = records[i];
      if (companyFields[i] && forceFillField(companyFields[i], record.company)) { filled += 1; touched.push(companyFields[i]); }
      if (roleFields[i] && forceFillField(roleFields[i], record.role)) { filled += 1; touched.push(roleFields[i]); }
      if (descFields[i] && forceFillField(descFields[i], record.desc)) { filled += 1; touched.push(descFields[i]); }
      if (timeFields[i * 2] && await setMonthField(timeFields[i * 2], record.startMonth)) { filled += 1; touched.push(timeFields[i * 2]); }
      if (record.isCurrent) {
        if (currentFields[i] && await setCheckbox(currentFields[i], true)) { filled += 1; touched.push(currentFields[i]); }
      } else if (timeFields[i * 2 + 1] && await setMonthField(timeFields[i * 2 + 1], record.endMonth)) {
        filled += 1;
        touched.push(timeFields[i * 2 + 1]);
      }
    }

    return {
      filled,
      touched,
      notes: [`实习/工作经历策略：已按 ${records.length} 条记录尝试填写。`],
      actions
    };
  }

  async function fillProject(ctx, rowMap) {
    const records = parseProjectEntries(rowMap);
    const touched = [];
    const actions = [];
    if (!records.length) {
      return { filled: 0, touched, notes: ['项目经历策略：本地无可用记录。'], actions };
    }

    const root = findSectionRoot('项目经历', '添加项目经历');
    const added = await ensureBlockCount(root, '添加项目经历', ['项目名称'], records.length);
    if (added) actions.push(`project_added:${added}`);

    const nameFields = collectFieldsByLabel(root, ['项目名称']);
    const roleFields = collectFieldsByLabel(root, ['项目角色', '担任角色']);
    const descFields = collectFieldsByLabel(root, ['项目描述', '详细信息']);
    const linkFields = collectFieldsByLabel(root, ['项目链接']);
    const timeFields = collectFieldsByLabel(root, ['起止时间']);
    const currentFields = collectCheckboxesNearText(root, '至今');

    let filled = 0;
    for (let i = 0; i < records.length; i += 1) {
      const record = records[i];
      if (nameFields[i] && forceFillField(nameFields[i], record.name)) { filled += 1; touched.push(nameFields[i]); }
      if (roleFields[i] && forceFillField(roleFields[i], record.role)) { filled += 1; touched.push(roleFields[i]); }
      if (descFields[i] && forceFillField(descFields[i], record.desc)) { filled += 1; touched.push(descFields[i]); }
      if (linkFields[i] && forceFillField(linkFields[i], record.link)) { filled += 1; touched.push(linkFields[i]); }
      if (timeFields[i * 2] && await setMonthField(timeFields[i * 2], record.startMonth)) { filled += 1; touched.push(timeFields[i * 2]); }
      if (record.isCurrent) {
        if (currentFields[i] && await setCheckbox(currentFields[i], true)) { filled += 1; touched.push(currentFields[i]); }
      } else if (timeFields[i * 2 + 1] && await setMonthField(timeFields[i * 2 + 1], record.endMonth)) {
        filled += 1;
        touched.push(timeFields[i * 2 + 1]);
      }
    }

    return {
      filled,
      touched,
      notes: [`项目经历策略：已按 ${records.length} 条记录尝试填写。`],
      actions
    };
  }

  register({
    id: 'bilibili-candidate',
    label: 'Bilibili Resume Strategy',
    matches(ctx) {
      const host = String(ctx?.location?.hostname || '').toLowerCase();
      return host.includes('bilibili.com');
    },
    async execute(ctx) {
      const rowMap = buildRowMap(ctx.profile);
      const reports = [];
      for (const runner of [
        () => fillBasicInfo(ctx, rowMap),
        () => fillEducation(ctx, rowMap),
        () => fillExperience(ctx, rowMap),
        () => fillProject(ctx, rowMap)
      ]) {
        reports.push(await runner());
      }

      const touchedElements = [];
      const touchedSet = new Set();
      const notes = ['已命中 Bilibili 站点策略，优先执行站点专用动作。'];
      const actions = [];
      let filled = 0;

      for (const report of reports) {
        filled += Number(report?.filled || 0);
        for (const note of report?.notes || []) notes.push(note);
        for (const action of report?.actions || []) actions.push(action);
        for (const el of report?.touched || []) {
          if (el && !touchedSet.has(el)) {
            touchedSet.add(el);
            touchedElements.push(el);
          }
        }
      }

      notes.push('首版策略当前跳过附件上传与内推码。');
      return { filled, touchedElements, notes, actions };
    }
  });

  globalThis.ZCGResumeSiteStrategies = strategies;
})();
