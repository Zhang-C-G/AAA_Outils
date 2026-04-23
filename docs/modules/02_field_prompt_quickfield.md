# 模块 02：字段 / 提示词 / 快捷字段

## 模块目标

- 统一管理三类核心数据：`fields`、`prompts`、`quick_fields`。
- 支持栏目与条目的完整生命周期：新增、重命名、删除、拖拽重排、内容编辑。
- Web 配置页中采用自动保存，减少手动保存负担。

## 主要文件

- `src/config_category_items.ahk`
- `src/config_category_tabs.ahk`
- `src/config_tabs/crud.ahk`
- `src/config_tabs/drag.ahk`
- `src/config_tabs/version.ahk`
- `webui/config/app-shortcuts.js`

## 存储位置

- `config.ini`
- 关键分区：`[Categories]`、`[Fields]`、`[Prompts]`、`[QuickFields]`、`[Category_*]`

## 关键行为

- 栏目：新增、双击改名、单次确认删除、拖拽重排。
- 条目：新增、编辑、删除（自动保存触发）。
- 自动保存：字段页改动后延迟写盘；后端记录 payload 与落盘结果日志。
- 自动刷新策略：改为系统内部维护与持久化，不在“快捷字段”页面显示配置项。
- 快捷字段可用于“高频标准指令”一键插入，例如：
  - `更新`：更新动作记录文档并同步各模块文档；若文件过大则自动拆分为子文件，防止文件臃肿并保持结构清晰。

## 关键日志动作

- `category_add` / `category_rename` / `category_delete` / `category_reorder`
- `config_save_payload` / `config_save_result` / `config_save`

## 改动后必查

1. 新增条目后不手动点保存，刷新仍存在。
2. 删除条目后刷新不回弹。
3. 内置栏目 `fields/prompts/quick_fields` 不丢失。
4. 自定义栏目拖拽顺序刷新后一致。
