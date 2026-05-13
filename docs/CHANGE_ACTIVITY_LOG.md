# 变更流水文档

最近同步：`2026-05-12`
状态：`active`

## 1. 文档定位

这份文档只记录当前这一轮、连续 `1-3` 次改动的内容。满 `3` 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-05-12-f3-credential-preflight`
- 当前连续改动次数：`3`
- 本轮目标：
  - 收口 F3 在讯飞凭据缺失场景下的失败提示与 service 状态表达
- 上一个 git 检查点：`archive: sync checkpoint docs after main push`
- 最近一次推送：
  - 提交：`4053230`
  - 目标：`origin/main`
  - 结果：`push 成功`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 1-3 次改动窗口

### 第 1 次改动
- 时间：`2026-05-12`
- 内容：
  - 为 F3 新增讯飞凭据前置校验：缺少 `AppID / API Key / API Secret` 时，不再继续走“预热成功/开始录音”假路径
  - 悬浮窗待命状态新增 `未配置凭据` 表达；按下 F3 时直接明确提示“讯飞语音识别凭据未配置完整”
  - `assistant_voice_input.ps1` 的 service 模式在启动和每次 `start` 时都重新校验讯飞配置；缺失时写出 `stage=failed` 与 `detail=credentials_missing`
  - 修正 service 在 worker 已退出时仍被 `stop` 命令打到 `finalizing` 的状态错误，避免卡住误导排障
- 影响文件：
  - `src/assistant_overlay.ahk`
  - `scripts/assistant_voice_input.ps1`
  - `src/storage/assistant.ahk`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
- 测试：
  - PowerShell Parser 校验 `scripts/assistant_voice_input.ps1`
  - `node --experimental-default-type=module --check webui/config/app-assistant.js`
  - service 缺凭据自测：确认 `PREWARM / START / STOP` 都稳定返回 `stage=failed` 与 `detail=credentials_missing`
  - AHK 进程校验：清理到仅保留 1 个 `main.ahk` 主实例
- 测试结果：`通过`

### 第 2 次改动
- 时间：`2026-05-13`
- 内容：
  - 收口 F3 缺凭据时的用户可见文案，将悬浮窗正文、状态栏与返回错误统一改成更直接的提示：`目前讯飞语音识别配置不完整`
  - 保留底层 `credentials_missing` 判定，不改 service 失败语义，只调整用户面对的提示语句
- 影响文件：
  - `src/assistant_overlay.ahk`
  - `src/storage/assistant.ahk`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
- 测试：
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restart_main_ahk.ps1`
  - 文案检索：`rg -n "目前讯飞语音识别配置不完整|请先在 API 中心补齐讯飞配置" src/assistant_overlay.ahk src/storage/assistant.ahk -S`
- 测试结果：`通过`

### 第 3 次改动
- 时间：`2026-05-13`
- 内容：
  - 按交互要求继续收口 F3 缺凭据时的文案，将用户可见提示进一步统一为：`需要到API中心补齐讯飞配置`
  - 悬浮窗正文、状态栏与前置校验返回值同步改成同一句式，去掉上一版“目前讯飞语音识别配置不完整”的中间表述
- 影响文件：
  - `src/assistant_overlay.ahk`
  - `src/storage/assistant.ahk`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
- 测试：
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restart_main_ahk.ps1`
  - 文案检索：`rg -n "需要到API中心补齐讯飞配置|目前讯飞语音识别配置不完整" src/assistant_overlay.ahk src/storage/assistant.ahk -S`
- 测试结果：`通过`

## 4. 是否触发 git

- 当前累计：`3 / 3`
- 本次是否触发 checkpoint：`是`
- 下一步要求：本次完成 checkpoint commit + push 后，下一轮重新从 `0 / 3` 开始累计
