# 模块文档索引

最近同步：`2026-04-25`

## 1. 目标

`docs/modules/` 用于维护功能级文档。

这里的“功能级”包括两类：

1. 真正的业务模块
2. 历史保留的功能壳层或系统相关说明

因此，这个目录当前是“模块优先”，但还不是“纯业务模块目录”。

## 2. 使用规则

- 如果是用户可感知的独立功能，优先放这里
- 如果是跨模块契约，放 `docs/shared/`
- 如果是系统实现、状态流、接口或依赖结构，优先放 `docs/components/` 或 `docs/architecture/`
- 新增系统实现类文档，不建议继续写入 `docs/modules/`

## 3. 当前文档分组

### 3.1 核心业务模块

1. `02_field_prompt_quickfield.md`
2. `04_notes.md`
3. `05_capture_to_phone.md`
4. `06_assistant_capture_qa.md`
5. `11_resume_autofill.md`
6. `12_notes_display.md`

### 3.2 功能入口或功能壳层

1. `01_hotkey_panel.md`
2. `03_hotkey_settings.md`

### 3.3 历史保留的系统说明文档

1. `07_web_config_frontend.md`
2. `08_web_config_backend.md`
3. `09_storage_and_files.md`
4. `10_runtime_and_state.md`

说明：

- 这四份文档当前仍保留在 `docs/modules/`，主要为了兼容现有编号和引用
- 后续如果做深一轮重构，它们更适合归入系统实现层

## 4. 核心优先规则

- 每个模块文档都必须明确写出“核心主功能是什么”
- 任何次要问题、附加体验、样式优化，都不能以破坏模块核心为代价
- 排障和改需求时，先判断是否影响核心；如果影响核心，先恢复核心

## 5. 相关入口

- 文档系统总图：`docs/DOC_SYSTEM.md`
- 公用块索引：`docs/shared/README.md`
- 扩展开发规范：`docs/extension/README.md`
- 更新清单：`docs/UPDATE_CHECKLIST.md`
- 模块模板：`docs/templates/MODULE_TEMPLATE.md`

