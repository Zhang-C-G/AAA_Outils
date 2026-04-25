# 模块 01：全局悬浮面板（Hotkey Panel）

## 模块目标

- 通过全局热键呼出小悬浮面板。
- 根据关键词匹配候选并回填到当前输入位置。
- 支持键盘选择与回车确认插入。

## 核心主功能

- 核心是“呼出面板 -> 选中候选 -> 插入到目标输入位置”这条链路稳定可用。
- 任何动画、样式、非核心交互问题，都不能以牺牲这条主链路为代价。

## 主要文件

- `src/panel_ui.ahk`
- `src/hotkeys.ahk`
- `src/effects.ahk`
- `src/helpers.ahk`

## 关键动作日志

- `panel_open` / `panel_close`
- `selection_confirm`
- `insert_success` / `insert_failed`

## 改动后必查

1. 面板热键可稳定打开/关闭。
2. `Enter` 可插入当前选中项。
3. `↑/↓` 可切换候选，`Enter` 可插入当前项。
4. `Esc` 可关闭面板且不残留状态。
