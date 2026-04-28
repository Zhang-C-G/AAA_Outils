# 改动流水文档

最近同步：`2026-04-28`
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。  
满 3 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-04-28-post-notes-stage1-checkpoint`
- 当前连续改动次数：`3`
- 本轮目标：
  - 压缩 B 模块第一阶段说明条的占位
  - 保留说明信息但不抢主工作区
  - 让 B 模块目录语义回到“笔记目录”，并补上“结论式开场”提取区
  - 让左侧笔记栏本身可缩放，减少列表区域长期占位
- 上一个 git 检查点：`checkpoint: rebuild notes stage1 shell`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 1-3 次改动窗口

### 第1次改动
- 时间：`2026-04-28`
- 内容：
  - 将 B 模块顶部说明条改为默认收起的可折叠小说明条
  - 说明条只保留一行标题和展开入口，点开后才展示正文说明
  - 维持原有说明内容，不再长期占据主编辑区域上方空间
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `webui/config/app-notes.js`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "notesExplainBar|toggleNotesExplainBtn|notes-explain-toggle|notes-explain-body|notesExplainCollapsed" webui/config/index.html webui/config/styles.css webui/config/app-notes.js`
  - `scripts/restart_main_ahk.ps1`
  - 重启后确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`
- 是否触发 git：`否`

### 第2次改动
- 时间：`2026-04-28`
- 内容：
  - 将 B 模块中的“模块筛选”语义改回“笔记目录”
  - 目录 chips 改为“全部目录”与目录块选择，不再误用“模块”概念
  - 新增“提取”区，专门从 Markdown 中提取 `**结论式开场：**`
  - 当 `结论式开场` 后紧跟正文内容时，会单独列出以便快速观看
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `webui/config/app-notes.js`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "模块筛选|全部模块|selectedModuleKey|notesExtractList|结论式开场|笔记目录|全部目录" webui/config/index.html webui/config/styles.css webui/config/app-notes.js`
  - `scripts/restart_main_ahk.ps1`
  - 重启后确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`
- 是否触发 git：`否`

### 第3次改动
- 时间：`2026-04-28`
- 内容：
  - 将 B 模块左侧“新建笔记 / 删除笔记 / 笔记列表”整列改为可缩放侧栏
  - 新增“收起列表 / 展开列表”入口
  - 侧栏收起后左列宽度明显缩小，仍保留笔记切换能力
  - 纠正本轮折叠目标，避免把说明条当成主缩放对象
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `webui/config/app-notes.js`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "toggleNotesSidebarBtn|notesLayoutRoot|sidebar-compact|notesSidebarCompact|收起列表|展开列表" webui/config/index.html webui/config/styles.css webui/config/app-notes.js`
  - `scripts/restart_main_ahk.ps1`
  - 重启后确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`
- 是否触发 git：`是，已达到 3/3 checkpoint 阈值`
