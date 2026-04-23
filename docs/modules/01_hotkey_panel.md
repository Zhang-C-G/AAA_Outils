# 模块 01：全局悬浮面板（Hotkey Panel）

## 模块目标

- 通过全局热键呼出小悬浮面板。
- 根据关键词匹配候选并回填到当前输入位置。
- 支持键盘选择与 `1-9` 快速插入。

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
3. `1-9`（含小键盘）可直插对应候选。
4. `Esc` 可关闭面板且不残留状态。
