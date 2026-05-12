# 变更流水文档

最近同步：`2026-05-12`
状态：`active`

## 1. 文档定位

这份文档只记录当前这一轮、连续 `1-3` 次改动的内容。满 `3` 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-05-12-f3-overlay-ready-state`
- 当前连续改动次数：`3`
- 本轮目标：
  - 收口 E 模块 F3 的待命状态显示
  - 让悬浮窗打开后即自动预热语音 service，并把 ready 态稳定显出来
- 上一个 git 检查点：`checkpoint: stabilize F3 voice input service path`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 1-3 次改动窗口

### 第 1 次改动
- 时间：`2026-05-12`
- 内容：
  - 收口 E 模块 F3 的待命态与常驻预热表达
  - 悬浮窗打开后即自动预热讯飞语音 service，不再等第一次按下 F3 才临时加载
  - 待命栏补上 `未预热 / 预热中 / 已就绪 / 启动失败` 状态
  - F3 开始录音前先确认 service 已进入 `ready`；若未就绪则先等待，必要时自动重建一次
  - `assistant_voice_input.ps1` 在单次识别完成后会从 `completed` 自动回落到 `ready`
  - F3 录音过程的界面提示改为 `请开始说话 / 正在听你说话 / 已松开，正在整理识别结果`
  - 如果上一轮 F3 在整理结果时用户又再次按下 F3，会直接放弃上一轮并切到新一轮
  - 松开后的整理阶段再拆为 `正在结束收音并上传尾段 / 正在整理最终文本`
  - 修正 `completed` 阶段误判：不再把上一轮空结果的完成态当成新一轮 F3 的 `ready/启动成功`
  - 新增每轮 F3 识别测试样本记录：输出结构化 `assistant_voice_sessions.jsonl`，汇总文本、字符数、总耗时、按住时长、整理时长与各段 metric
- 影响文件：
  - `src/assistant_overlay.ahk`
  - `scripts/assistant_voice_input.ps1`
  - `src/storage/assistant.ahk`
  - `src/helpers.ahk`
  - `src/app_state.ahk`
  - `docs/ACTION_LOG.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
- 测试：
  - PowerShell Parser 校验 `scripts/assistant_voice_input.ps1`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restart_main_ahk.ps1`
  - 进程校验：确认仅保留 1 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 第 2 次改动
- 时间：`2026-05-12`
- 内容：
  - 将 F3 的交互状态改为更贴近实际操作：`请开始说话 -> 正在听你说话 -> 已松开，正在整理识别结果 -> 你刚才说的是...`
  - 若上一轮 F3 在松开后的整理阶段尚未结束，用户再次按下 F3 会立即放弃上一轮结果，并自动切入新一轮语音输入
  - 将松开后的整理阶段再拆细为：`正在结束收音并上传尾段 -> 正在整理最终文本`
- 影响文件：
  - `src/assistant_overlay.ahk`
  - `scripts/assistant_voice_input.ps1`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
- 测试：
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restart_main_ahk.ps1`
  - 进程校验：确认仅保留 1 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 第 3 次改动
- 时间：`2026-05-12`
- 内容：
  - 修正 `completed` 阶段误判：不再把上一轮空结果的完成态当成新一轮 F3 的 `ready/启动成功`
  - 新增每轮 F3 识别测试样本记录：输出结构化 `assistant_voice_sessions.jsonl`，汇总文本、字符数、总耗时、按住时长、整理时长与各段 metric
  - `action.log` 新增 `assistant_voice_session_summary`，便于直接追踪每轮测试结果
- 影响文件：
  - `src/assistant_overlay.ahk`
  - `src/storage/assistant.ahk`
  - `src/helpers.ahk`
  - `src/app_state.ahk`
  - `docs/ACTION_LOG.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
- 测试：
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restart_main_ahk.ps1`
  - 进程校验：确认仅保留 1 个 `AutoHotkey64.exe`
  - `rg -n "assistant_voice_session_summary|assistant_voice_sessions.jsonl|RecordAssistantVoiceSessionSample" src docs -S`
- 测试结果：`通过`

## 4. 是否触发 git

- 当前累计：`3 / 3`
- 本次是否触发 checkpoint：`是，已达到文档规则中的 checkpoint 阈值`
- 下一步要求：执行 `checkpoint commit + push`
