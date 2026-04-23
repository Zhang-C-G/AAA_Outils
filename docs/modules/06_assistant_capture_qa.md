# 模块 06：截图问答助手

## 模块目标

- 通过快捷键触发截图并调用模型回答。
- 支持先启动悬浮窗，再按截图热键触发问答。
- 在助手悬浮窗展示结果，支持透明度与滚动。
- 悬浮窗内提供“截图问答”按钮，可直接点击触发截图问答链路（无需按快捷键）。
- 悬浮窗答案展示支持自动换行，并对代码块进行换行格式整理（避免“一行到底”）。
- 增加过程状态提示：正在截图、截图成功、正在思考（含已思考秒数）、回答完成/失败。
- 状态栏升级为链路态：准备截图（含模型）-> 正在截图 -> 截图完毕 -> 正在分析（含秒数）-> 回答完成/失败。
- Web 端仅做配置与触发，不在页面内显示回答文本。
- 支持提示词模板、多模板管理、限流、密钥保护。
- 悬浮窗透明度滑条已关闭悬浮数字气泡（鼠标悬浮/拖动不再弹数字提示）。
- Assistant Web 页关键项支持自动保存落盘（模板增删改、限流开关、每小时次数等）。
- Assistant 主界面模型输入改为“模型选择”下拉框，选项由后端返回的 `model_options` 驱动，确保与实际可用模型一致。
- Assistant 主界面支持“禁止复制悬浮窗答案”开关（默认开启）；开启后悬浮窗内文本不可复制。
- Assistant 页“快捷键说明（自动同步配置）”展示框采用统一斜线背景样式（低对比强调），用于弱提示但可快速识别。

## 主要文件

- `src/storage/assistant.ahk`
- `src/assistant_overlay.ahk`
- `src/config_modes/assistant_mode_ui.ahk`
- `src/config_modes/assistant_mode_actions.ahk`
- `webui/config/app-assistant.js`
- `webui/config/server-assistant.ps1`
- `webui/config/server_state/assistant.ps1`

## 存储位置

- `config.ini`：`[Assistant]`、`[AssistantTemplates]`
- `assistant_rate.ini`
- 默认限额：每小时 `100` 次截图问答（可在 Assistant 配置中调整）

## 默认提示词策略

- 读取或渲染到“全问号提示词”时自动回填默认提示词。
- 默认模板名统一为 `default_template`。
- 默认提示词：
  - 编程题：直接给编程完整答案，代码写在代码框中，并对核心部分做简短解释。
  - 选择题：先写15字以内题目总结，再直接给答案。

## 模型选择策略

- 默认模型：`doubao-seed-2-0-lite-260215`
- 已接入模型：`doubao-seed-2-0-lite-260215`、`doubao-seed-2-0-pro-260215`
- 前端使用后端下发的 `model_options` 渲染下拉，不允许自由文本乱填。
- 后端保存时会再次校验模型是否在白名单中，不合法值自动回退默认模型。

## 悬浮窗复制控制

- 配置项：`[Assistant] disable_copy`
- 默认值：`1`（禁止复制）
- 行为：
  - 无底部复制按钮；悬浮窗仅保留标题、状态与回答展示区
  - 拦截悬浮窗文本控件复制消息（防止快捷键/菜单复制）
  - 回答区鼠标不可选中文本，光标固定为箭头样式（不再切换为 I-beam）
  - 悬浮窗以 NoActivate 模式显示（点击不抢前台焦点，降低“切后台”判定风险）
  - 最终显示策略：优先 WDA；WDA 生效时录屏与 F1 分析阶段保持可见，WDA 失效时才回退到风险触发隐藏

## 关键动作日志

- `assistant_settings_save`
- `assistant_overlay_open` / `assistant_overlay_open_req`
- `assistant_capture_req` / `assistant_capture_triggered`
- `assistant_capture_btn_click`
- `assistant_capture` / `assistant_capture_failed`
- `assistant_answer_show` / `assistant_answer_failed`
- `assistant_rate_consume` / `assistant_rate_limited`
- `assistant_overlay_protect_enabled` / `assistant_overlay_protect_failed`
- `assistant_overlay_sensitive_hide` / `assistant_overlay_sensitive_restore`
- `assistant_overlay_risk_hide` / `assistant_overlay_risk_restore`
- `assistant_overlay_guard_forward` / `assistant_overlay_temp_hide` / `assistant_overlay_temp_restore`

## 快捷键（默认）

- `Alt+Shift+A`：启动问答悬浮窗
- `F1`：截图并问答
- 悬浮窗按钮：点击 `截图问答` 与 `F1` 使用同一安全链路
- `Alt+Up / Alt+Down`：悬浮窗答案滚动
- 外部截图保护：当悬浮窗可见时，`PrintScreen` / `Win+Shift+S` / `Ctrl+Alt+A` 会先临时隐藏悬浮窗再转发截图快捷键，降低“黑块被截入图片”的概率
- 录屏保护：检测到常见录屏进程/窗口（如 OBS、Bandicam、Game Bar 等）时，悬浮窗自动临时隐藏；风险解除后原位恢复。
- 传输阶段展示：截图完成后进入“思考/请求”阶段时，悬浮窗保持显示（状态与读秒持续可见），仅在真实截图风险触发时临时隐藏并自动恢复。
- 风险轮询保护：悬浮窗显示期间持续检测截图风险（按键态/截图进程），命中风险即隐藏，风险解除后恢复。
- 防黑块与可见性策略：默认开启 `WDA_EXCLUDEFROMCAPTURE`（优先“本地可见、录屏/截图不可见”）；若系统不支持则自动回退到“风险触发临时隐藏 + 原位恢复”。
- 防捕捉策略（最终口径）：`WDA_EXCLUDEFROMCAPTURE` 生效时，录屏与 F1 分析阶段悬浮窗保持可见；仅在 WDA 失效时回退到风险触发隐藏。
- `F1` 内部截图策略：仅在截图瞬间短隐藏并恢复同一窗口（原位置、原状态、原文本框），避免黑块同时保持界面稳定。
- 思考读秒策略：使用本地秒表定时器每秒更新“已思考 X 秒”，不依赖接口回调频率。
- WDA 持续重试：悬浮窗可见期间会定时重申 `SetWindowDisplayAffinity`，减少保护状态意外丢失。

## 改动后必查

1. Assistant 页面默认提示词不再出现问号。
2. Assistant Web 页面不再显示“本地模拟测试”按钮（仅保留真实触发入口）。
3. 真实接口调用至少可触发 `assistant_capture`，成功时出现 `assistant_answer_show`。
4. 模板保存后刷新不丢失，`active_template` 正确回显。
5. Web 页面“启动悬浮窗”按钮可触发本地悬浮窗；“截图并问答（F1）”可触发本地截图链路。
6. 悬浮窗长文本与代码段应自动换行，阅读不出现整行横向拉长。
7. 透明度滑杆为 100% 时窗口应完全不透明（不再若隐若现）。
8. 触发截图问答后，状态栏会展示“正在截图 -> 正在思考（X 秒）-> 回答完成”流程。
9. Assistant 页“快捷键说明”行必须只读，并随快捷键配置变化自动更新。
10. 模板新增/删除与每小时限流参数修改后，无需手点保存，刷新后仍保留并生效。
11. 悬浮窗可见时触发外部截图快捷键，不应在截图中留下问答悬浮窗黑块。
12. 按 `F1` 后悬浮窗应保持原位与同一实例更新；在 `WDA` 生效时允许全程可见，在 `WDA` 失效时允许“截图瞬间安全隐藏”，但不允许回答阶段闪烁重建或坐标跳回固定位置。
13. Assistant 页底部快捷键说明框应显示斜线背景，并实时同步热键值（`F2/F1/Alt+Up/Alt+Down` 或用户自定义值）。
