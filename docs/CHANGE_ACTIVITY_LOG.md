# 改动流水文档

最近同步：`2026-05-09`
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。  
满 3 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-05-09-post-resume-filter-checkpoint`
- 当前连续改动次数：`3`
- 本轮目标：
  - 保留 F 模块公司投递表的颜色区分
  - 让下拉框恢复原本黑白风
  - 将颜色信息改为侧边色标承载
- 上一个 git 检查点：`checkpoint: refine resume table filtering`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 上一轮已归档 checkpoint 摘要

上一轮在进入 checkpoint 前共完成 3 次改动：

### 第1次改动
- 时间：`2026-05-09`
- 内容：
  - 删除 F 模块公司投递表顶部整排筛选器
  - 改为“列标题右侧圆点按钮 -> 点击后展开对应筛选”的筛选方式
  - 链接地址列改为“单一可编辑输入框 + 单独跳转按钮”
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resumeCompanyFilterKeyword|resume-company-filters|url-preview|resume-company-url-link|resume-filter-dot|resumeCompanyFilterCompany|open-url" webui/config/app-resume.js webui/config/index.html webui/config/styles.css`
- 测试结果：`通过`

### 第2次改动
- 时间：`2026-05-09`
- 内容：
  - 为 F 模块公司类型、公司规模、岗位类型、投递进度增加按值着色
  - 让不同选择结果在表格里更容易快速区分
- 影响文件：
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "syncCompanySelectTheme|data-role=|data-value=|resume-company-select\\[data-role" webui/config/app-resume.js webui/config/styles.css`
- 测试结果：`通过`

### 第3次改动
- 时间：`2026-05-09`
- 内容：
  - 将 F 模块公司投递表的筛选交互从悬浮筛选改为顶部筛选条
  - 点击列头 `筛` 后，按钮变绿，表格上方出现对应筛选框
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resumeCompanyFilterBar|resume-filter-popover|resumeCompanyFilterCompanyPanel|resume-company-filter-bar|resume-filter-dot.active" webui/config/app-resume.js webui/config/index.html webui/config/styles.css`
- 测试结果：`通过`
- 是否触发 git：`是，已完成 checkpoint commit 并 push`

## 4. 当前 1-3 次改动窗口

### 第1次改动
- 时间：`2026-05-09`
- 内容：
  - 保留 F 模块不同选择值的颜色区分
  - 下拉框本体恢复原色
  - 颜色改由左侧小色标承载
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
- 是否触发 git：`否`

### 第2次改动
- 时间：`2026-05-09`
- 内容：
  - F 模块公司投递表补充分页
  - 分页状态接入保存与草稿恢复
  - 公司名称输入框改为字段贴合宽度
  - 表格规则写入私人偏好，并建立第一个统一表格模版
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
- 是否触发 git：`否`

### 第3次改动
- 时间：`2026-05-09`
- 内容：
  - F 模块公司投递表的顶部筛选条支持多项同时展开
  - 多个 `筛` 按钮允许同时保持绿色激活态
  - 顶部筛选区改为承载多个筛选块
  - 表头 `选择` 改为 `全选`，点击后可一键勾选当前表中可见公司
  - 顶部筛选条增加结果统计，筛选时直接显示当前命中的公司总数
  - 删除 `收起筛选` 按钮；筛选面板的展开与取消仅通过对应列头圆点控制
  - 公司名称与链接地址输入框改为默认单行显示，只有手动回车后才扩展为多行
  - 顶部筛选区整体压缩为更紧凑的工具条样式，减少高度与留白占用
  - 修正公司名称与链接地址输入框的视觉高度，避免被表格通用 `textarea` 样式继续撑成多行外观
  - 删除筛选卡片里的重复字段名，只保留一层标题
  - 收窄公司名称列宽度，减少表格横向占用
  - 删除表头 `全选` 文字，仅保留勾选框本体
- 影响文件：
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/extension/global_preferences/components/18_表格与筛选器偏好.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resumeCompanySelectAll|aria-label=\\\"全选当前表格公司\\\"" webui/config/index.html`
- 测试结果：`通过`
- 是否触发 git：`是，本次达到 3/3，需执行 checkpoint commit 并 push`
