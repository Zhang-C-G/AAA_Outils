# 模块 04：B 笔记

## 模块目标

- 管理多条笔记（新建、编辑、保存、删除）。
- 模式切换或关闭时自动保存当前编辑内容。
- 支持 Markdown 内容写入，并稳定落盘到本地笔记文件。

## 核心主功能

- 核心是笔记内容可编辑、可保存、可自动保存，且刷新后不丢。
- 任何界面调整或次级交互问题，都不能以牺牲保存链路为代价。
- “笔记显示”是独立模块，不属于本模块；两者现在也不共享同一套笔记文件。

## 当前状态

- 当前状态：`未开发完全`
- 目前已经完成的是基础的笔记新建、编辑、保存、删除、自动保存。
- 仍不能把本模块视为最终完成版；后续若继续扩展，必须在不破坏现有保存链路的前提下推进。

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
4. Markdown 内容可正常保存到 `notes/*.md`。
5. 刷新页面或重启后，笔记编辑内容不丢失。
