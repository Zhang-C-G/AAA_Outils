# 软件组件文档（总览索引）

项目：`Raccourci`
入口：`main.ahk`
最近同步：`2026-04-24`

## 产品核心定位（必须保持）

- 核心一：输入提效器（全局热键 + 悬浮匹配 + 一键插入）。
- 核心二：扩展容器（通过模式切换承载笔记、截图发手机、后续新能力）。
- 结论：扩展能力是核心功能的一部分，改造时必须保留统一的模式切换入口。

## 核心优先原则（必须保持）

- 每个模块都必须先定义“核心主功能是什么”，再讨论体验优化、附加能力与边界修复。
- 任何非核心问题，都不能通过牺牲核心主功能来换取“看起来更稳定”或“局部更好看”的结果。
- 如果两个目标冲突，必须优先保住模块核心功能，再处理次级问题。
- 文档、实现、排障结论都必须明确写出该模块的核心，避免后续改动偏离主线。
- 面向外部环境的不确定性（如随机录屏软件、随机网站、随机输入目标）默认按“通用兼容”处理，不能把核心能力建立在某个特定软件的定向兼容上。

## 文档拆分说明（2026-04-20）

为了避免单文件持续臃肿，组件文档拆为“总览 + 分模块文件”：

1. `docs/COMPONENTS.md`（本文件）：总览、入口、导航
2. `docs/components/10_RUNTIME_FLOW.md`：启动流程与运行链路
3. `docs/components/20_UI_AND_MODES.md`：UI 结构、栏目机制、模式机制
4. `docs/components/30_DATA_AND_FILES.md`：状态变量与数据文件
5. `docs/components/40_EXTENSION_GUIDE.md`：扩展规则与拆分策略
6. `docs/components/50_WEB_API.md`：Web 配置接口与前端模块
7. `docs/components/60_SIZE_AUDIT.md`：文件体量审计与拆分优先级

## 快速入口

- 使用说明：`README.md`
- AI 交接入口：`docs/AI_HANDOFF.md`
- 动作日志说明：`docs/ACTION_LOG.md`
- 主题文字/颜色 token：`docs/UI_STYLE_TOKENS.md`
- 组件拆分文档目录：`docs/components/`
- 模块化维护目录：`docs/modules/README.md`
- 公用块维护目录：`docs/shared/README.md`
- 扩展开发规范目录：`docs/extension/README.md`
- 文档系统总图：`docs/DOC_SYSTEM.md`
- AI 开发分阶段指南：`docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`
- 悬浮窗二阶段开发指南：`docs/extension/OVERLAY_STAGE2_GUIDE.md`
- 决策记录（ADR）：`docs/adr/README.md`
- 更新执行清单：`docs/UPDATE_CHECKLIST.md`

## 开发前置要求（必须保持）

- 每次开始一个新的开发阶段前，必须先阅读 `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`。
- 如果本轮开发涉及悬浮窗、保护态、热键作用域、位置保存、隐藏恢复，还必须同时阅读 `docs/extension/OVERLAY_STAGE2_GUIDE.md`。
- 如果本轮开发针对某个具体模块，还必须同时阅读对应 `docs/modules/*.md`。

## 目录结构（代码）

- `main.ahk`：轻量入口，仅负责 `#Include` 与 `Init()`
- `src/app_state.ahk`：全局状态定义、启动流程、开发态源码自动重载
- `src/theme.ahk`：主题颜色 Token 定义
- `src/storage.ahk`：存储模块聚合入口（只做 include）
- `src/storage/data_load.ahk`：配置读取与默认数据
- `src/storage/data_save.ahk`：配置写回与版本快照
- `src/storage/usage.ahk`：触发词使用频率读写
- `src/storage/notes.ahk`：笔记读写与元数据
- `src/storage/capture_file_ops.ahk`：截图文件与上传基础能力
- `src/storage/capture_bridge.ahk`：手机桥接状态与服务进程控制
- `src/storage/assistant.ahk`：截图问答助手设置（含多模板提示词）与模型调用
- `src/assistant_overlay.ahk`：问答结果悬浮窗与透明度控制
- `src/web_config.ahk`：Web 配置桥接（服务启动、状态同步、热加载）
- `webui/config/server.ps1`：Web 配置路由入口
- `webui/config/server-common.ps1`：Web 服务公共工具
- `webui/config/server-state.ps1`：配置状态聚合入口（内部 include 子模块）
- `webui/config/server_state/capture.ps1`：Capture 配置读写
- `webui/config/server_state/assistant.ps1`：Assistant 配置与模板读写
- `webui/config/server_state/config.ps1`：Categories/Data/Hotkeys/Behavior/App 状态读写
- `webui/config/server-notes.ps1`：笔记接口实现
- `webui/config/server-capture.ps1`：截图发手机接口实现
- `webui/config/server-assistant.ps1`：截图问答接口实现
- `webui/config/server-resume.ps1`：简历 Profile 接口实现
- `src/hotkeys.ahk`：热键定义、动态注册、作用域控制
- `src/strategy.ahk`：默认展示自动更新策略与定时器
- `src/panel_ui.ahk`：悬浮面板 UI、搜索匹配、插入流程
- `src/config_ui.ahk`：主配置界面壳层（布局与装配）
- `src/config_modes.ahk`：模式子模块聚合入口（只做 include）
- `src/config_modes/mode_state.ahk`：模式页状态变量
- `src/config_modes/mode_switch.ahk`：模式切换逻辑
- `src/config_modes/notes_mode_ui.ahk`：笔记模式 UI
- `src/config_modes/notes_mode_actions.ahk`：笔记模式事件与保存逻辑
- `src/config_modes/capture_mode_ui.ahk`：截图模式 UI
- `src/config_modes/capture_mode_actions.ahk`：截图模式事件与连接状态逻辑
- `src/config_modes/assistant_mode_ui.ahk`：截图问答模式 UI
- `src/config_modes/assistant_mode_actions.ahk`：截图问答模式事件与执行逻辑
- `src/config_category_items.ahk`：栏目条目子模块（增删改、上下移动）
- `src/config_category_tabs.ahk`：栏目级子模块聚合入口（只做 include）
- `src/config_tabs/crud.ahk`：栏目新增/改名/删除
- `src/config_tabs/drag.ahk`：栏目拖拽重排
- `src/config_tabs/version.ahk`：版本保存/恢复
- `src/config_behavior_hotkeys.ahk`：快捷键与策略子模块（编辑、校验、恢复默认）
- `src/effects.ahk`：面板动画、输入法切换
- `src/helpers.ahk`：工具函数（日志、匹配、字符串、热键格式转换）
- `webui/config/index.html`：Web 配置页结构
- `webui/config/styles.css`：Web 配置页样式
- `webui/config/app-common.js`：共享状态与工具
- `webui/config/app-shortcuts.js`：快捷键模式
- `webui/config/app-notes.js`：笔记模式
- `webui/config/app-capture.js`：截图模式
- `webui/config/app-assistant.js`：截图问答模式
- `webui/config/app-testing.js`：测试模式（录屏探针 + API 基线测试）
- `webui/config/app-resume.js`：简历自动填写模式
- `webui/config/app-main.js`：入口与模式切换
- `browser_extension/resume_autofill/*`：简历自动填写浏览器插件骨架
- Web 顶部按钮现为：`快捷字段/笔记/截图发手机/截图问答/简历自动填写/快捷键/测试`，其中“快捷键”为专用视图入口（后端仍映射 `shortcuts` 模式）
- `测试` 视图当前同时承载两类能力：
  - 录屏捕获检测
  - 截图问答 API 基线测试（固定默认题图、独立选模型、秒级计时）
- `scripts/test_assistant_mock.ps1`：截图问答本地模拟链路测试脚本（不调用外部 API）

## 维护要求

- 开发时默认存在 AHK 自动热重载：修改 `main.ahk` 或 `src/*.ahk` 后，运行中的脚本会自动刷新；后续 AI 排障时必须先考虑这一行为。
- 每次重要改动后，必须检查并更新 `docs/AI_HANDOFF.md`，保证下一个 AI 能快速接手当前状态与下一步工作。
- 修改系统行为时，必须同步更新 `docs/ACTION_LOG.md` 与对应 `docs/components/*.md`。
- 修改具体功能模块时，必须同步更新对应 `docs/modules/*.md`。
- 更新模块文档时，必须同步检查该模块“核心主功能”描述是否仍与当前实现一致。
- 新功能优先写入已有功能域文件；若超过合理体量，再按功能域继续拆分，不做杂糅拆分。
