# 模块 05：截图发手机

## 模块目标

- 本地全屏截图后上传，并给出手机可访问链接。
- 显示桥接状态（PC/Phone），便于判断连接是否可用。

## 核心主功能

- 核心是“截图 -> 上传 -> 手机可访问”这条链路真实可用。
- 任何附加展示、状态文案或次要 UI 问题，都不能以牺牲这条主链路为代价。

## 主要文件

- `src/config_modes/capture_mode_ui.ahk`
- `src/config_modes/capture_mode_actions.ahk`
- `src/storage/capture_file_ops.ahk`
- `src/storage/capture_bridge.ahk`
- `webui/config/app-capture.js`
- `webui/config/server-capture.ps1`
- `webui/config/server_state/capture.ps1`

## 存储位置

- `captures/*.png`
- `config.ini` 的 `[Capture]`

## 关键动作日志

- `capture_settings_save`
- `capture_bridge_start` / `capture_bridge_stop`
- `capture_create` / `capture_create_failed`
- `capture_upload_success` / `capture_upload_failed`

## 改动后必查

1. Link 启停状态与界面一致。
2. 截图后 `latest` 文件可读取。
3. 上传失败时错误提示可见且不中断主流程。
