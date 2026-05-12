# 模块修改过程记录：B 笔记

最近同步：`2026-04-28`
状态：`active`

## 1. 当前状态
- 核心范围：笔记列表、标题、Markdown 内容、保存、删除、结构目录、模块筛选
- 当前重点：从“小笔记编辑器”重构为适合几十万字私人笔记的三栏结构

## 2. 修改记录

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
