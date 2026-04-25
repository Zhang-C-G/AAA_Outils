# 公用块索引

最近同步：`2026-04-25`

## 1. 目标

`docs/shared/` 用于维护跨多个模块复用的能力和契约。

这里放的不是某个单独模块的说明，而是“多个模块必须共同遵守”的规则。

## 2. 什么时候写到这里

满足下面任一条件，就优先写到 `docs/shared/`：

- 被多个模块复用
- 属于契约或规则
- 修改后会同时影响多个模块
- 需要统一命名、统一行为、统一日志

## 3. 当前公用块

1. `01_global_hotkeys.md`
   说明：全局热键定义、注册、作用域控制

2. `02_state_and_mode.md`
   说明：全局状态、模式切换、模式边界

3. `03_storage_contract.md`
   说明：存储、默认值、落盘契约

4. `04_logging_contract.md`
   说明：日志命名、记录时机、排障契约

5. `05_ui_tokens_contract.md`
   说明：UI token、文案风格、公共展示口径

## 4. 相关入口

- 文档系统总图：`docs/DOC_SYSTEM.md`
- 模块文档索引：`docs/modules/README.md`
- 扩展开发规范：`docs/extension/README.md`

