# 模块修改过程记录：F 简历自动填写

最近同步：`2026-05-09`
状态：`active`

## 1. 当前状态

- 核心范围：资料字段、映射、自动填写入口
- 当前重点：字段编辑稳定、公司投递表可维护、表格规则与文档口径一致

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
  - 删除 AHK 配置界面 F 模块 `Save Resume Config` 按钮
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
  - 为 `resume_profile.json` 中的 50 家目标公司补全链接
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

### 2026-05-09 / 公司投递表改为列表头圆点筛选，链接列收口为单编辑框
- 改动内容：
  - 删除 F 模块公司投递表顶部整排筛选器
  - 改为在每一个可筛选列表头右侧仅保留一个小圆按钮，点击后再展开对应筛选项
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
  - `rg -n "resumeCompanyFilterBar|resume-filter-popover|resumeCompanyFilterCompanyPanel|resume-company-filter-bar|resume-filter-dot.active" webui/config/app-resume.js webui/config/index.html webui/config.styles.css`
- 测试结果：`已通过`

### 2026-05-09 / 颜色保留为侧边色标，下拉框恢复原色
- 改动内容：
  - 保留不同选项值的颜色区分
  - 颜色不再直接作用到下拉框本体
  - 下拉框恢复原本黑白风，颜色信息改为左侧小色标承载
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resume-company-select-wrap|resume-company-select-indicator|syncCompanySelectTheme" webui/config/app-resume.js webui/config/styles.css`
- 测试结果：`已通过`

### 2026-05-09 / 公司投递表补充分页，并修正公司名称输入框宽度
- 改动内容：
  - F 模块公司投递表增加底部分页区
  - 分页支持 `上一页 / 下一页 / 每页条数`
  - 当前页与每页条数接入保存链路与前端草稿恢复链路
  - 公司名称输入框不再横向撑满整格，改为按字段自身宽度贴合
  - 将本轮表格规则沉淀到“表格与筛选器偏好”，并建立第一个统一表格模板
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resumeCompanyPagination|company_table_view|resume-company-name-input|TABLE_STAGE1_TEMPLATE" webui/config/app-resume.js webui/config/index.html webui/config/styles.css webui/config/app-main.js docs/templates/TABLE_STAGE1_TEMPLATE.md`
- 测试结果：`已通过`

### 2026-05-09 / 顶部筛选条支持多个筛同时绿色
- 改动内容：
  - F 模块公司投递表的顶部筛选条从“单开一项”改为“可同时展开多项”
  - 多个 `筛` 按钮在同时使用时，允许同时保持绿色激活态
  - 顶部筛选区改为承载多个筛选块，而不是一次只显示一个
  - 表头选择入口收敛为勾选框本体，去掉额外文字
  - 顶部筛选条增加结果统计，筛选时直接显示当前命中的公司总数
  - 删除 `收起筛选` 按钮；筛选面板的展开与取消仅通过对应列表头圆点控制
  - 公司名称与链接地址输入框改为默认单行显示，只有手动回车后才扩展为多行
  - 顶部筛选区整体压缩为更紧凑的工具条样式，减少高度与留白占用
  - 修正公司名称与链接地址输入框的视觉高度，避免被表格通用 `textarea` 样式继续撑成多行外观
  - 删除筛选卡片里的重复字段名，只保留一层标题
  - 收窄公司名称列宽度，减少表格横向占用
  - 将表头勾选框调整为列内真正居中显示
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resume-company-select-head|resume-company-select-all|justify-content: center" webui/config/index.html webui/config/styles.css`
- 测试结果：`已通过`

### 2026-05-09 / 正式文档与表格模板同步收口
- 改动内容：
  - 正式同步 F 模块说明文档，使其与当前“简历字段维护 + 公司投递维护”双工作区实现一致
  - 正式同步“表格与筛选器偏好”文档，沉淀已验证的表头筛选、顶部筛选条、分页、单行短文本编辑等规则
  - 正式同步第一阶段表格模板，作为后续同类模块复用入口
  - 补齐模块修改过程文档与本轮改动流水文档，保证实现、偏好、模板、过程四份口径一致
- 测试：
  - 文档一致性校对
  - `git log --oneline -5`
- 测试结果：`已通过`

### 2026-05-14 / 基础简历区改为四列配对布局并锁定字段名
- 改动内容：
  - 将 F 模块基础简历区从 `字段名 / 值 / 操作` 三列表改为一行两组 `字段名 + 值` 的四列布局
  - 基础简历区字段名改为只读展示，不再允许在前端直接修改
  - 删除基础简历区“操作”列，以及新增字段 / 删除字段入口
  - 将值输入框改为固定高度，不再随内容自动长高；内容超出时允许输入框内部上下滚动
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/modules/11_resume_autofill.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/extension/global_preferences/02_编辑态与光标偏好.md`
  - `docs/extension/global_preferences/components/18_表格与筛选器偏好.md`
  - `docs/ACTION_LOG.md`
  - `docs/DOC_CHANGELOG.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - 静态检视 `index.html` / `styles.css` / `app-resume.js`，确认基础简历区已移除字段名输入与删除入口
- 测试结果：`已通过`

### 2026-05-14 / 自动投递补通知、站点策略骨架与研究目录
- 改动内容：
  - F 模块信息变更后，改为通过右下角 toast 及时提示“已修改 / 正在自动保存 / 已自动保存”
  - 浏览器扩展拆出 `site-strategies.js`，建立“站点策略优先、通用填表回退”的执行骨架
  - 扩展弹窗补充策略命中日志，区分专用策略命中与通用回退命中
  - 新增 `docs/resume_autofill/` 研究目录，沉淀公司分析、动作策略和疑难问题台账
  - 建立 `Bilibili` 首个公司分析模板，作为截图分析入口
- 影响文件：
  - `webui/config/app-resume.js`
  - `browser_extension/resume_autofill/manifest.json`
  - `browser_extension/resume_autofill/content.js`
  - `browser_extension/resume_autofill/site-strategies.js`
  - `browser_extension/resume_autofill/popup.js`
  - `browser_extension/resume_autofill/README.md`
  - `docs/resume_autofill/README.md`
  - `docs/resume_autofill/strategy_notes.md`
  - `docs/resume_autofill/issue_log.md`
  - `docs/resume_autofill/company_analysis/README.md`
  - `docs/resume_autofill/company_analysis/bilibili.md`
  - `docs/modules/11_resume_autofill.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/ACTION_LOG.md`
  - `docs/DOC_CHANGELOG.md`
- 测试：
  - `node --check browser_extension/resume_autofill/content.js`
  - `node --check browser_extension/resume_autofill/site-strategies.js`
  - `node --check browser_extension/resume_autofill/popup.js`
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
- 测试结果：`已通过`

### 2026-05-14 / Bilibili 首版浏览器插件策略落地
- 改动内容：
  - 将 `browser_extension/resume_autofill/site-strategies.js` 从占位骨架升级为可执行的 Bilibili 专用策略
  - 基于本地 `resume_profile.json` 的 section/row 结构，补齐教育、实习、项目多段记录解析
  - 为 Bilibili 表单实现四段策略：
    - `basic_info_strategy`
    - `education_group_strategy`
    - `experience_group_strategy`
    - `project_group_strategy`
  - 实现标签文本定位、按需点击新增按钮、按序填充分组字段、时间区间写入与下拉文本选择
  - 保留“站点策略优先 + 通用回退填表”的双层执行结构
- 影响文件：
  - `browser_extension/resume_autofill/site-strategies.js`
  - `browser_extension/resume_autofill/README.md`
  - `docs/resume_autofill/README.md`
  - `docs/resume_autofill/company_analysis/bilibili.md`
  - `docs/modules/11_resume_autofill.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/ACTION_LOG.md`
  - `docs/DOC_CHANGELOG.md`
- 测试：
  - `node --check browser_extension/resume_autofill/site-strategies.js`
  - `node --check browser_extension/resume_autofill/content.js`
  - `node --check browser_extension/resume_autofill/popup.js`
- 测试结果：`已通过`

### 2026-05-14 / F 模块拆为“简历信息 / 公司信息”双页面入口
- 改动内容：
  - 将 F 模块原先“右上角文字入口切换”改为顶部双栏页面切换：`简历信息` / `公司信息`
  - `简历信息` 页面保留左侧分区导航与右侧字段表
  - `公司信息` 页面隐藏左侧分区导航，让公司投递表独占主区域
  - 继续复用既有 `editor_mode` 状态，记住用户上次停留页面
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `webui/config/app-resume.js`
  - `docs/modules/11_resume_autofill.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/ACTION_LOG.md`
  - `docs/DOC_CHANGELOG.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resumePageProfileBtn|resumePageCompaniesBtn|companies-mode|resumeSidebar" webui/config/index.html webui/config/styles.css webui/config/app-resume.js`
- 测试结果：`已通过`

### 2026-05-14 / F 模块补 Chrome 插件安装指南弹窗
- 改动内容：
  - 在 `简历信息` 页面补上 `安装 Chrome 插件` 入口
  - 点击后弹出安装指南，明确 `chrome://extensions/`、开发者模式、加载已解压扩展等步骤
  - 新增后端只读接口，自动识别本地扩展目录 `browser_extension/resume_autofill`
  - 弹窗中展示自动识别到的绝对路径，并提供一键复制按钮
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `webui/config/app-resume.js`
  - `webui/config/server-resume.ps1`
  - `webui/config/server.ps1`
  - `docs/modules/11_resume_autofill.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/ACTION_LOG.md`
  - `docs/DOC_CHANGELOG.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - PowerShell 脚本解析校验：`server-resume.ps1` / `server.ps1`
  - `rg -n "resumeInstallChromeExtensionBtn|resumeExtensionGuideHost|/api/resume/extension-install|Get-ResumeExtensionInstallState" webui/config`
- 测试结果：`已通过`

### 2026-05-14 / 安装指南弹窗补“打开扩展页 / 打开插件目录”
- 改动内容：
  - 在安装指南弹窗底部补上 `打开扩展页` 按钮，直接尝试打开 `chrome://extensions/`
  - 新增本地后端动作，支持从 Web UI 直接打开 `browser_extension/resume_autofill` 目录
  - 在安装指南弹窗底部补上 `打开插件目录` 按钮
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/app-resume.js`
  - `webui/config/server-resume.ps1`
  - `webui/config/server.ps1`
  - `docs/modules/11_resume_autofill.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/ACTION_LOG.md`
  - `docs/DOC_CHANGELOG.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - PowerShell 脚本解析校验：`server-resume.ps1` / `server.ps1`
  - `rg -n "resumeExtensionGuideOpenFolderBtn|resumeExtensionGuideOpenChromeBtn|/api/resume/open-extension-folder|Open-ResumeExtensionFolder" webui/config`
- 测试结果：`已通过`

### 2026-05-14 / F 模块头部再整理：分区下移、公司标题移除
- 改动内容：
  - `简历分区` 从左侧栏布局调整为放在顶部页面切换栏下方
  - `公司信息` 页面移除顶部 `公司信息` 四字标题，仅保留页面切换栏
  - `简历信息` 页面保留分区标题与分区列表，但不再采用左右双栏结构
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `webui/config/app-resume.js`
  - `docs/modules/11_resume_autofill.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
- 测试结果：`已通过`

### 2026-05-14 / 简历信息值输入改为按内容判断单行或多行
- 改动内容：
  - 不再将 `简历信息` 页的所有值字段统一渲染为多行 `textarea`
  - 普通短值改为单行输入
  - 明显长文本、描述类字段、带换行内容继续使用多行输入
  - 同步调整值区与字段名区高度，避免整表都被长输入框撑高
- 影响文件：
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/modules/11_resume_autofill.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
- 测试结果：`已通过`

### 2026-05-14 / 简历信息值输入进一步收紧为字段类型优先
- 改动内容：
  - 将 `简历信息` 页的值输入判断逻辑从“主要按内容长度和标签关键词”收紧为“字段类型优先”
  - `text/date/select` 默认走单行
  - `textarea` 默认走多行
  - 仅对非标准自定义字段保留内容特征兜底判断
- 影响文件：
  - `webui/config/app-resume.js`
  - `docs/modules/11_resume_autofill.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
- 测试结果：`已通过`

### 2026-05-14 / 简历页恢复左右布局并移除顶部当前分区标题
- 改动内容：
  - `简历信息` 页将 `简历分区` 与具体字段内容恢复为左右布局
  - 左侧为 `简历分区`，右侧为当前分区字段表
  - 顶部移除当前分区标题显示，不再展示 `基础信息` 一类标题文字
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `webui/config/app-resume.js`
  - `docs/modules/11_resume_autofill.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
- 测试结果：`已通过`

### 2026-05-14 / 新增蚂蚁集团投递页截图分析
- 改动内容：
  - 基于用户提供的蚂蚁集团招聘投递页截图，新增站点分析文档
  - 拆出个人信息、教育经历、实习/工作、项目经历、其他区的字段与控件类型
  - 明确蚂蚁集团页对教育背景字段的细粒度要求高于当前本地默认结构
  - 补充共享策略笔记，记录国家/地区下拉、手机号复合字段、标签式技术栈录入等新规则
- 影响文件：
  - `docs/resume_autofill/company_analysis/ant_group.md`
  - `docs/resume_autofill/company_analysis/README.md`
  - `docs/resume_autofill/strategy_notes.md`
  - `docs/modules/11_resume_autofill.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/ACTION_LOG.md`
  - `docs/DOC_CHANGELOG.md`
- 测试：
  - 文档静态校对
- 测试结果：`已通过`

### 2026-05-14 / 简历页顶线对齐并调整插件按钮位置
- 改动内容：
  - 将 `简历信息` 页左侧 `简历分区` 标题条与右侧主体顶部工具条对齐到统一水平线
  - 将 `安装 Chrome 插件` 按钮稳定放到右侧主体右上角
  - 为插件按钮所在工具条与按钮本身补上背景与边框承托，提升层级清晰度
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `docs/modules/11_resume_autofill.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
- 测试：
  - 静态检视 `index.html` / `styles.css`
- 测试结果：`已通过`

### 2026-05-14 / 安装插件按钮提升到顶部栏并跨页面常驻显示
- 改动内容：
  - 将 `安装 Chrome 插件` 按钮从 `简历信息` 子页面内部移到顶部页面切换栏右侧
  - 让按钮不再跟随 `简历信息 / 公司信息` 子页面切换而隐藏
  - 保持按钮在两个页面下都常驻显示，并保留独立背景承托
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `docs/modules/11_resume_autofill.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
- 测试：
  - 静态检视 `index.html` / `styles.css`
- 测试结果：`已通过`

### 2026-05-14 / 顶部切换栏与下方内容区增加垂直间距
- 改动内容：
  - 拉开 F 模块顶部切换栏块与下方主体块之间的垂直距离
  - 间距落点调整到 `resume-layout` 这一层，直接作用于上下两个兄弟块之间
  - `简历信息` 与 `公司信息` 两个子页面都继承这一层间距
- 影响文件：
  - `webui/config/styles.css`
  - `docs/modules/11_resume_autofill.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
- 测试：
  - 静态检视 `styles.css`
- 测试结果：`已通过`

### 2026-05-14 / 修复插件目录识别与安装弹窗打开动作
- 改动内容：
  - 修复安装弹窗对 `browser_extension/resume_autofill` 的目录识别，改为结合项目根目录、`resume_profile.json` 所在目录与脚本目录做多路探测
  - 修复 `打开插件目录` 动作，改为显式通过 `explorer.exe` 打开目标目录
  - 修复 `打开扩展页` 动作，改为通过后端接口触发 `chrome://extensions/`，避免前端 `window.open` 被浏览器策略拦截
- 影响文件：
  - `webui/config/app-resume.js`
  - `webui/config/server-resume.ps1`
  - `webui/config/server.ps1`
  - `docs/modules/11_resume_autofill.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
- 测试：
  - `Get-ResumeExtensionInstallState` 静态调用校验
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - PowerShell 脚本解析校验：`server-resume.ps1` / `server.ps1`
- 测试结果：`已通过`

### 2026-05-14 / 按最新简历截图回填 F 模块个人资料
- 改动内容：
  - 按用户提供的简历截图，修正 `resume_profile.json` 中的基础信息、求职期望、教育经历、实习经历、项目经历、获奖、语言与证书内容
  - 补入 `微信` 字段
  - 将 `自我介绍` 区补充为更完整的语言能力、交叉背景、软技能与技术栈摘要
- 影响文件：
  - `resume_profile.json`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
- 测试：
  - `node --input-type=module -e "JSON.parse(require('fs').readFileSync('resume_profile.json','utf8').replace(/^\uFEFF/, ''))"` 等价静态解析校验
  - 手工抽查关键字段：姓名、微信、期望岗位、教育经历、实习经历、项目经历、语言能力
- 测试结果：`已通过`

### 2026-05-14 / 新增携程投递页截图分析
- 改动内容：
  - 基于用户提供的携程站内简历页截图，新增站点分析文档
  - 拆出基本信息、教育背景、实习经历、项目经历、获奖经历、自我描述分区
  - 明确携程教育块字段粒度较细，且教育/实习/获奖日期更接近完整日期控件
  - 补充共享策略笔记，记录完整日期控件、项目职责最小映射、获奖列表映射等规则
- 影响文件：
  - `docs/resume_autofill/company_analysis/ctrip.md`
  - `docs/resume_autofill/company_analysis/README.md`
  - `docs/resume_autofill/strategy_notes.md`
  - `docs/modules/11_resume_autofill.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
- 测试：
  - 文档静态校对
- 测试结果：`已通过`

### 2026-05-14 / 优化教育经历结构以适配携程细粒度字段
- 改动内容：
  - 诊断出教育区问题主要来自三点：主摘要与分段明细口径不一致、时间/学历口径与携程页不一致、缺少导师/次专业/研究方向/GPA细分字段
  - 在 `resume_profile.json` 的教育区补入 `education_gpa`、`education_rank`、`second_major`、`research_direction`、`advisor`
  - 将四段教育经历统一整理为“学校/学院/城市/入学日期/毕业日期/学历/专业/GPA/成绩排名/次专业/研究方向/导师”的细粒度文本
  - 同步修正当前主教育摘要中的学历、时间与导师口径
- 影响文件：
  - `resume_profile.json`
  - `docs/resume_autofill/company_analysis/ctrip.md`
  - `docs/resume_autofill/strategy_notes.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
- 测试：
  - `resume_profile.json` 静态 JSON 解析校验
  - 手工抽查教育区字段：学历、时间、GPA/排名、导师、四段教育经历明细
- 测试结果：`已通过`

### 2026-05-14 / 教育经历改为可新增删除的多条维护
- 改动内容：
  - 将 F 模块教育经历从“单条摘要 + 若干长文本”继续推进为“多条结构化记录”的维护方式
  - 在编辑器中新增 `新增教育经历` 按钮，并为每条 `education_entry_*` 提供 `删除` 动作
  - 新增教育经历模板，统一字段口径为：学校、学院、城市、入学日期、毕业日期、学历、专业、GPA、成绩排名、次专业、研究方向、导师、专业主要课程
  - 调整浏览器扩展侧教育记录解析，优先识别 `入学日期 / 毕业日期`
- 影响文件：
  - `webui/config/app-resume.js`
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `webui/config/server-resume.ps1`
  - `browser_extension/resume_autofill/site-strategies.js`
  - `resume_profile.json`
  - `docs/modules/11_resume_autofill.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - PowerShell 脚本静态解析校验：`webui/config/server-resume.ps1`
  - `resume_profile.json` 静态 JSON 解析校验
- 测试结果：`已通过`
