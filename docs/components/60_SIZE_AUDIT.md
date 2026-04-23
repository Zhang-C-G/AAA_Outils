# 文件体量审计（Size Audit）

审计时间：`2026-04-21`
审计范围：`src/`、`webui/config/`、`docs/`、`scripts/`、`README.md`
阈值：`> 200 行` 视为建议拆分

## Top 文件（按行数）

1. `src/storage/assistant.ahk`：247 行
2. `webui/config/app-shortcuts.js`：236 行
3. `src/storage/data_load.ahk`：228 行
4. `src/panel_ui.ahk`：223 行

## 结论

- 当前有 4 个文件超过目标阈值，属于“可运行但可维护性开始下降”的阶段。
- 本轮已完成：`webui/config/server-state.ps1` 与 `src/config_category_tabs.ahk` 的拆分降维。
- 最优先拆分对象是 `src/storage/assistant.ahk`。

## 建议拆分顺序

1. `src/storage/assistant.ahk`
2. `webui/config/app-shortcuts.js`
3. `src/storage/data_load.ahk`
4. `src/panel_ui.ahk`

## 备注

- 本审计仅用于维护成本评估，不代表当前功能不可用。
- 拆分时保持“功能域聚合”原则，避免过度碎片化。
