# 模块 06：截图问答助手

## 模块目标

- 通过快捷键或悬浮窗按钮触发截图并调用模型回答。
- 支持先启动悬浮窗，再按截图热键触发问答。
- 回答统一在本地悬浮窗展示，Web 端只负责配置与触发。
- 悬浮窗支持链路状态展示、长文本换行、代码段整理、滚动查看。
- 录屏期间悬浮窗对本地用户保持可见；截图时才允许短暂隐藏。
- 支持模板、多模板管理、模型下拉、限流、密钥保护与禁止复制。
- Assistant Web 页采用“基础设置 / 高级设置”分层，高级设置默认隐藏。

## 核心主功能

- 核心是：问答悬浮窗对本地用户可见；真实截图时可短暂隐藏；录屏/共享时必须做到“本地可见、录屏里不见”。
- 硬约束：悬浮窗一经调用，就必须立即处于不可被录屏/共享捕捉的保护态；不能先显示出来再补做保护。
- 硬约束：用户点击悬浮窗时，底层前台目标窗口不能失焦，不能触发目标应用自身的 `window.blur` / focus loss；悬浮窗交互必须尽量保持对目标窗口“不可检测”。
- 任何透明度、样式、布局、文案、按钮位置等次级问题，都不能以牺牲上述核心目标为代价。
- 录屏防捕捉必须采用通用方案，不能依赖对某个录屏软件、会议软件或共享工具做定向兼容。

## 主要文件

- `src/storage/assistant.ahk`
- `src/assistant_overlay.ahk`
- `src/config_modes/assistant_mode_ui.ahk`
- `src/config_modes/assistant_mode_actions.ahk`
- `webui/config/app-assistant.js`
- `webui/config/server-assistant.ps1`
- `webui/config/server_state/assistant.ps1`
- `webui/config/index.html`
- `webui/config/styles.css`

## 存储位置

- `config.ini`：`[Assistant]`、`[AssistantTemplates]`
- `assistant_rate.ini`
- `captures/*.png`
- 默认限额：每小时 `100` 次截图问答

## 默认提示词策略

- 读取或渲染到“全问号提示词”时自动回填默认提示词。
- 默认模板名统一为 `default_template`。
- 默认提示词：
  - 编程题：直接给编程完整答案，代码写在代码框中，并对核心部分做简短解释。
  - 选择题：先写 15 字以内题目总结，再直接给答案。

## 模型选择策略

- 默认模型：`doubao-seed-2-0-lite-260215`
- 已接入模型：`doubao-seed-2-0-lite-260215`、`doubao-seed-2-0-pro-260215`
- 前端模型输入改为后端驱动下拉框，选项来自 `model_options`
- 保存时后端会再次校验模型白名单，不合法值自动回退默认模型

## Web 页面结构

- 顶部先显示“快捷键说明（自动同步配置）”只读说明框。
- 基础设置只保留高频项：
  - 模型选择
  - 模板选择
  - 模板名称
  - Prompt
  - 新增模板 / 删除模板
- 高级设置默认隐藏，并通过开关式 UI 显示当前开关状态：
  - 关闭时，对应高级设置整块隐藏
  - 开启时，显示启用助手、透明度、API Key、禁止复制、限流等项
- `API Endpoint` 已从 Web 主界面移除，不再作为常规用户配置项暴露。
- 截图保存目录在页面中只读展示，并提供“修改目录”按钮切换保存位置。
- 页面提供“修改目录 / 打开目录”入口，直接调整或跳到当前截图目录。
- “最新截图文件”展示已从主界面移除。

## 透明度策略

- Web 端透明度改为 4 档点击切换：`20 / 50 / 75 / 100`
- 悬浮窗透明度只通过主界面修改，悬浮窗内不提供透明度切换入口
- 存储与运行时会将透明度收敛到这 4 个固定档位
- 防录屏开启时，若 WDA 需要本地不透明窗口，透明度展示仍保留当前档位文案

## 悬浮窗行为

- 悬浮窗仅保留标题、状态栏、`截图问答` 按钮与回答展示区。
- 悬浮窗不进入任务栏与常规 Alt-Tab 列表。
- 回答区禁止复制、禁止选中、鼠标光标固定为箭头。
- 悬浮窗以 NoActivate 模式显示，点击不抢焦点。
- 回答区不再显示“回答区”提示字样；仅在内容超长时显示当前行号范围。
- 回答文本从左上角起始渲染，不再垂直居中。
- 回答文本会做可读性整理：
  - 自动换行
  - 代码块 fence 整理
  - 多余空白压缩
  - 中文句读后的弱换行优化
- 展示实现已从 `Edit` 子控件收敛为轻量只读文本渲染，保留 `Alt+Up / Alt+Down` 滚动。
- 首次显示会先完成本地重绘，再延后挂接捕捉保护，降低按钮区域黑块与透明度切换闪烁。

## 录屏 / 截图安全策略

- 录屏 / 会议 / 共享期间：
  - 悬浮窗对本地用户必须持续可见
  - 悬浮窗一旦被调用，默认就要已经处于防捕捉状态，不能先暴露在录屏结果里再切到保护态
  - 用户点击悬浮窗时，不能让底层目标窗口触发 `window.blur`、失焦或焦点切换
  - 不能因为检测到录屏进程或窗口就自动隐藏
  - 目标是“本地能看见，录屏里看不见”
  - 防捕捉方案必须对随机录屏软件尽量成立，不能把实现建立在 OBS / Zoom / 腾讯会议 / Teams / 飞书 等某个软件的专用兼容逻辑上
- 截图期间：
  - `PrintScreen` / `Win+Shift+S` / `Ctrl+Alt+A` 命中时先临时隐藏悬浮窗，再转发截图动作
  - `F1` 内部截图仅在截图瞬间短隐藏并恢复原窗口
- 防捕捉基线：
  - 第一层：`WDA_EXCLUDEFROMCAPTURE`
  - 第二层：真实截图动作触发时临时隐藏 + 原位恢复
- 保护稳定性：
  - 先读 `GetWindowDisplayAffinity`
  - 仅在漂移或超时场景按需重建 affinity
  - 关键日志：`assistant_overlay_protect_rearm`、`affinity_drift_*`

## 关键动作日志

- `assistant_settings_save`
- `assistant_overlay_open` / `assistant_overlay_open_req`
- `assistant_capture_req` / `assistant_capture_triggered`
- `assistant_capture_btn_click`
- `assistant_capture` / `assistant_capture_failed`
- `assistant_answer_show` / `assistant_answer_failed`
- `assistant_rate_consume` / `assistant_rate_limited`
- `assistant_overlay_protect_enabled` / `assistant_overlay_protect_failed` / `assistant_overlay_protect_rearm`
- `assistant_overlay_risk_hide` / `assistant_overlay_risk_restore`
- `assistant_overlay_guard_forward` / `assistant_overlay_temp_hide` / `assistant_overlay_temp_restore`
- `assistant_overlay_sensitive_visible`

## 快捷键（默认）

- `Alt+Shift+A`：启动问答悬浮窗
- `F1`：截图并问答
- 悬浮窗按钮：点击 `截图问答` 与 `F1` 共用同一安全链路
- `Alt+Up / Alt+Down`：悬浮窗答案滚动

## 改动后必查

1. Assistant 页面顶部先展示只读的快捷键说明框。
2. 高级设置默认隐藏；关闭时整块不显示，开启后整块显示。
3. 基础设置中可以直接新增 / 删除模板。
4. Web 页不再展示 `API Endpoint` 输入框。
5. 截图保存目录只读显示，并可通过“修改目录”按钮切换；“打开目录”按钮可直接打开对应文件夹。
6. 主界面不再展示“最新截图文件”字段。
7. 透明度只能在 `20 / 50 / 75 / 100` 四档间切换。
8. 悬浮窗内不提供透明度修改入口，透明度仅在主界面调整。
9. 悬浮窗内不再显示“回答区”文字。
10. 回答文本应从左上角开始显示；长文本与代码段应自动换行，不出现整行横向拉长。
11. 录屏期间悬浮窗对本地持续可见，但截图 / 录屏结果中不应出现答案内容。
12. 悬浮窗不应出现在任务栏或常规窗口切换展示中。
13. 触发外部截图快捷键时，不应在截图中留下问答悬浮窗黑块。
14. 按 `F1` 后悬浮窗应保持原位与同一实例更新，不允许回答阶段闪烁重建或坐标跳回固定位置。
