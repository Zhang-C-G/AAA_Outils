# 改动流水记录

最近同步：`2026-04-26`

## 记录规则

- 每完成 1 次明确改动，就追加 1 条记录
- 每满 3 次改动，必须立刻 git
- git 后在记录中写明提交 hash，并将计数重新开始

---

## 2026-04-26

### 轮次：E 模块语音模型 UI / 启动修复

#### 第 1 次改动

- 时间：`2026-04-26`
- 内容：E 模块第一阶段 UI 拆分，新增“问答模型选择 / 语音模型选择 / 语音模型激活 / 语音模型 API”等前端字段
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/app-assistant.js`
- 是否触发 git：`否`
- 备注：第一阶段只做 UI 壳层与前端状态占位，不接后端链路

#### 第 2 次改动

- 时间：`2026-04-26`
- 内容：新增 E 模块第一阶段文档，明确本阶段范围、页面结构与第二阶段待补项
- 影响文件：
  - `docs/modules/06E_stage1_voice_model_ui.md`
- 是否触发 git：`否`
- 备注：用于固定“先做 UI、后接真实链路”的边界

#### 第 3 次改动

- 时间：`2026-04-26`
- 内容：修复助手语音输入启动时的 AHK `#Warn` 作用域问题，避免 `gAssistantVoiceTranscriptLastText` 被误判为局部变量
- 影响文件：
  - `src/assistant_overlay.ahk`
- 是否触发 git：`是`
- git 检查点：`d999c5c`
- 备注：按当前规则，这 3 次改动已构成一轮检查点锚点

#### 第 4 次改动

- 时间：`2026-04-26`
- 内容：建立“每 3 次改动强制 git”的文档机制，并补写规则文档、流水文档、AI 交接总文档
- 影响文件：
  - `docs/CHANGE_CHECKPOINT_RULE.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/AI_HANDOFF.md`
- 是否触发 git：`否`
- 备注：当前连续计数从本次开始重新累计为 `1`

#### 第 5 次改动

- 时间：`2026-04-26`
- 内容：A 模块 Web UI 标签栏隐藏 `提示词`、`快捷字段`，仅保留 `字段` 与用户自建栏目；同步更新模块文档与前端文档口径
- 影响文件：
  - `webui/config/app-shortcuts.js`
  - `docs/modules/02_field_prompt_quickfield.md`
  - `docs/modules/07_web_config_frontend.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 是否触发 git：`否`
- 备注：当前连续计数更新为 `2`，下一次改动后必须 git

#### 第 6 次改动

- 时间：`2026-04-26`
- 内容：重构全局私人偏好文档结构，新增“通用偏好结论层”和“控件专项层”，并补齐栏目框、按钮、标签页三份控件偏好文档
- 影响文件：
  - `docs/extension/全局私人偏好文档.md`
  - `docs/extension/global_preferences/00_通用偏好结论.md`
  - `docs/extension/global_preferences/components/10_栏目框偏好.md`
  - `docs/extension/global_preferences/components/11_按钮偏好.md`
  - `docs/extension/global_preferences/components/12_标签页偏好.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
- 是否触发 git：`是`
- git 检查点：`checkpoint: restructure global preference docs`
- 备注：这是当前连续第 3 次改动，按规则本次改动完成后立即 git，后续计数从 `0` 重新开始

#### 第 7 次改动

- 时间：`2026-04-26`
- 内容：修正规则文档中对 `git` 的定义，明确本项目语境里的 git 默认指“本地 commit + push 到远端分支”，并补充远端结果说明要求
- 影响文件：
  - `docs/CHANGE_CHECKPOINT_RULE.md`
  - `docs/AI_HANDOFF.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
- 是否触发 git：`否`
- 备注：当前连续计数更新为 `1`
