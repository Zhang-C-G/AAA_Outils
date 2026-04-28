# 改动流水文档

最近同步：`2026-04-28`
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。  
满 3 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-04-28-post-notes-sidebar-checkpoint`
- 当前连续改动次数：`3`
- 本轮目标：
  - 收掉 B 模块目录区里不需要的说明和筛选占位
  - 只保留目录主体
  - 把提取功能改成真正可手动定义范围、跨笔记查看和修改的工具
  - 让结构目录的层级缩进更接近正常目录
- 上一个 git 检查点：`checkpoint: compact notes sidebar`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 1-3 次改动窗口

### 第1次改动
- 时间：`2026-04-28`
- 内容：
  - 删除目录区下面的小字说明
  - 删除目录 chips 和相关筛选语义
  - 删除提取区及其相关结构
  - 将目录区收口为只保留“结构目录 / 复制目录 / 目录罗列”
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `webui/config/app-notes.js`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "selectedDirectoryKey|notesStructureSummary|notesModuleChips|notesExtractList|renderDirectoryChips|renderExtractList|renderStructureSummary" webui/config/app-notes.js webui/config/index.html webui/config/styles.css`
  - `scripts/restart_main_ahk.ps1`
  - 重启后确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`
- 是否触发 git：`否`

### 第2次改动
- 时间：`2026-04-28`
- 内容：
  - 在正文区增加“提取工具”
  - 支持手动输入“从”和“到”的范围标记
  - 点击“执行提取”后，集中列出每条笔记命中的对应内容
  - 提取结果允许直接编辑，并自动写回对应原笔记内容
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `webui/config/app-notes.js`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "notesExtractStart|notesExtractEnd|runNotesExtractBtn|notesExtractResults|runNotesExtraction|extractRange|saveExtractResult|queueExtractSave" webui/config/index.html webui/config/styles.css webui/config/app-notes.js`
  - `scripts/restart_main_ahk.ps1`
  - 重启后确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`
- 是否触发 git：`否`

### 第3次改动
- 时间：`2026-04-28`
- 内容：
  - 将结构目录中的层级缩进从整体 padding 改成真实前导空位
  - 让 `H2 / H3 / H4` 在目录前方保留明确的空位层级
  - 目录视觉上更接近标准文档目录，而不是单列列表
- 影响文件：
  - `webui/config/app-notes.js`
  - `webui/config/styles.css`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes.js`
  - `rg -n "outline-indent|depth-1|depth-2|depth-3|depth-4|depth-5" webui/config/app-notes.js webui/config/styles.css`
  - `scripts/restart_main_ahk.ps1`
  - 重启后确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`
- 是否触发 git：`是，已达到 3/3 checkpoint 阈值`
