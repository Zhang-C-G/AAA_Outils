# 变更流水文档

最近同步：`2026-05-13`
状态：`active`

## 1. 文档定位

这份文档只记录当前这一轮、连续 `1-3` 次改动的内容。满 `3` 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-05-13-post-checkpoint`
- 当前连续改动次数：`0`
- 本轮目标：
  - 恢复 F3 的讯飞必选模式，并在缺配置时直接报出具体缺失项
- 上一个 git 检查点：`archive: sync checkpoint docs after F3 credential push`
- 最近一次推送：
  - 提交：`5ba45b8`
  - 目标：`origin/main`
  - 结果：`push 成功`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 1-3 次改动窗口

本轮 `3` 次改动已随提交 `5ba45b8` 推送到 `origin/main`，当前计数已清零；下面内容作为刚完成 checkpoint 的归档摘要保留，后续新的连续改动从 `0` 重新开始。

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

- 当前累计：`0 / 3`
- 本次是否触发 checkpoint：`已完成`
- 下一步要求：后续新的有效改动重新累计；满 `3` 次后再次执行 checkpoint commit + push
