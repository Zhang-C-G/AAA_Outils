# 改动流水文档

最近同步：`2026-04-26`  
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。  
满 3 次并完成 git checkpoint + push 后，历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-04-26-after-checkpoint-fix-a-module-add-tab-save-validation`
- 当前连续改动次数：`3`
- 本轮目标：`收紧 A 模块悬浮窗逻辑，补齐拖拽排序个性化能力，并消除唤出时闪动`
- 上一个 git 检查点：`checkpoint: incident docs and shortcuts category persistence`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 3 次改动窗口

### 第 1 次改动
- 时间：`2026-04-26`
- 内容：调整 A 模块悬浮窗逻辑；把它收敛为普通悬浮窗行为，增加失焦自动隐藏；空搜索默认展示 `fields` 中按使用频率排序的 Top 10；悬浮窗列表只显示触发词与热度，不再罗列内容列
- 影响文件：
  - `src/panel_ui.ahk`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 代码校验：确认悬浮窗列表列定义已改为 `键 / 热度`
  - 逻辑校验：确认空搜索默认候选来源已从 `prompts` 切到 `fields`
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例成功
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 2 次改动
- 时间：`2026-04-26`
- 内容：为笔记模块左侧罗列框增加拖拽排序，并把顺序持久化到笔记目录顺序文件；同时为 A 模块 `quick_fields` 条目增加拖拽改顺序能力。该排序能力归类为个人偏好
- 影响文件：
  - `webui/config/app-notes.js`
  - `webui/config/server-notes.ps1`
  - `webui/config/server.ps1`
  - `webui/config/app-shortcuts.js`
  - `webui/config/styles.css`
  - `docs/extension/global_preferences/components/13_列表排序偏好.md`
  - `docs/extension/global_preferences/00_通用偏好结论.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 代码校验：确认笔记列表已接入 `dragstart / drop` 和 `/api/notes/reorder`
  - 代码校验：确认 `quick_fields` 条目已接入拖拽重排并走自动保存
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例成功
  - 接口校验：新增 `/api/notes/reorder` 路由已挂载
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 3 次改动
- 时间：`2026-04-26`
- 内容：修正 A 模块悬浮窗唤出时闪动；去掉该悬浮窗显示/隐藏时的透明度淡入淡出，改成普通悬浮窗的直接弹出与直接隐藏，避免在唤出瞬间出现可见闪动
- 影响文件：
  - `src/panel_ui.ahk`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 代码校验：确认 `ShowPanel()` / `HidePanel()` 已不再调用 `PanelFadeIn()` / `PanelFadeOut()`
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例成功
  - 行为校验：A 模块悬浮窗现按普通悬浮窗直接显示/隐藏
- 测试结果：`通过`
- 是否触发 git：`是，本次完成后执行 checkpoint`
