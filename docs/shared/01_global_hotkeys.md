# Shared 01：全局热键（Global Hotkeys）

## 定义

跨所有模块可见、可触发、可复用的热键能力。
该能力属于 Shared 公用块，不计入业务模块数量。

## 主要文件

- `src/hotkeys.ahk`
- `src/config_behavior_hotkeys.ahk`
- `webui/config/app-shortcuts.js`
- `webui/config/server_state/config.ps1`

## 约束

1. 热键定义唯一，避免冲突。
2. 保存后必须落盘到 `[Hotkeys]`。
3. 默认热键缺失时应自动回填。
4. 页面说明文案需跟随真实热键配置变化。
