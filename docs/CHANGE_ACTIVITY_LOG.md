# 改动流水文档

最近同步：`2026-05-11`
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。
满 3 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-05-09-post-resume-company-table-checkpoint`
- 当前连续改动次数：`3`
- 本轮目标：
  - 完成 F 模块公司投递表相关正式文档、偏好文档、模板文档与过程文档的同步收口
- 上一个 git 检查点：`checkpoint: refine resume company table workflow`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 上一轮已归档 checkpoint 摘要

上一轮在进入 checkpoint 前共完成 3 次改动：

### 第 1 次改动
- 时间：`2026-05-09`
- 内容：
  - 保留 F 模块公司投递表的颜色区分
  - 让下拉框恢复原本黑白风
  - 将颜色信息改为侧边色标承载
- 影响文件：
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resume-company-select-wrap|resume-company-select-indicator|syncCompanySelectTheme" webui/config/app-resume.js webui/config/styles.css`
- 测试结果：`通过`

### 第 2 次改动
- 时间：`2026-05-09`
- 内容：
  - F 模块公司投递表补充分页
  - 分页状态接入保存与草稿恢复
  - 公司名称输入框改为字段贴合宽度
  - 表格规则写入私人偏好，并建立第一个统一表格模板
- 影响文件：
  - `webui/config/app-common.js`
  - `webui/config/app-main.js`
  - `webui/config/app-resume.js`
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `docs/extension/global_preferences/components/18_表格与筛选器偏好.md`
  - `docs/templates/TABLE_STAGE1_TEMPLATE.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resumeCompanyPagination|company_table_view|resume-company-name-input|TABLE_STAGE1_TEMPLATE" webui/config/app-resume.js webui/config/index.html webui/config/styles.css webui/config/app-main.js docs/templates/TABLE_STAGE1_TEMPLATE.md`
- 测试结果：`通过`

### 第 3 次改动
- 时间：`2026-05-09`
- 内容：
  - F 模块公司投递表的顶部筛选条支持多项同时展开
  - 多个 `筛` 按钮允许同时保持绿色激活
  - 顶部筛选区改为承载多个筛选块
  - 表头选择入口改为勾选框本体，去掉“全选”文字
  - 顶部筛选条增加结果统计
  - 删除额外的“收起筛选”入口，筛选展开与关闭只通过对应列表头圆点控制
  - 公司名称与链接地址输入框改为默认单行显示
  - 顶部筛选区压缩为更紧凑的工具条样式
  - 删除筛选卡片内重复字段名
  - 收窄公司名称列
  - 将表头勾选框调整为列内真正居中显示
- 影响文件：
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/extension/global_preferences/components/18_表格与筛选器偏好.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resumeCompanyFilterBar|resume-company-filter-summary|resume-filter-dot.active|resume-company-select-head" webui/config/app-resume.js webui/config.index.html webui/config/styles.css`
- 测试结果：`通过`
- 是否触发 git：`是，已形成 checkpoint`

## 4. 当前 1-3 次改动窗口

### 第 1 次改动
- 时间：`2026-05-09`
- 内容：
  - 将 F 模块正式模块文档同步为当前“简历字段维护 + 公司投递维护”双工作区口径
  - 将表格与筛选器私人偏好文档补齐为当前已验证规则
  - 将第一阶段表格模板同步到当前复用规则
  - 将 F 模块修改过程文档与改动流水文档补齐到当前状态
- 影响文件：
  - `docs/modules/11_resume_autofill.md`
  - `docs/extension/global_preferences/components/18_表格与筛选器偏好.md`
  - `docs/templates/TABLE_STAGE1_TEMPLATE.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 文档一致性校对：核对正式模块文档、私人偏好文档、模板文档与模块当前实现是否一致
  - `git log --oneline -5`
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 2 次改动
- 时间：`2026-05-09`
- 内容：
  - 删除主界面中的“靠北！”软件名前缀
  - 页面 `<title>` 与顶部 `<h1>` 统一只保留 `Raccourci Control`
- 影响文件：
  - `webui/config/index.html`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `rg -n "靠北！|靠北!|靠北" webui/config/index.html -S`
  - `rg -n "<title>|<h1>" webui/config/index.html`
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 3 次改动
- 时间：`2026-05-11`
- 内容：
  - 修复 E 模块 `语音模型激活` 未自动保存、未完整接入后端与 AHK 运行态的问题
  - 语音模型选择新增 `本地默认语音识别`
  - F2 悬浮窗待命状态新增当前语音模型展示
- 影响文件：
  - `webui/config/app-assistant.js`
  - `webui/config/server_state/assistant.ps1`
  - `src/storage/assistant.ahk`
  - `src/storage/data_save.ahk`
  - `src/storage/data_load.ahk`
  - `src/assistant_overlay.ahk`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-assistant.js`
  - PowerShell Parser 校验 `webui/config/server_state/assistant.ps1`
  - `rg -n "voice_model|voice_model_enabled|voice_model_options|local_windows_default|BuildAssistantOverlayIdleStatus|GetAssistantCurrentVoiceModelLabel" webui/config/app-assistant.js webui/config/server_state/assistant.ps1 src/storage/assistant.ahk src/storage/data_save.ahk src/storage/data_load.ahk src/assistant_overlay.ahk -S`
- 测试结果：`通过`
- 是否触发 git：`是，本次达到 3/3，需要执行 checkpoint commit 并 push`
