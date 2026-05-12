# 模块修改过程记录：E 截图问答

最近同步：`2026-05-12`  
状态：`active`

## 1. 当前状态

- 核心范围：截图问答、语音输入、悬浮窗、模型配置
- 当前重点：F3 讯飞语音识别的低延迟、流式转写、状态可视化与常驻待命优化

## 2. 修改记录

### 2026-05-12 / F3 待命状态可视化与悬浮窗预热常驻收口
- 改动内容：
  - 将 F3 的讯飞 service 待命态正式收成“悬浮窗打开即预热”，不再等第一次按下 F3 才临时拉起
  - 为悬浮窗待命栏补上语音状态细分：`未开启 / 未预热 / 预热中 / 已就绪 / 启动失败`
  - 新增 idle watcher，在悬浮窗可见且 F3 空闲时持续观察语音 service 状态；若 service 掉线，会按冷却节奏自动补拉起
  - F3 按下前新增 `ready` 确认；如果 service 还没真正进入待命，会先等待 ready，再必要时重建一次 service，避免“按下 F3 但实际上还不能录音”
  - PowerShell service 在一次识别完成后不再长期停留在 `completed`，而是短暂保留完成态后自动回到 `ready`，让悬浮窗能稳定显示“已就绪”
  - 将 F3 的交互状态改为更贴近实际操作：`请开始说话 -> 正在听你说话 -> 已松开，正在整理识别结果 -> 你刚才说的是...`
  - 若上一轮 F3 在松开后的整理阶段尚未结束，用户再次按下 F3 会立即放弃上一轮结果，并自动切入新一轮语音输入
  - 将松开后的整理阶段再拆细为：`正在结束收音并上传尾段 -> 正在整理最终文本`
  - 修正讯飞 service 的阶段判定：`completed` 不再被当成新一轮 F3 的 `ready` 或有效启动成功，避免把上一轮空结果的完成态误判成“本轮已经准备好/已识别完成”，导致持续出现“未识别到语音内容”
  - 新增 F3 测试样本记录：每次语音识别结束后，都会把本轮的 `总耗时 / 按住时长 / 松开后整理时长 / 各段 metric / 识别文本 / 字符数 / 结果类型 / 错误信息` 汇总记录到结构化 `assistant_voice_sessions.jsonl`，并同步写一条 `assistant_voice_session_summary` 到 `action.log`
- 影响文件：
  - `src/assistant_overlay.ahk`
  - `scripts/assistant_voice_input.ps1`
  - `src/storage/assistant.ahk`
  - `src/helpers.ahk`
  - `src/app_state.ahk`
  - `docs/ACTION_LOG.md`
- 测试：
  - PowerShell Parser 校验：`[System.Management.Automation.Language.Parser]::ParseFile('scripts/assistant_voice_input.ps1',[ref]$null,[ref]$null)`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restart_main_ahk.ps1`
  - 进程校验：确认当前仅存在 1 个 `AutoHotkey64.exe` 主实例
- 测试结果：`通过`

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

### 2026-05-11 / F3 切换为纯语音识别回填并修复中文编码链路
- 改动内容：
  - 将 `F3` 从“识别后直接调用问答模型”切为“纯语音识别回填输入框”，便于先单独验证语音识别准确率
  - 修复讯飞识别结果在 Python -> PowerShell -> AHK 链路中的中文乱码问题，改为由 Python 先写入 UTF-8 文本文件，再由上层读取
  - transcript 初始化改为 `UTF-8 without BOM`，避免空文件被误识别为已有内容
  - 压短整段录音上传前的额外等待，先收掉明显的非必要延迟
- 测试：
  - `python scripts/xunfei_asr.py --audio <probe_pcm> --output <temp> --error-output <temp>`
  - transcript 空文件检查：确认长度为 `0`，无 BOM
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restart_main_ahk.ps1`
- 测试结果：`通过`

### 2026-05-11 / F3 接入 live 讯飞链路与流式 transcript
- 改动内容：
  - 将讯飞识别链路从“按住录音、松开后整段识别”推进到 `live` 模式，改为边采集、边上传、边实时写 transcript
  - 悬浮窗 transcript watcher 刷新间隔从 `180ms` 收紧到 `70ms`
  - 悬浮窗文案同步改为“实时转写”，明确当前看到的是流式中间结果
  - 当前阶段先保持“语音识别 -> 回填文本”的单目标闭环，不叠加问答模型调用
- 测试：
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/assistant_voice_input.ps1 -Mode listen -Provider xunfei_websocket_asr ...`
  - live transcript 文件持续写入观察
  - `python scripts/xunfei_asr.py --audio <probe_pcm>`
- 测试结果：`通过`

### 2026-05-11 / F3 增加语音状态显示、耗时埋点与 service 常驻待命尝试
- 改动内容：
  - 为 F3 增加状态显示：`语音启动中 / 已连接麦克风 / 已连接识别服务 / 正在监听输入 / 正在实时转写 / 正在整理识别结果 / 正在结束监听 / 语音识别完成`
  - 增加耗时埋点日志：`assistant_voice_input_start`、`assistant_voice_stage`、`assistant_voice_first_text`
  - 实测旧链路中 `F3 -> listening` 约 `641ms`，`F3 -> capturing` 约 `1344ms`，确认用户感知到的 1 秒级启动延迟是真实存在的
  - 新增“悬浮窗打开时预拉起语音底层”的 service / prewarm 尝试：悬浮窗打开即启动待命 service，按下 F3 时优先走 service start，超时则 fallback 到旧链路
  - 当前 service 已可稳定进入 `stage=ready`，也能拉起 Python 子进程，但 `start` 后尚未稳定推进到 `connected / capturing / streaming`，因此仍需继续修复
- 测试：
  - `action.log` 校验：确认出现 `assistant_voice_stage` 与 `assistant_voice_first_text` 埋点
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/assistant_voice_input.ps1 -Mode service ...`
  - service `start` / `stop` 冒烟：确认 service 可进入 `ready`，但 `start` 后状态仍停在 `ready`
- 测试结果：`部分通过：状态显示、日志埋点、ready 待命正常，service start 后的 live 采集链路仍需继续修复`

### 2026-05-11 / E 模块配置持久化与 DeepSeek 模型接入
- 改动内容：
  - 补齐问答模型与语音配置的真实持久化，避免前端切换后只停留在界面态
  - 新增 `DeepSeek V4 Pro` 问答模型，并接入独立 `deepseek_api_key_protected` 存储，避免覆盖豆包问答密钥
  - 新增讯飞 `xunfei_app_id / xunfei_api_key_protected / xunfei_api_secret_protected` 的读写链路，供 F3 语音识别真实复用
  - 让问答 endpoint 按当前模型自动解析，DeepSeek 走 `https://api.deepseek.com/chat/completions`，豆包继续走 Ark Responses endpoint
  - 去掉 F3 启动时对 service 的 900ms 阻塞等待，避免人为拉长按下后到监听开始的体感延迟
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-common.js`
  - PowerShell Parser 校验 `webui/config/server_state/assistant.ps1` 与 `webui/config/server_state/config.ps1`
  - `rg -n "deepseek-v4-pro|deepseek_api_key_protected|xunfei_api_secret_protected|Get-AssistantEndpointByModel|GetAssistantApiEndpointForModel" src webui/config -S`
- 测试结果：`通过`

### 2026-05-11 / F3 语音 service 启动参数修复
- 改动内容：
  - 修复 service 模式下 Python live worker 的启动参数拼接错误
  - 改正设备名、路径参数在后台启动时的拆分方式，避免空格设备名被拆坏，导致 Python 将整串参数识别成脚本路径或报 `unrecognized arguments`
  - 为 service worker 补上工作目录、stdout/stderr 重定向与退出后的错误透传
  - 修正 worker 退出码读取，避免正常 stop 后误写 `xunfei live worker failed with exit code`
- 测试：
  - service 冒烟：`assistant_voice_input.ps1 -Mode service -Provider xunfei_websocket_asr`
  - `start` 指令回归：确认状态可从 `starting` 推进到 `capturing`
  - `stop` 指令回归：确认最终回到 `ready`，错误文件为空
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restart_main_ahk.ps1`
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

### 2026-05-11 / F3 语音链路竞态收口
- 改动内容：
  - 为 F3 语音输入新增 `gAssistantVoiceInputStarting / gAssistantVoiceStopPending` 防重入状态，避免长按期间重复触发 `start`
  - 调整热键启动尚未完成时的 `Up` 处理，避免过早进入 `voice session missing`
  - 调整讯飞 service 结束态保留逻辑，让单次识别结束后先保留 `completed / failed`，不再立刻覆盖回 `ready`
  - 调整 AHK 停止轮询逻辑，service 停止时优先等待 `completed / failed`，降低把识别中途误判成空结果的概率
- 测试：
  - PowerShell 语法校验：`[System.Management.Automation.Language.Parser]::ParseFile('scripts/assistant_voice_input.ps1',[ref]$null,[ref]$null)`
  - service 独立冒烟：确认状态可从 `starting` 进入 `capturing`
  - service 停止回归：发送 `stop` 后最终状态稳定停在 `stage=completed | detail=completed_empty`
- 测试结果：`通过`
- 补充：live 采集现已优先改为 `sounddevice`，仅在不可用时回退到 `ffmpeg dshow`。这一步属于参考开源实时语音项目的常见优化方向，目标是压缩录音链路的外部进程冷启动成本。
### 2026-05-11 / F3 当前“未识别到语音内容”问题加固
- 改动内容：
  - 在 `src/assistant_overlay.ahk` 新增 service 存活校验，启动 F3 前先确认缓存中的讯飞 service 进程确实还活着，避免复用已失活的旧对象
  - 新增会话启动确认逻辑，在发出 `start` 命令后，等待状态文件真正进入本次识别会话；如果命令发出了但 service 没有真正起会话，不再直接当作成功
  - 若首次 `start` 未能把会话推进到有效阶段，则自动销毁旧 service、重建后再重试一次，降低空会话与假启动概率
  - F3 停止时若最终 transcript 为空，则优先回退使用实时转写过程中已经显示到悬浮窗上的文本，避免“中途识别到了，但最后仍被判空”
- 测试：
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restart_main_ahk.ps1`
  - service 状态观察：临时拉起 `assistant_voice_input.ps1 -Mode service -Provider xunfei_websocket_asr` 后，状态文件已可推进到 `stage=streaming`
  - transcript 运行态观察：当前 transcript 文件可实时写入内容，不再只停留在空结果路径
- 测试结果：`通过`

### 2026-05-11 / F3 语音链路分段时长埋点
- 改动内容：
  - 为 F3 语音链路补齐可分段测试的时长埋点，不再只看“总感觉慢”
  - 在 `scripts/xunfei_asr.py` 新增状态报告器，持续写出 `metric_*` 指标，覆盖：Python worker 启动、WebSocket 开始连接、WebSocket 已连接、音频流 ready、首帧采集、首包发送、首个服务响应、首个非空文字结果、停止请求、最终结果返回、整次完成
  - 在 `scripts/assistant_voice_input.ps1` 中补上 service 收到命令后到 Python 拉起的时长，并作为 bootstrap 指标传入 Python worker
  - 在 `src/assistant_overlay.ahk` 中解析状态文件里的 `detail` 与 `metric_*`，把每段时长转存进 `action.log`
  - 当前这套设计的目标，是后续可以直接从日志判断主要延迟究竟卡在：service 启动、识别服务连接、音频采集、首包发送，还是首条结果返回
- 测试：
  - `py_compile.compile('scripts/xunfei_asr.py', doraise=True)`
  - PowerShell Parser 校验：`[System.Management.Automation.Language.Parser]::ParseFile('scripts/assistant_voice_input.ps1',[ref]$null,[ref]$null)`
  - service 冒烟观察：状态文件已成功写出分段指标
  - 当前实测样本：`websocket_connected_ms=269`、`audio_stream_ready_ms=308`、`first_audio_captured_ms=351`、`first_audio_sent_ms=352`
  - 我自行追加了 3 轮 live service 测试；有效样本显示：`websocket_connected_ms=225-257`、`first_audio_sent_ms=302-336`、`first_result_received_ms=1108-1127`、`completed_ms=2187-2191`
  - 由此确认：当前主要延迟不在本地麦克风首帧，而更集中在“首包发出后到识别服务返回第一条有效响应”这段
- 测试结果：`通过`
