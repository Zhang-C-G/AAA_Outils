# 模块 04：笔记

## 模块目标

- 管理多条笔记（新建、编辑、保存、删除）。
- 模式切换或关闭时自动保存当前编辑内容。

## 主要文件

- `src/config_modes/notes_mode_ui.ahk`
- `src/config_modes/notes_mode_actions.ahk`
- `src/storage/notes.ahk`
- `webui/config/app-notes.js`
- `webui/config/server-notes.ps1`

## 存储位置

- `notes/*.md`

## 关键动作日志

- `notes_new`
- `notes_select`
- `notes_save`
- `notes_autosave`
- `notes_delete`

## 改动后必查

1. 新建笔记后可保存并刷新可见。
2. 切换模式触发自动保存。
3. 删除确认流程正常且落盘生效。
