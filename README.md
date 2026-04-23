# Raccourci（热键）- AutoHotkey MVP

这是一个可运行的 Windows MVP，覆盖你提出的核心能力：

- 全局悬浮面板：`Alt+Q`
- 主配置窗口：`Alt+Shift+Q`
- 主界面模式切换：快捷键 / 笔记 / 截图发手机 / 截图问答
- 动态栏目机制：新增/内联改名/单次确认删除
- 版本机制：保存版本 / 恢复到最近保存版本

## 模块口径（当前）

- 业务模块：4 个（快捷字段、笔记、截图发手机、截图问答）。
- 全局快捷键：归类为 Shared 公用能力，不计入业务模块数量。
- “快捷键”页面是公用能力管理入口，不单独计入业务模块。

## 当前产品目标（核心定位）

本项目有两个同等核心目标：

- 输入提效核心：通过全局热键与悬浮面板，快速匹配并插入常用内容。
- 扩展切换核心：通过模式切换承载后续功能扩展（如笔记、截图发手机、日记、任务板等），并保持统一入口与一致交互。

## 运行要求

- Windows
- AutoHotkey v2.x

## 快速开始

1. 安装 AutoHotkey v2
2. 双击运行：`main.ahk`
3. 在任意输入框点击后，按 `Alt+Q`
4. 输入关键词，按 `Enter` 回填
5. 按 `Alt+Shift+Q` 打开主配置（默认进入 Web 配置界面）

## 主界面新增机制（你当前这轮需求）

- 栏目最右侧 `+`：新增栏目
- 双击栏目名：内联改名（无弹窗）
- 右下角 `删除当前栏目`：单次确认后删除
- 顶部右侧：`保存版本` / `恢复版本`
  - 保存版本：保存当前栏目和栏目内条目
  - 恢复版本：恢复到最近一次保存版本
- 顶部模式切换：`快捷字段` / `笔记` / `截图发手机` / `截图问答` / `快捷键`
- 快捷字段页：默认自动保存（新增/编辑/删除/排序后自动落盘）
- 快捷键页：独立全宽主区域展示，支持多列布局
- 笔记增强：
  - 左侧多笔记列表（按更新时间排序）
  - 右侧标题 + 正文编辑
  - 支持新建 / 保存 / 删除（二次确认）
  - 切换模式或关闭配置窗时自动保存当前笔记
- 截图发手机：
  - 一键全屏截图保存到 `captures\*.png`
  - 上传到可配置端点（默认 `https://0x0.st`）
  - 自动复制手机访问 URL，可选自动打开二维码
- 截图问答助手：
  - 先启动悬浮窗，再通过截图热键触发问答
  - 返回答案在同一悬浮窗原位更新（不重建、不跳位）
  - 支持悬浮窗答案滚动热键（默认 `Alt+Up` / `Alt+Down`，可自定义）
  - 支持在 Assistant 模块配置 `API Endpoint / API Key / Model / Opacity`
  - 支持多提示词模板（新增/删除/重命名模板，选择激活模板后按该模板回答）
  - 支持思考状态与实时读秒
  - 支持防截图/防录屏策略：
    - 优先 `WDA_EXCLUDEFROMCAPTURE`（本地可见、录制/截图不可见）
    - 若系统不支持则自动回退为“风险触发临时隐藏 + 原位恢复”
  - 说明：仅提供正常可见悬浮窗，不提供规避检测能力

## 快捷键

- 默认快捷键：
  - `Alt+Q`：打开/关闭小悬浮面板
  - `Esc`：关闭小悬浮面板
  - `Enter`：确认并插入当前选中项
  - `↑ / ↓`：切换候选项
  - `Alt+Shift+Q`：打开主配置窗口
  - `Alt+Shift+A`：启动截图问答悬浮窗
  - `F1`：截图并问答
  - `Alt+Up`：助手悬浮窗内容上移
  - `Alt+Down`：助手悬浮窗内容下移
- 快捷键支持友好写法：`Alt+Q`、`Alt+Shift+Q`、`Ctrl+J`。

## 代码结构（已拆分）

- `main.ahk`：入口文件（只负责加载模块并启动）
- `src/app_state.ahk`：全局状态与启动流程
- `src/theme.ahk`：主题颜色 Token
- `src/storage.ahk`：存储聚合入口（只做 include）
- `src/storage/data_load.ahk`：配置读取（栏目/热键/策略/模式/截图设置）
- `src/storage/data_save.ahk`：配置写盘与版本快照
- `src/storage/usage.ahk`：usage 频率读写
- `src/storage/notes.ahk`：笔记读写
- `src/storage/capture_file_ops.ahk`：截图/上传基础能力
- `src/storage/capture_bridge.ahk`：手机桥接状态与进程控制
- `src/storage/assistant.ahk`：截图问答助手设置与模型调用
- `src/assistant_overlay.ahk`：问答结果悬浮窗（透明度可调）
- `src/hotkeys.ahk`：热键定义与动态注册
- `src/strategy.ahk`：默认展示自动刷新策略
- `src/panel_ui.ahk`：小悬浮面板逻辑
- `src/config_ui.ahk`：主配置界面壳层（布局与装配）
- `src/config_modes.ahk`：模式子模块聚合入口（只做 include）
- `src/config_modes/mode_state.ahk`：模式状态变量
- `src/config_modes/mode_switch.ahk`：模式切换逻辑
- `src/config_modes/notes_mode_ui.ahk`：笔记模式 UI
- `src/config_modes/notes_mode_actions.ahk`：笔记模式事件
- `src/config_modes/capture_mode_ui.ahk`：截图模式 UI
- `src/config_modes/capture_mode_actions.ahk`：截图模式事件与状态刷新
- `src/config_modes/assistant_mode_ui.ahk`：助手模式 UI
- `src/config_modes/assistant_mode_actions.ahk`：助手模式事件
- `src/config_category_items.ahk`：栏目条目子模块（条目增删改、条目上下移动、使用次数辅助）
- `src/config_category_tabs.ahk`：栏目级子模块聚合入口（只做 include）
- `src/config_tabs/crud.ahk`：栏目新增、重命名、删除
- `src/config_tabs/drag.ahk`：栏目拖拽重排
- `src/config_tabs/version.ahk`：版本保存与恢复
- `src/config_behavior_hotkeys.ahk`：快捷键与策略子模块
- `src/web_config.ahk`：Web 配置桥接（服务启动、热加载）
- `webui/config/server.ps1`：Web API 路由入口
- `webui/config/server-common.ps1`：Web 公共函数
- `webui/config/server-state.ps1`：配置状态聚合入口（只做 include）
- `webui/config/server_state/capture.ps1`：截图配置读写
- `webui/config/server_state/assistant.ps1`：助手配置与模板读写
- `webui/config/server_state/config.ps1`：主配置状态读写
- `webui/config/server-notes.ps1`：笔记接口
- `webui/config/server-capture.ps1`：截图发手机接口
- `webui/config/server-assistant.ps1`：截图问答接口
- `webui/config/app-main.js`：Web 前端入口
- `webui/config/app-shortcuts.js`：快捷键模式前端
- `webui/config/app-notes.js`：笔记模式前端
- `webui/config/app-capture.js`：截图模式前端
- `webui/config/app-assistant.js`：截图问答模式前端
- `src/effects.ahk`：动画与输入法切换
- `src/helpers.ahk`：通用工具函数
- `docs/ACTION_LOG.md`：动作日志规范
- `docs/COMPONENTS.md`：组件说明（供后续 AI 快速接手）
- `docs/UI_STYLE_TOKENS.md`：界面颜色/文字样式映射
- `docs/components/*.md`：按功能域拆分的组件子文档
- `docs/modules/README.md`：按小功能拆分的模块文档索引（每模块独立维护）
- `docs/UPDATE_CHECKLIST.md`：每次改动后的文档更新清单

## 数据文件

- 配置文件：`config.ini`
- 配置分区：`[Categories]` / `[Fields|Prompts|QuickFields|Category_*]` / `[Hotkeys]` / `[Behavior]` / `[App]` / `[Capture]` / `[Assistant]` / `[AssistantTemplates]`
- 使用频率：`usage.ini`
- 版本快照：`config.snapshot.ini`
- 动作日志：`action.log`
- 笔记目录：`notes\*.md`
- 截图目录：`captures\*.png`

## 测试脚本

- 本地模拟问答链路测试（不调用外部 API）：
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test_assistant_mock.ps1`
