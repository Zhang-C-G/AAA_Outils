# 模块化文档索引（Modules Index）

最近同步：`2026-04-22`

## 目标

把软件拆成可独立维护的小模块；跨模块复用能力放在 `docs/shared/`。

## 业务模块（5 个）

1. `02_field_prompt_quickfield.md`：快捷字段（字段/提示词/快捷字段）
2. `04_notes.md`：笔记
3. `05_capture_to_phone.md`：截图发手机
4. `06_assistant_capture_qa.md`：截图问答助手
5. `11_resume_autofill.md`：简历自动填充

说明：
`全局快捷键` 不计入业务模块，归类在 `docs/shared/01_global_hotkeys.md`。

## 维护规则

1. 改代码后先定位受影响模块。
2. 更新对应 `docs/modules/*.md`。
3. 涉及公用能力同步 `docs/shared/*.md`。
4. 涉及架构/API 同步 `docs/components/*.md`。
5. 追加 `docs/ACTION_LOG.md` 与 `docs/DOC_CHANGELOG.md`。

## 其余实现模块文档清单（平台/运行/存储）

1. `01_hotkey_panel.md`：全局悬浮面板
2. `03_hotkey_settings.md`：快捷键配置页（公用能力管理入口）
3. `07_web_config_frontend.md`：Web 前端
4. `08_web_config_backend.md`：Web 后端
5. `09_storage_and_files.md`：存储层与文件
6. `10_runtime_and_state.md`：运行态与全局状态

## 相关入口

- 文档系统总图：`docs/DOC_SYSTEM.md`
- 公用块索引：`docs/shared/README.md`
- 更新清单：`docs/UPDATE_CHECKLIST.md`
- 模板：`docs/templates/MODULE_TEMPLATE.md`
