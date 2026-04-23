# 文档更新清单（每次改动后执行）

## 必做

1. 更新受影响模块文档：`docs/modules/*.md`
2. 更新受影响公用块文档：`docs/shared/*.md`（如涉及）
3. 更新架构/API文档：`docs/components/*.md`（如涉及）
4. 追加 `docs/ACTION_LOG.md` 最近维护记录
5. 追加 `docs/DOC_CHANGELOG.md` 文档改动摘要

## 场景补充

1. 改 UI 样式或文案：更新 `docs/UI_STYLE_TOKENS.md`
2. 改运行方式或用户操作：更新 `README.md`
3. 改持久化格式：更新 `docs/modules/09_storage_and_files.md` 与 `docs/shared/03_storage_contract.md`
4. 改全局快捷键：优先更新 `docs/shared/01_global_hotkeys.md`；若改到配置页交互，再同步 `docs/modules/03_hotkey_settings.md`
5. 发生线上故障：创建 `docs/incidents/TEMP_*.md`，修复后删除临时文档并在日志中记录“已关闭”

## 完成标准

1. 不允许“只改代码不改文档”。
2. 交付说明里必须列出已更新的文档清单。
3. 若修复了临时故障，必须关闭/移除对应 TEMP 文档。

## Governance Additions

1. If architecture decision changed, update `docs/adr/*.md`.
2. If config contract changed, update `docs/config/*.md`.
3. If dependency relation changed, update `docs/architecture/DEPENDENCY_MAP.md`.
