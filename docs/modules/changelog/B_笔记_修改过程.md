# 模块修改过程记录：B 笔记

最近同步：`2026-04-28`
状态：`active`

## 1. 当前状态
- 核心范围：笔记列表、标题、Markdown 内容、保存、删除、结构目录、模块筛选
- 当前重点：从“小笔记编辑器”重构为适合几十万字私人笔记的三栏结构

## 2. 修改记录

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
