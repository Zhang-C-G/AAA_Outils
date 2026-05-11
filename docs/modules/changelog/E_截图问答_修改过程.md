# 模块修改过程记录：E 截图问答

最近同步：`2026-04-27`  
状态：`active`

## 1. 当前状态

- 核心范围：截图问答、语音输入、悬浮窗、模型配置
- 当前重点：保留有效配置项，收掉无用前端入口

## 2. 修改记录

### 2026-04-26 / 麦克风与语音链路阶段
- 改动内容：
  - 已围绕麦克风链路、语音输入开关、模型 UI 做过接入与文档归档
- 测试：
  - 链路测试完成后已纳入 incident / handoff 体系
- 测试结果：`通过`

### 2026-05-11 / 语音模型真实接入到自动保存与待命展示
- 改动内容：
  - 修复 E 模块中 `语音模型激活` 仅停留在前端界面、未真实写入后端配置与 AHK 运行态的问题
  - 语音模型选择新增 `本地默认语音识别`，并作为默认候选接入完整保存链路
  - 前端、PowerShell 配置服务、AHK 本地配置读取与写回统一新增 `voice_model`、`voice_model_enabled`
  - F2 截图问答悬浮窗在待命状态下新增语音模型展示，格式改为 `状态：待命：问答=... | 语音=...`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-assistant.js`
  - `node --experimental-default-type=module --check webui/config/app-common.js`
  - PowerShell Parser 校验 `webui/config/server_state/assistant.ps1`
  - `rg -n "voice_model|voice_model_enabled|local_windows_default|BuildAssistantOverlayIdleStatus|GetAssistantCurrentVoiceModelLabel" webui/config/app-assistant.js webui/config/server_state/assistant.ps1 src/storage/assistant.ahk src/storage/data_save.ahk src/storage/data_load.ahk src/assistant_overlay.ahk -S`
- 测试结果：`通过`

### 2026-04-26 / 语音模型收敛为讯飞
- 改动内容：
  - E 模块中的“语音模型选择”不再把豆包模型当作语音模型候选
  - 当前语音模型候选只保留 `讯飞 WebSocket 语音识别`
  - 默认语音模型改为 `xunfei_websocket_asr`
- 测试：
  - 代码校验：确认前端默认值、候选列表、回填默认值均已切到讯飞
- 测试结果：`通过`

### 2026-04-26 / 模板删除确认改为自定义弹窗
- 改动内容：
  - E 模块模板删除不再使用浏览器默认 `confirm()`
  - 删除确认改为应用内自定义弹窗
  - 删除操作只保留一次确认
- 测试：
  - 代码校验：确认 `assistantDeleteTplBtn` 删除链路已改为 `confirmDialog`
  - 全局搜索：确认模板删除链路不再使用默认 `confirm()`
- 测试结果：`通过`

### 2026-04-26 / 语音模型 API 回填改为星号保护
- 改动内容：
  - E 模块“语音模型 API”补齐与“问答模型 API”一致的受保护存储链路
  - 前端回填时继续使用星号遮罩，不回显明文
  - 公开状态新增 `has_voice_model_api_key`，使前端可稳定按“已保存密钥”样式显示
- 测试：
  - 代码校验：确认 `server_state/assistant.ps1` 已新增 `voice_model_api_key_protected`
  - 代码校验：确认公开状态已返回 `has_voice_model_api_key`
  - 语法校验：PowerShell Parser 成功解析 `webui/config/server_state/assistant.ps1`
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk`
- 测试结果：`通过`

### 2026-04-26 / 悬浮窗再次点击可关闭
- 改动内容：
  - E 模块悬浮窗新增 `ToggleAssistantOverlay()` 入口
  - 用户再次点击同一唤起入口时，若悬浮窗已显示，则直接关闭
  - 热键入口与 Web 操作入口统一改为 toggle；内部截图、语音、恢复显示等强制展示链路保持原逻辑
- 测试：
  - 代码校验：确认 `HotkeyAssistantCapture()` 已改为调用 `ToggleAssistantOverlay()`
  - 代码校验：确认 `src/web_config.ahk` 中 `assistant_overlay_open` 已改为调用 `ToggleAssistantOverlay(false, "web_action")`
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk`
  - 进程校验：确认当前仅存在 1 个绑定 `main.ahk` 的 AutoHotkey 进程
- 测试结果：`通过`

### 2026-04-27 / 移除高级设置中的 API 输入框
- 改动内容：
  - 删除 E 模块高级设置中的 `问答模型 API` 与 `语音模型 API` 前端文案和输入框
  - 删除前端对应的回填逻辑与输入监听
  - 保留保存时沿用后端已有 key 的行为，避免因为 UI 删除而误清空已有配置
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-assistant.js`
  - `rg` 确认前端文件中已不再存在 `assistantApiKey`、`assistantVoiceApiKey`、`问答模型 API`、`语音模型 API`
  - 通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk`
  - 延迟复查后确认当前仅存在 1 个 `AutoHotkey64.exe` 实例
  - `GET http://127.0.0.1:8798/` 返回 HTML，确认页面中已不再包含这两组 API 字段
- 测试结果：`通过`
### 2026-04-27 / 悬浮球主色色轮
- 改动内容：
  - E 模块高级设置新增 `悬浮球主色`
  - 使用原生色轮选择颜色，并显示当前十六进制颜色值
  - 保存后端新增 `overlay_ball_color`，AHK 默认配置与加载链路同步接入
  - 运行中的截图问答悬浮窗开始按该颜色刷新背景、按钮和文本对比色
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-assistant.js`
  - PowerShell Parser 校验 `webui/config/server_state/assistant.ps1` 与 `webui/config/server_state/config.ps1`
  - `scripts/restart_main_ahk.ps1`
  - 确认仅存在 `1` 个 `AutoHotkey64.exe`
  - `GET /api/assistant/state` 与 `POST /api/assistant/save-settings` 均正确返回 `overlay_ball_color`
- 测试结果：`通过`
