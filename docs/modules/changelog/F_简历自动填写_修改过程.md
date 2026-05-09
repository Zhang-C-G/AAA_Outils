# 模块修改过程记录：F 简历自动填写

最近同步：`2026-04-27`  
状态：`active`

## 1. 当前状态

- 核心范围：资料字段、映射、自动填写入口
- 当前重点：字段编辑稳定、公司链接界面布局清晰、内容从顶部起排

## 2. 修改记录

### 2026-04-26 / 初始建档
- 改动内容：
  - 建立模块修改过程文档，后续独立记录 F 模块演进
- 测试：
  - 文档创建校验
- 测试结果：`通过`

### 2026-04-26 / 删除保存按钮并切到自动保存
- 改动内容：
  - 删除 Web 端 F 模块“保存简历资料”按钮
  - 删除 AHK 配置界面 F 模块 “Save Resume Config” 按钮
  - F 模块改为字段变更后自动保存，符合“不喜欢保存按钮”的个人偏好
- 测试：
  - 代码校验：确认 `resumeSaveBtn` 已从 `index.html` 与 `app-resume.js` 移除
  - 代码校验：确认 AHK F 模块已改为自动保存链路
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk`
- 测试结果：`通过`

### 2026-04-26 / 公司链接维护界面第一阶段 UI
- 改动内容：
  - F 模块头部新增一行“进入公司链接界面”提示条
  - 点击后，主编辑区切换为“公司 / 链接地址 / 允许填充”维护表
  - 当前只做 UI，不接后端自动填充逻辑
- 测试：
  - 代码校验：确认 F 模块新增 `resumeCompanyPanel` 与切换按钮
  - 代码校验：确认 `app-resume.js` 已新增 `editor_mode` 与公司链接表渲染
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk`
- 测试结果：`通过`

### 2026-04-27 / 公司链接界面贴顶修正
- 改动内容：
  - 修正 F 模块公司链接界面布局
  - `resume-subview` 改为贴顶栅格流式布局
  - `resume-table-wrap` 改为贴顶对齐，避免公司表格被压到界面下方
- 测试：
  - 代码校验：确认 `styles.css` 已新增 `.resume-subview` 与 `.resume-table-wrap` 的贴顶样式
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk`
  - 进程校验：延迟复查后确认当前仅存在 1 个 `AutoHotkey64.exe` 实例
- 测试结果：`通过`

### 2026-04-27 / 字段页与公司页内容改为顶部起排
- 改动内容：
  - 字段页 `值` 输入区继续使用 `textarea`，并统一为顶部起排、向下自动扩展
  - 公司页的“公司名称 / 链接地址”改为 `textarea`
  - 公司页内容同样从顶部开始显示，并随内容向下扩展
  - 公司页编辑、新增、删除也纳入自动保存
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg` 确认公司页已改为 `textarea`，并且样式包含 `min-height: 72px` 与顶部对齐设置
  - 通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk`
  - 延迟复查后确认当前仅存在 1 个 `AutoHotkey64.exe` 实例
- 测试结果：`通过`
- 
### 2026-05-09 / 公司链接维护改为公司投递面板
- 改动内容：
  - F 模块公司维护表由“公司 / 链接地址 / 允许填充”调整为“选择 / 公司名称 / 公司类型 / 投递进度 / 链接地址 / 操作”
  - 公司类型改为固定选项：`国企 / 民企 / 外企`
  - 投递进度改为固定选项：`未投递 / 已投递 / 已挂 / 已经一面 / 已经二面 / OFFER / 暂不投递`
  - 默认新建公司记录的投递进度为 `未投递`
  - 新增“投递选中公司”按钮，可批量勾选多家公司后统一打开对应投递链接
  - 批量投递后，已成功打开链接的公司会自动把进度切到 `已投递`
  - 公司维护数据已接入后端保存链路，不再只是前端临时 UI
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `[System.Management.Automation.Language.Parser]::ParseFile(...)`
- 测试结果：`已通过`

### 2026-05-09 / 公司投递面板补公司规模、岗位类型与筛选器
- 改动内容：
  - 在 F 模块公司维护表中新增 `公司规模` 列：`大 / 中 / 小`
  - 在 F 模块公司维护表中新增 `岗位类型` 列：`日常实习 / 转正实习 / 正式工作`
  - 公司投递表顶部新增筛选器区域，支持按 `关键词 / 公司类型 / 公司规模 / 岗位类型 / 投递进度` 过滤
  - 对齐私人偏好：多维维护表默认优先采用“筛选器 + 表格”组合，而不是只做纯表格横向堆列
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `[System.Management.Automation.Language.Parser]::ParseFile(...)`
  - `Invoke-WebRequest http://127.0.0.1:8798/api/resume/state`
- 测试结果：`已通过`

### 2026-05-09 / 公司投递面板补官方链接
- 改动内容：
  - 为 `resume_profile.json` 中的 50 家目标公司补入链接
  - 优先填写官方招聘页；如未单独维护稳定招聘入口，则回填官方站点或官方公司页
  - 便于后续在 F 模块中直接点击进入公司侧页面继续投递或二次维护
- 测试：
  - `Get-Content -Raw -Encoding UTF8 resume_profile.json | ConvertFrom-Json`
  - 校验 `company_links.Count = 50`
  - 校验空链接数量为 `0`
- 测试结果：`已通过`

### 2026-05-09 / 公司链接地址支持点击跳转
- 改动内容：
  - F 模块公司投递表的链接地址列改为“上方直接跳转链接 + 下方继续编辑输入框”
  - 链接为空时显示 `暂无链接`
  - 输入未带协议头时，跳转时自动补全为 `https://`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resume-company-url|url-preview|normalizeExternalUrl" webui/config/app-resume.js webui/config/styles.css`
- 测试结果：`已通过`

### 2026-05-09 / 公司投递表改为列头圆点筛选，链接列收口为单编辑框
- 改动内容：
  - 删除 F 模块公司投递表顶部整排筛选器
  - 改为在每个可筛选列标题右侧仅保留一个小圆按钮，点击后再展开对应筛选项
  - 链接地址列不再同时显示“链接文本 + 输入框”两个入口
  - 改为“单一可编辑链接框 + 单独跳转按钮”组合，既能修改，也能点击跳转
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resumeCompanyFilterKeyword|resume-company-filters|url-preview|resume-company-url-link|resume-filter-dot|resumeCompanyFilterCompany|open-url" webui/config/app-resume.js webui/config/index.html webui/config/styles.css`
- 测试结果：`已通过`

### 2026-05-09 / 公司投递表选择项按值着色
- 改动内容：
  - F 模块公司类型、公司规模、岗位类型、投递进度改为“不同选项值对应不同颜色”
  - 让国企/民企/外企、大/中/小、实习/转正/正式、未投递/已投递/OFFER/已挂等状态更容易一眼区分
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "syncCompanySelectTheme|data-role=|data-value=|resume-company-select\\[data-role" webui/config/app-resume.js webui/config/styles.css`
- 测试结果：`已通过`

### 2026-05-09 / 公司投递表筛选改为顶部筛选条
- 改动内容：
  - 列头 `筛` 按钮不再弹出悬浮筛选框
  - 改为点击后按钮进入绿色激活态，并在表格上方出现对应筛选条
  - 筛选条为顶部固定区域，不悬浮在表头旁边
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resumeCompanyFilterBar|resume-filter-popover|resumeCompanyFilterCompanyPanel|resume-company-filter-bar|resume-filter-dot.active" webui/config/app-resume.js webui/config/index.html webui/config/styles.css`
- 测试结果：`已通过`
