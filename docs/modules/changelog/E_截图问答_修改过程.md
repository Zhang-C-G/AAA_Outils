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

### 2026-05-11 / 讯飞 WebSocket 语音识别真实接入 F3
- 改动内容：
  - 将 `F3` 语音输入从“仅本地 Windows 识别可用”扩展为支持 `讯飞 WebSocket 语音识别`
  - 保留原有本地识别链路，同时新增讯飞链路：按住期间本地录音，松开后将 PCM 音频发送到讯飞 WebSocket ASR，识别结果再回写到问答输入链路
  - AHK 启动语音脚本时新增 `Provider` 与 `DataFile` 传递，让脚本按当前语音模型切换到本地识别或讯飞识别
  - 本机 `config.ini` 的 `Assistant` 段新增隐藏持久化字段：`xunfei_app_id`、`xunfei_api_key_protected`、`xunfei_api_secret_protected`
  - 为讯飞识别补充更长的停止等待时间，避免松开 F3 后脚本还未完成上传与识别就被 AHK 提前截断
- 测试：
  - PowerShell Parser 校验 `scripts/assistant_voice_input.ps1`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/assistant_voice_input.ps1 -Mode list -DevicesJsonPath <temp>`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restart_main_ahk.ps1`
  - 进程校验：确认仅存在 1 个 `AutoHotkey64.exe` 主实例
- 测试结果：`通过`

### 2026-05-11 / 新增 DeepSeek 问答模型
- 改动内容：
  - E 模块问答模型新增 `DeepSeek V4 Pro`
  - 为 DeepSeek 模型新增独立密钥持久化字段，避免覆盖原有豆包问答密钥
  - 选中 DeepSeek 时，问答 endpoint 自动切换为 `https://api.deepseek.com/chat/completions`
  - 文本问答链路按 DeepSeek 官方示例补充 `thinking={ type: enabled }` 与 `reasoning_effort=high`
  - 本地 AHK 运行态与 Web 配置态统一支持按模型自动选择对应问答密钥
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-common.js`
  - PowerShell Parser 校验 `webui/config/server_state/assistant.ps1`
  - 代码检索：`rg -n "deepseek-v4-pro|api.deepseek.com/chat/completions|deepseek_api_key_protected|GetAssistantRequestApiKey|Get-AssistantEndpointByModel|Get-AssistantModelProvider" webui/config src config.ini -S`
  - 真实 API 冒烟测试：向 `https://api.deepseek.com/chat/completions` 发起最小文本请求，确认正常返回回答与 `reasoning_content`
- 测试结果：`通过`

### 2026-05-11 / F3 讯飞语音识别排障推进到鉴权层
- 改动内容：
  - 修复 `assistant_voice_input.ps1` 中讯飞签名链路的 PowerShell 兼容问题，包括 `HMACSHA256` 构造与鉴权 URL 拼接
  - 由于当前机器上的 .NET `ClientWebSocket` 对讯飞握手不稳定，新增 `scripts/xunfei_asr.py`，改为由 Python `websockets` 执行真实讯飞 WebSocket 上传
  - F3 语音识别错误现在会直接透传讯飞服务端响应，便于判断是本地问题还是凭据问题
  - 当前本机凭据已推进到真实鉴权阶段，服务端明确返回：`{"message":"HMAC signature does not match"}`
  - 同时兼容本机 `xunfei_api_secret` 可能存在的 base64 包裹形态，避免直接用包裹值签名
- 测试：
  - PowerShell 真机回归：`scripts/assistant_voice_input.ps1 -Mode listen -Provider xunfei_websocket_asr`
  - Python WebSocket 直连讯飞鉴权校验
  - 校验结果：本地录音与远端连接已通，当前剩余阻塞为讯飞 `API Key / API Secret` 签名不匹配
- 测试结果：`链路推进成功，但需修正讯飞凭据后才能完成最终识别`

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
