# 模块 02：字段 / 提示词 / 快捷字段

最近同步：`2026-05-31`

## 模块目标

- 统一管理三类核心数据：`fields`、`prompts`、`quick_fields`。
- 支持栏目与条目的完整生命周期：新增、重命名、删除、拖拽重排、内容编辑。
- Web 配置页中采用自动保存，减少手动保存负担。

## 核心主功能

- 核心是三类数据可以被稳定编辑、保存、刷新后不丢失。
- 任何界面重排、交互简化、附加提示的修改，都不能以破坏真实落盘和刷新一致性为代价。

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
- 栏目改名进入编辑态时，栏目框尺寸保持不变，仅通过外圈白色边框提示当前正在编辑。
- 条目：新增、编辑、删除（自动保存触发）。
- A 模块悬浮窗插入链路：先把当前选中项内容粘贴进目标窗口，再延迟恢复用户原剪贴板，避免目标窗口误吃到旧剪贴板内容。
- 自动保存：字段页改动后延迟写盘；后端记录 payload 与落盘结果日志。
- 字段备份与导出（`2026-05-31`）：
  - 每次 Web 保存成功后，自动在 `backups/shortcuts/` 写入一份 JSON 备份（保留最近 40 份，并同步更新 `latest.json`）。
  - Web UI「A快捷字段」页提供：手动「备份字段」「从最近备份恢复」「导出字段」（JSON / INI 片段 / CSV）。
  - 导出范围：全部栏目及其触发词、正文内容（含隐藏的 `prompts`、`quick_fields` 与自定义栏目）。
- 自动刷新策略：改为系统内部维护与持久化，不在“快捷字段”页面显示配置项。
- 快捷字段可用于“高频标准指令”一键插入，例如：
  - `更新`：更新动作记录文档并同步各模块文档；若文件过大则自动拆分为子文件，防止文件臃肿并保持结构清晰。
- 从 `2026-04-26` 起，Web UI 的 A 模块标签栏默认只展示 `字段` 与用户自建栏目。
- `提示词`、`快捷字段` 继续保留在底层数据结构和存储层中，但前端标签栏默认不显示。

## 关键日志动作

- `category_add` / `category_rename` / `category_delete` / `category_reorder`
- `config_save_payload` / `config_save_result` / `config_save`

## 改动后必查

1. 新增条目后不手动点保存，刷新仍存在。
2. 删除条目后刷新不回弹。
3. 内置栏目 `fields/prompts/quick_fields` 不丢失。
4. 自定义栏目拖拽顺序刷新后一致。
5. Web UI 标签栏中不再显示 `提示词`、`快捷字段`。
6. 双击栏目改名时，不出现放大、外扩、加粗描边等突变，只保留白色外圈提示。
