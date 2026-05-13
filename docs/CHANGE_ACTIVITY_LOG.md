# 变更流水文档

最近同步：`2026-05-13`
状态：`active`

## 1. 文档定位

这份文档只记录当前这一轮、连续 `1-3` 次改动的内容。满 `3` 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-05-13-latency-stability-suite`
- 当前连续改动次数：`2`
- 本轮目标：
  - 聚焦 F3 的延迟与稳定性，补齐可重复执行的自动化测试脚本与回归口径
- 上一个 git 检查点：`checkpoint: stabilize F3 xunfei service restart flow`
- 最近一次推送：
  - 提交：`73e90ce`
  - 目标：`origin/main`
  - 结果：`push 成功`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 1-3 次改动窗口

上一轮 `3` 次改动已随提交 `73e90ce` 推送到 `origin/main`；下面保留上一轮摘要，同时开始记录本轮新的连续改动。

### 第 1 次改动（当前轮次）
- 时间：`2026-05-13`
- 内容：
  - 新增 `scripts/test_f3_latency_report.ps1`，把 F3 的自动化延迟回归拆成 `launch_ms / websocket_connected_ms / first_audio_sent_ms / finalize_ms` 等指标，并输出聚合统计
  - 新增 `scripts/test_f3_stability_suite.ps1`，把延迟回归、讯飞文本延迟基准、F3 中断重启稳定性回归收束成一份统一测试套件
  - 让本轮验收不再依赖单次体感，而是依赖脚本化结果：启动日志、会话汇总、首条文本基准、重启成功率
- 影响文件：
  - `scripts/test_f3_latency_report.ps1`
  - `scripts/test_f3_stability_suite.ps1`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
- 测试：
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_f3_latency_report.ps1 -RepoRoot . -OpenOverlayFirst -Iterations 3 -HoldMs 2200 -WaitAfterReleaseMs 4200`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_f3_stability_suite.ps1 -RepoRoot . -OpenOverlayFirst -LatencyIterations 3 -RestartIterations 2`
- 测试结果：`通过`

### 第 2 次改动（当前轮次）
- 时间：`2026-05-13`
- 内容：
  - 对“语音功能已基本完结”的现状做文档收口，统一模块主文档、模块修改过程文档、AI 交接文档、总文档变更记录中的最终口径
  - 修正 `docs/extension/global_preferences/00_通用偏好结论.md` 开头误入的脏文本，避免后续继续把异常内容带进文档体系
  - 将 E 模块语音现状统一收口为：`F3 = 讯飞 WebSocket 语音识别主链已完成`，并明确后续默认只做质量、体感与展示细节优化
- 影响文件：
  - `docs/extension/global_preferences/00_通用偏好结论.md`
  - `docs/modules/06_assistant_capture_qa.md`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
  - `docs/AI_HANDOFF.md`
  - `docs/DOC_CHANGELOG.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 文档口径交叉校对：`docs/modules/06_assistant_capture_qa.md`、`docs/modules/changelog/E_截图问答_修改过程.md`、`docs/AI_HANDOFF.md`
  - 依赖上一轮已通过的语音回归脚本结果作为当前功能收口依据
- 测试结果：`通过`

### 第 1 次改动
- 时间：`2026-05-13`
- 内容：
  - 按当前验收要求恢复 F3 的讯飞必选模式，不再临时回退到本地默认语音识别
  - 将 F3 缺配置时的提示改成直接报出缺失项，形如：`讯飞语音识别配置缺失：缺少 AppID / API Key / API Secret。请到 API 中心补齐。`
  - 当前实机配置核对结果：`xunfei_app_id / xunfei_api_key_protected / xunfei_api_secret_protected` 仍为空，因此 F3 现阶段不能正常启动讯飞识别
- 影响文件：
  - `config.ini`
  - `src/assistant_overlay.ahk`
  - `src/storage/assistant.ahk`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
- 测试：
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restart_main_ahk.ps1`
  - 配置核对：确认 `voice_model=xunfei_websocket_asr`、`voice_input_provider=xunfei_websocket_asr`
  - 文案检索：`rg -n "讯飞语音识别配置缺失|状态：讯飞配置缺失" src/assistant_overlay.ahk src/storage/assistant.ahk -S`
- 测试结果：`通过`

### 第 2 次改动
- 时间：`2026-05-13`
- 内容：
  - 已在本机补齐讯飞 WebSocket 所需配置，并保持 F3 继续走讯飞识别链路
  - 按现有受保护字段机制写入本地配置，不将明文密钥保存在普通配置字段，也不写入文档
  - 预热验证结果从 `credentials_missing` 收口为 `ready`，说明 service 已能正常读取讯飞配置
- 影响文件：
  - `config.ini`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
- 测试：
  - 配置读取校验：确认 `AppID / API Key / API Secret` 三项均可从本地配置正常解出
  - service 预热校验：`stage=ready`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restart_main_ahk.ps1`
- 测试结果：`通过`

### 第 3 次改动
- 时间：`2026-05-13`
- 内容：
  - 修复 F3 讯飞常驻 service 的残留命令文件问题：在 `EnsureAssistantVoiceService()` 启动新 service 前，主动清理旧的 `command / status / stop / pid / transcript / err` 运行时文件
  - 修复 service 退出后的尾部清理：`assistant_voice_input.ps1` 在 service `finally` 中补充删除旧 `command` 文件，避免新进程启动后误吃到上一轮遗留的 `exit|...`
  - 补充 AHK 侧 `ShutdownAssistantVoiceService()` 收尾清理，避免 F3 重启链路把旧退出指令残留到下一轮
  - 直接打通 F3 中断重启链路：第二次按下 F3 后，已能稳定打断上一轮并进入新一轮识别启动，不再卡在 `voice service did not become ready`
- 影响文件：
  - `src/storage/assistant.ahk`
  - `scripts/assistant_voice_input.ps1`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
- 测试：
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restart_main_ahk.ps1`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_f3_restart_flow.ps1 -RepoRoot . -OpenOverlayFirst`
  - 再次回归：`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_f3_restart_flow.ps1 -RepoRoot . -OpenOverlayFirst`
  - 讯飞延迟基准：`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_xunfei_voice_latency.ps1 -DataFile config.ini`
- 测试结果：`通过`

## 4. 是否触发 git

- 当前累计：`2 / 3`
- 本次是否触发 checkpoint：`否`
- 下一步要求：如再完成 `1` 次有效改动并测试通过，则执行 checkpoint commit + push
