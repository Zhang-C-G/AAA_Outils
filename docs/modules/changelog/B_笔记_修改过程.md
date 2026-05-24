# 模块修改过程记录：B 笔记

最近同步：`2026-05-24`
状态：`active`

## 1. 当前状态
- 核心范围：笔记列表、标题、Markdown 内容、最终版本编辑、自动保存、结构目录、提取、导出、正文头部工作带
- 当前重点：继续收紧正文工作区主路径，包括头部操作组织、目录标签稳定显示、`最终版本 -> Markdown` 定位体感

## 1.1 2026-05-18 归档摘要

- 本轮已归档为 4 组能力：
  - `最终版本` 结构与视觉强化
  - 选区着色与持久化
  - 自动保存与列表项结构编辑修复
  - 当前笔记导出
- 对应模块化文档入口：
  - 模块主文档：`docs/modules/04_notes.md`
  - 第二阶段能力说明：`docs/modules/04C_B模块最终版本编辑与导出能力说明.md`
  - 相关偏好文档：`02_编辑态与光标偏好.md`、`04_自动保存与保存按钮偏好.md`、`16_结构目录偏好.md`、`17_笔记类目录与正文工作区偏好.md`

## 2. 修改记录

### 2026-05-24 / 引入 note session 深模块，收口 B 笔记会话状态
- 改动内容：
  - 基于 `improve-codebase-architecture` 的架构检测结果，开始把 B 笔记工作区中的“保存 / 切换 / restore / 版本戳 / unload flush”从 `app-notes.js` 抽离为独立的 `app-note-session.js`
  - 新模块先承接笔记会话状态、保存队列、编辑器绑定、已加载版本戳、切换串行链
  - `app-notes.js` 开始退回到工作区 UI 与 DOM orchestration 角色，避免继续同时承担工作区展示和状态机实现
  - 本轮同时修复了 `app-notes.js` 中一批会阻断语法与维护的损坏文案，作为继续 deepening 的前置清障
  - 当前主运行路径已经完成切换：`saveCurrentNote`、`selectNote`、`loadNotes`、`loadNoteContent`、`applyNotesDraftState` 全部改为通过 `app-note-session.js` 工作
  - 旧的工作区内会话状态残留已从 `app-notes.js` 清理，Notes workspace module 现已更明确地只保留 DOM orchestration 与工作区交互
- 影响文件：
  - `webui/config/app-note-session.js`
  - `webui/config/app-notes.js`
  - `CONTEXT.md`
  - `docs/architecture/SKILL_ORCHESTRATION.md`
  - `docs/architecture/DEPENDENCY_MAP.md`
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-note-session.js`
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
- 测试结果：`通过`

### 2026-05-24 / 切换笔记串行化、防串写与已加载版本戳
- 改动内容：
  - `selectNote` 改为串行链式切换，避免用户连续点击多条笔记时并发执行多个切换流程
  - 切换前先按当前绑定笔记 ID 快照编辑器内容，再以该快照保存离开中的笔记，避免 A 笔记正文被误写入 B 文件
  - `loadNoteContent` 增加切换世代号校验，过期加载结果直接丢弃
  - 笔记加载结果新增 `updatedAt`，前端同步记录 `noteLoadedRevision` 与最近已保存版本，用于刷新恢复和 dirty 清理判断
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "noteSwitchGeneration|noteSwitchChain|captureNoteEditorPayload|noteLoadedRevision|updatedAt" webui/config/app-notes.js webui/config/server-notes.ps1`
- 测试结果：`通过`

### 2026-05-24 / 图片资源文件化与保存后规范化正文回写
- 改动内容：
  - B 笔记保存前，后端开始扫描 Markdown 中的 `data:image/...;base64,...` 图片
  - 图片内容按哈希写入 `webui/config/note-assets/<note-id>/`，正文引用统一改写为 `/note-assets/<note-id>/<sha>.<ext>`
  - 保存成功后，前端接受服务端返回的规范化正文，确保编辑器内容、落盘 Markdown 与后续导出使用同一份标准图片路径
  - 目标是避免把超长 base64 常驻写入 `notes/*.md`，同时让粘贴图片后的刷新恢复更稳定
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "Convert-EmbeddedNoteImagesToFiles|Get-NoteAssetDir|note-assets|response.content !== content" webui/config/server-notes.ps1 webui/config/app-notes.js`
- 测试结果：`通过`

### 2026-05-20 / 正文头部双行工作带、手动保存与文本锚点定位
- 改动内容：
  - 正文头部操作改为上下两行：第一行左侧固定显示保存状态点与字数，第一行右侧放小搜索框与手动保存按钮，第二行放导出区与 `Markdown / 最终版本` 切换
  - 删除正文标题文字，避免头部控件拥挤；手动“保存”按钮改为只补充触发现有保存链路，不改变自动保存优先级
  - `最终版本 -> Markdown` 切换定位从“标题锚点 / 滚动比例”收紧为“当前可见正文文本锚点优先”，减少切回源码时明显跳偏
  - 目录项后方的 `H1 / H2 / H3` 层级标签改为固定不可收缩，长标题只截断标题文字本身，不再把层级标签挤没
  - 本轮文档归档拆为独立子能力说明 `04D_B模块正文头部与定位联动说明.md`，并同步修正自动保存/正文工作区/结构目录三份相关私人偏好文档
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "notes-content-head-row|saveCurrentNoteBtn|noteContentSearch|capturePreviewPosition|getPreviewTextAnchor|findSourceIndexByAnchorText|level-label|outline-text" webui/config/index.html webui/config/styles.css webui/config/app-notes.js`
  - `rg -n "04D_B模块正文头部与定位联动说明|文本锚点|双行工作带|层级标签改为固定不可收缩" docs -S`
- 测试结果：`通过`

### 2026-05-20 / 正文头部搜索框接入 Enter 跳转
- 改动内容：
  - 将 B 笔记正文头部搜索框从纯展示壳接成真实可用的轻量搜索跳转
  - 在 `Markdown` 视图下，按 `Enter` 会跳到下一个关键词匹配位置，`Shift + Enter` 反向跳转
  - 在 `最终版本` 视图下，按关键词匹配正文文本节点并滚动到对应位置，同时对命中块追加短暂高亮
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "noteContentSearch|navigateNoteSearch|navigateMarkdownSearch|navigateRenderedSearch|notes-search-hit" webui/config/app-notes.js webui/config/styles.css`
- 测试结果：`通过`

### 2026-05-20 / 最终版本保存前强制同步源码
- 改动内容：
  - 新增统一同步兜底：只要当前停在 `最终版本`，手动保存、自动保存、导出前保存与刷新前卸载保存都会先把当前正文 DOM 强制序列化回 `noteContent`
  - 不再依赖 `notesPreviewEditing` 恰好保持为 `true` 才触发回写，降低图片、粘贴、拖放内容“看起来已显示/已保存，刷新后却丢失”的概率
  - 这次修正的目标是优先保证“当前看到的最终版本正文”与真正落盘的 Markdown 源码一致
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "syncRenderedNoteSourceFromPreview|syncPreviewEditToSourceForUnload|saveCurrentNote\\(|exportCurrentNote\\(" webui/config/app-notes.js`
- 测试结果：`通过`

### 2026-05-12 / 抽离 B 的通用工作区模板层
- 改动内容：
  - 正式将 B 模块中的“列表 + 目录 + 正文工作区”通用层从 B 专属说明中抽离出来，作为独立模板文档沉淀
  - 在 B 的第一阶段文档中明确区分“通用工作区模板层”和“B 模块专属扩展层”
  - 为后续 C 模块及其他类似模块提供可执行的继承基线，减少只继承大结构、不继承细节的情况
- 测试：
  - 文档一致性人工校对
- 测试结果：`通过`

### 2026-05-01 / 提取内容回写时的错误分段修复
- 改动内容：
  - 提取结果保存时，分段识别从“看到任意 `###` 就切段”改为“优先按本次提取生成的固定片段标题切段”
  - 避免用户在提取正文里正常输入或保留 `###` 标题时，被系统误判为“片段数量变化”
  - 仅在无法匹配本次提取标题时，才回退旧的通用 `###` 分段逻辑
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "getExtractSegmentTitle|parseExtractSegments\\(|parseExtractSegmentsLegacy|segmentTitles" webui/config/app-notes.js`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / Markdown 正文框焦点反馈对齐最终版本
- 改动内容：
  - `Markdown` 正文框新增自定义 `:focus` 样式，去掉浏览器原生白色高亮闪变
  - 焦点反馈改为与 `最终版本` 正文框同方向的低打扰内描边
  - 对应交互偏好同步写入“笔记类目录与正文工作区偏好”
- 测试：
  - `rg -n "notes-source-textarea:focus|notes-preview-body:focus" webui/config/styles.css`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / Markdown 视图目录跳转定位
- 改动内容：
  - 目录点击在 `Markdown` 视图下不再强制切去 `最终版本`
  - 当用户当前停留在 `Markdown` 视图时，目录点击会直接把正文文本框定位到对应标题行
  - Markdown 定位从“按源码行号粗算”改为“按文本框真实可视行数估算”，让跳转手感更接近 `最终版本`
  - 目录跳转时不再主动抢占 Markdown 文本框焦点，去掉顶部白色亮边闪烁
  - 保持 `最终版本` 视图继续沿用原有预览区定位逻辑
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "scrollSourceToHeading|countWrappedVisualLines|getSourceHeadingScrollTop|selectionStart = cursor" webui/config/app-notes.js`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / 提取工具显隐状态持久化
- 改动内容：
  - `显示提取 / 隐藏提取` 状态接入应用配置持久化
  - 刷新页面、重新打开后，默认恢复到上次的提取工具展开或折叠状态
  - 对齐通用偏好里的“页面切换 / 面板显隐类按钮默认记住上次状态”
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-common.js`
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "notes_extract_collapsed|notes-extract-collapsed|persistNotesExtractCollapsed" webui/config`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-26 / 笔记列表拖拽排序
- 改动内容：
  - 笔记左侧罗列框支持拖拽调整顺序
  - 顺序通过 `notes/_order.json` 持久化保存
  - 后端新增 `/api/notes/reorder`
- 测试：
  - 重启 `main.ahk`
  - 实测 `/api/notes/reorder`
  - 确认 `notes/_order.json` 生成
- 测试结果：`通过`

### 2026-04-26 / 笔记删除确认改为单次自定义弹窗
- 改动内容：
  - 笔记删除不再使用浏览器默认 `confirm()`
  - 原有两次确认收敛为一次确认
  - 删除确认改为应用内自定义弹窗
- 测试：
  - 代码校验：确认 `deleteNoteBtn` 已改为 `await confirmDialog(...)`
  - 全局搜索：确认笔记删除链路不再有两次确认
- 测试结果：`通过`

### 2026-04-28 / 第一阶段重型笔记结构重构
- 改动内容：
  - B 模块页面由“笔记列表 + 正文编辑”双栏改为“笔记列表 + 结构目录/模块筛选 + 正文编辑”三栏
  - 新增第一阶段说明条，明确当前为重型笔记重构期
  - 从当前 Markdown 正文中前端抽取标题目录
  - 新增“复制目录”按钮
  - 模块筛选以 H1/H2 作为第一阶段默认结构锚点
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "copyNoteOutlineBtn|notesModuleChips|notesOutlineList|renderNoteStructure|parseNoteStructure" webui/config/index.html webui/config/app-notes.js`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / 结构目录点击定位正文
- 改动内容：
  - 结构目录点击后，正文框内部会滚动到对应标题位置
  - 当前点击的目录项增加轻量激活态
  - 正文被定位到的标题增加短暂高亮反馈
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "focusOutlineHeading|activeOutlineHeadingId|notes-preview-active-heading|notes-outline-item.active" webui/config/app-notes.js webui/config/styles.css`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / Markdown 与最终版本双视图切换
- 改动内容：
  - B 模块正文区新增 `Markdown` 与 `最终版本` 两个切换入口
  - `Markdown` 视图直接展示原始输入内容
  - `最终版本` 视图展示转换后的正文效果
  - 两个视图仍共用同一份内容与自动保存链路
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "notesViewMarkdownBtn|notesViewRenderedBtn|notesContentView|notes-source-textarea.visible" webui/config/index.html webui/config/app-notes.js webui/config/styles.css`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / 目录跳转修正与白底激活态
- 改动内容：
  - 目录点击时如当前停在 `Markdown` 视图，会先切回 `最终版本` 再执行正文定位
  - 目录跳转改为按正文滚动容器的真实相对位置计算，避免点第三项却不落到第三项
  - 当前目录项激活态改为整行白底
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "scrollPreviewToHeading|notesContentView !== 'rendered'|notes-outline-item.active" webui/config/app-notes.js webui/config/styles.css`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / 自动保存失败兜底与 Markdown 视图尺寸修正
- 改动内容：
  - `api()` 在遇到一次 `TypeError / Failed to fetch` 时会短暂等待后自动重试一次
  - 笔记保存失败时继续保留脏状态，并重新挂起下一轮自动保存
  - `Markdown` 视图的编辑窗口改为与 `最终版本` 使用同尺寸工作区
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "scheduleNotesAutosave\\(|Failed to fetch|notes-source-textarea.visible|grid-template-rows: auto minmax\\(0, 1fr\\)" webui/config/app-common.js webui/config/app-notes.js webui/config/styles.css`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / Markdown 视图高度分配修正
- 改动内容：
  - 右侧正文区改为单主工作行布局
  - `Markdown` 与 `最终版本` 共用固定高度正文工作区
  - 避免 `Markdown` 视图仍缩成一小块
- 测试：
  - `rg -n "height: 684px|grid-template-rows: minmax\\(0, 1fr\\)|align-self: stretch" webui/config/styles.css`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / Markdown 标签行与换行渲染修正
- 改动内容：
  - `**结论式开场：**`、`**主体：**` 这类独立加粗标签行改为单独成块渲染
  - 普通段落在预览中改为保留原始换行，不再强行用空格并成一段
  - 避免“最终版本”把标签行吞成普通正文、同时丢掉换行感
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "standaloneStrongMatch|paragraph\\.join\\('\\n'\\)|notes-preview-label" webui/config/app-notes.js webui/config/styles.css`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / 最终版本回写时保留 Markdown 加粗标记
- 改动内容：
  - 从“最终版本”回写 Markdown 时，保留 `**粗体**`、`*斜体*`、`` `code` `` 标记
  - 避免一切到最终版本、再切回 Markdown 后，星号表达方式被自动去掉
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "collectInlineMarkdown|\\*\\*\\$\\{inner\\}\\*\\*|\\*\\$\\{inner\\}\\*|`\\$\\{inner\\}`" webui/config/app-notes.js`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / 目录跳转延迟收敛
- 改动内容：
  - 目录点击后的正文定位由平滑滚动改为即时定位
  - 去掉多余的二次等待与帧调度，减少点击后约 1 秒的拖沓感
  - 结构目录偏好补充为“跳转反馈优先即时响应”
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "scrollTop = nextTop|优先即时响应|明显延迟" webui/config/app-notes.js docs/extension/global_preferences/components/16_结构目录偏好.md`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / 目录点击路径减重
- 改动内容：
  - 目录点击时不再重绘整块目录列表，只同步当前激活项 class
  - 目录点击后不再强制 `focus()` 正文区
  - 正文标题高亮改为复用当前激活节点引用，减少不必要查询
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "syncActiveOutlineHeading|activePreviewHeadingEl|previewEl\\.focus\\(" webui/config/app-notes.js`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / 提取结果显示真实目录标题
- 改动内容：
  - 提取链路保留每个片段对应的 `headingTitle`
  - 提取结果中的 `###` 标题优先显示真实目录名，不再回退成“片段一 / 片段二 / 片段三”
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "headingTitle: range.headingTitle|片段 \\$\\{index \\+ 1\\}" webui/config/app-notes.js`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / 三条常驻提取线
- 改动内容：
  - 提取工具由单条 `从 / 到` 提取线改为三条常驻提取线
  - 不显示“需求一 / 需求二 / 需求三”文字，减少占位
  - 每一条提取线都可独立执行
  - `恢复正文 / 隐藏提取` 保持为共享操作
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "notesExtractStart1|notesExtractStart2|notesExtractStart3|EXTRACT_SLOTS|runNotesExtractBtn3" webui/config/index.html webui/config/app-notes.js`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / 目录层级标识颜色
- 改动内容：
  - 目录项后方的层级标识颜色改为：`H1` 绿色且更重、`H2` 蓝色且稍微加粗、`H3` 灰色
  - 结构目录偏好同步写入这套层级颜色语义
- 测试：
  - `rg -n "level-1 \\.level-label|level-2 \\.level-label|font-weight: 700|font-weight: 600|H1.*更重.*H2.*蓝色.*稍微加粗" webui/config/styles.css docs/extension/global_preferences/components/16_结构目录偏好.md`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / 恢复正文不再被保存失败阻断
- 改动内容：
  - `恢复正文` 按钮优先保证返回正文视图
  - 即使提取结果保存失败，也不再整条恢复链一起报错中断
  - 保存失败时改为给出提示，并直接恢复正文
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "allowDiscardOnFailure|提取内容保存失败，已直接恢复正文|恢复正文失败" webui/config/app-notes.js`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / 隐藏提取后保留斜线背景
- 改动内容：
  - 提取工具折叠后仍保留原有斜线纹理背景
  - 不再在折叠态退成透明空条
  - 说明条偏好同步写入“折叠后仍保留纹理背景”
- 测试：
  - `rg -n "notes-extract-tool\\.collapsed|repeating-linear-gradient|折叠后默认仍保留斜杠纹理背景" webui/config/styles.css docs/extension/global_preferences/components/15_说明条偏好.md`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / Web 配置页前端改动纳入服务重启判断
- 改动内容：
  - Web 配置服务的“需要重启”判断新增监控 `index.html / *.js / *.css`
  - 避免前端文件已经改了，但本地配置服务继续挂着旧版本
  - 修复“Ctrl+F5 也刷不到最新前端，必须再次重启后才像生效”的问题来源
- 测试：
  - `rg -n "\\\\*.html|\\\\*.css|\\\\*.js|GetWebConfigSourceLatestWriteTime" src/web_config.ahk`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-04-28 / 目录列与正文列统一高度基准
- 改动内容：
  - 结构目录列改为与正文列相同的固定总高度
  - 左右两列头部行高统一
  - 目录列表区域改为吃掉同样的剩余高度，避免上下边线不齐
- 测试：
  - `rg -n "notes-structure-panel|height: 684px|min-height: 32px|notes-outline-list" webui/config/styles.css`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-05-18 / 最终版本 Markdown 元素颜色强化
- 改动内容：
  - 仅对 B 笔记模块的“最终版本”预览区追加颜色语义，不影响 Markdown 源码编辑区
  - 无序列表项目符号改为绿色，有序列表序号改为蓝色，提升层次识别
  - 行内代码与代码块追加独立蓝色系底色和文字色，避免与正文混成一层
  - 引用块同步改为偏蓝强调色，保证正式态下列表、引用、代码块都有独立视觉区分
- 测试：
  - `rg -n "#notePreviewBody\\.notes-preview-body ul > li::marker|#notePreviewBody\\.notes-preview-body pre code|#notePreviewBody\\.notes-preview-body :not\\(pre\\) > code" webui/config/styles.css`
- 测试结果：`通过`

### 2026-05-18 / H1 目录默认折叠并悬浮展开
- 改动内容：
  - B 笔记目录区改为按 `H1` 分组渲染，`H1` 下属的 `H2+` 默认折叠
  - 鼠标悬浮在对应 `H1` 分组时，当前组的下属目录临时展开；离开当前组后再自动折回
  - 该交互只对 `H1` 生效，其他层级本身不增加额外折叠规则
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "notes-outline-group|notes-outline-children|notes-outline-item-h1|heading.level !== 1" webui/config/app-notes.js webui/config/styles.css`
- 测试结果：`通过`

### 2026-05-18 / 正文选区悬浮着色工具
- 改动内容：
  - B 笔记“最终版本”正文区新增选区悬浮工具条，选中文字后可直接追加文字色或背景色
  - 颜色能力只接在 B 模块正式态内容区，不影响 Markdown 源码编辑区，也不外溢到其他模块
  - 选区着色结果会回写为可持久化标记，保证自动保存、刷新恢复、再次打开后仍然保留
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `node --check --experimental-default-type=module webui/config/app-markdown.js`
  - `rg -n "notes-selection-toolbar|data-note-color|data-note-bg|applySelectionColor" webui/config/app-notes.js webui/config/app-markdown.js webui/config/styles.css`
- 测试结果：`通过`

### 2026-05-18 / 二次改色改为覆盖同类旧色
- 改动内容：
  - 第二次修改文字色时，不再在第一次文字色外层继续叠加，而是替换当前选中范围内原有的文字色
  - 第二次修改背景色时，同样替换当前选中范围内原有的背景色
  - 同类样式按“覆盖”处理，不同类样式仍允许共存，例如“有文字色 + 有背景色”
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "replaceStyleInsideSingleSpan|stripSelectionStyleFromFragment|getSelectionStyleAttrName" webui/config/app-notes.js`
- 测试结果：`通过`

### 2026-05-18 / 正文修改默认保存收紧
- 改动内容：
  - 保留正文输入过程中的自动保存
  - 正文失焦时追加一次静默保存，减少“改完离开正文但仍停留在本页”时的未落盘窗口
  - 选区改色这类非键盘正文修改在回写 Markdown 后会立即进入静默保存
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "forceSaveCurrentNoteSilently|previewEl\\.addEventListener\\('blur'|applySelectionColor" webui/config/app-notes.js`
- 测试结果：`通过`

### 2026-05-18 / 正式态列表项可退回普通正文
- 改动内容：
  - 正式态正文里，当光标位于列表项开头时，按 `Backspace` / `Delete` 会去掉该行列表格式
  - 去掉列表格式后，这一行会从 `-` 列表项退回为普通正文段落
  - 正文段落与列表项显式声明为可选中文本，缓解中文内容编辑时的“像选不中”手感
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "handlePreviewListMarkerDelete|unwrapEditableListItem|isCaretAtListItemStart|user-select: text" webui/config/app-notes.js webui/config/styles.css`
- 测试结果：`通过`

### 2026-05-18 / 修复去掉列表标记后自动保存吞字
- 改动内容：
  - 修复正式态里“去掉 `-` 列表格式”后生成无效 DOM 结构的问题
  - 当前改为把目标行从原列表中真正拆出，前后列表分别保留，普通正文放到列表外层
  - 避免自动保存并重新渲染后，这一行正文被错误吞掉
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "beforeItems|afterItems|parentList\\.replaceWith\\(replacement\\)" webui/config/app-notes.js`
- 测试结果：`通过`

### 2026-05-18 / 当前笔记导出功能
- 改动内容：
  - B 笔记正文头部新增导出格式选择与“导出当前笔记”按钮
  - 当前支持 `Markdown / HTML / PDF / TXT / JSON` 五种导出格式
  - 导出前会优先同步正式态编辑内容并静默保存，尽量保证导出的就是当前最新版本
  - 提取视图下暂不允许直接导出当前笔记，避免把聚合提取内容误导出为单条笔记
  - `PDF` 当前采用本地后端 + 浏览器无头导出链路，直接下载真实 `.pdf` 文件
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "noteExportFormat|exportCurrentNoteBtn|buildExportHtmlDocument|triggerTextDownload|exportCurrentNote" webui/config/index.html webui/config/app-notes.js webui/config/styles.css`
- 测试结果：`通过`
