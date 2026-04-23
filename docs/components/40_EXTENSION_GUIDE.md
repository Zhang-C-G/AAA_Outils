# 扩展与拆分指南（Extension Guide）

## 当前拆分原则

- 以“功能域”拆分，不以“零散工具函数”拆分。
- 主壳层只做装配，不承载复杂业务逻辑。
- 高频变更区域独立成文件，降低冲突风险。
- 控制单文件体量：优先保持在 `<= 200 行` 或 `<= 8KB`；超过后优先拆分。

## 已完成拆分（2026-04-21）

- 存储层从单文件拆为 7 个模块（data_load/data_save/usage/notes/capture_file_ops/capture_bridge/assistant）。
- 模式层从单文件拆为 8 个模块（mode_state/mode_switch/notes_mode_ui/notes_mode_actions/capture_mode_ui/capture_mode_actions/assistant_mode_ui/assistant_mode_actions）。
- Web 服务拆为 6 个文件（入口 + common/state/notes/capture/assistant）。
- Web 前端拆为 6 个模块（common/shortcuts/notes/capture/assistant/main）。
- `src/config_category_tabs.ahk` 已进一步拆分为聚合入口 + 3 子模块（`config_tabs/crud.ahk` / `config_tabs/drag.ahk` / `config_tabs/version.ahk`）。
- `webui/config/server-state.ps1` 已进一步拆分为聚合入口 + 3 子模块（`server_state/capture.ps1` / `server_state/assistant.ps1` / `server_state/config.ps1`）。

## 下一轮优先建议

当前仍偏大的文件（`2026-04-21` 最新审计）：

- `src/storage/assistant.ahk`（247 行）：模板管理 + mock 模式 + API 调用集中
- `webui/config/app-shortcuts.js`（236 行）：快捷键模式前端状态与事件集中
- `src/storage/data_load.ahk`（228 行）：默认配置 + 全部加载逻辑集中
- `src/panel_ui.ahk`（223 行）：悬浮窗 UI + 匹配 + 插入链路集中

建议拆分方向：

1. `src/storage/assistant.ahk`
   - `assistant_settings.ahk`：默认值、模板归一化、配置读取
   - `assistant_request.ps1_builder.ahk`：API 请求构造与执行
   - `assistant_mock.ahk`：mock 模式输出
2. `webui/config/app-shortcuts.js`
   - `app-shortcuts-tabs.js`：栏目 tab 与重命名/拖拽
   - `app-shortcuts-rows.js`：条目 CRUD
   - `app-shortcuts-save.js`：保存与校验流程

## 体量评估结论（本轮）

- 结论：本轮已完成两处重点拆分，超阈值文件从 6 个下降到 4 个。
- 风险：继续叠加需求时，回归影响面会扩大，冲突概率上升。
- 建议：优先拆 `src/storage/assistant.ahk`，其余按需求并行拆分。

## 新功能接入清单

1. 明确该功能属于“新增模式”还是“现有模式增强”
2. 补齐配置读写（`src/storage/*.ahk`）
3. 补齐 UI 构建与事件（`src/config*.ahk` / `webui/config/*.js`）
4. 补齐动作日志埋点（`WriteLog`）
5. 更新 `docs/ACTION_LOG.md` 与 `docs/components/*.md`

## 文档同步清单（每轮改动后必须做）

1. 更新 `README.md` 的能力与结构描述
2. 更新 `docs/COMPONENTS.md` 的模块索引
3. 更新 `docs/ACTION_LOG.md` 的维护记录
4. 若涉及样式，更新 `docs/UI_STYLE_TOKENS.md`

## 质量门槛

- 不引入破坏现有全局热键链路的变更
- 默认数据可回滚（至少保留“保存版本/恢复版本”能力）
- 新增页面不影响模式切换稳定性
- 文档与代码必须同轮更新
