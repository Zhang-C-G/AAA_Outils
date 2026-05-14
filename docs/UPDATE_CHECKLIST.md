# 文档更新清单（每次改动后执行）

## 必做

0. 本轮开发开始前，先读取 `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`；如涉及悬浮窗，再读取 `docs/extension/OVERLAY_STAGE2_GUIDE.md`
0.1 如涉及具体业务模块，必须同时读取对应模块主文档：`docs/modules/*.md`
0.2 如涉及具体业务模块，必须同时读取对应模块修改过程文档：`docs/modules/changelog/*.md`
1. 更新受影响模块文档：`docs/modules/*.md`
1.1 更新受影响模块修改过程文档：`docs/modules/changelog/*.md`
2. 更新受影响公用块文档：`docs/shared/*.md`（如涉及）
3. 更新架构/API文档：`docs/components/*.md`（如涉及）
4. 检查并更新 `docs/AI_HANDOFF.md`（如本轮状态、优先级、风险、接手路径发生变化）
5. 追加 `docs/ACTION_LOG.md` 最近维护记录
6. 追加 `docs/DOC_CHANGELOG.md` 文档改动摘要
7. 若本轮完成了一条可独立验收的功能链路，测试通过后创建 git 检查点（提交或用户确认的固定版本点）

## 场景补充

1. 改 UI 样式或文案：更新 `docs/UI_STYLE_TOKENS.md`
2. 改运行方式或用户操作：更新 `README.md`
3. 改持久化格式：更新 `docs/modules/09_storage_and_files.md` 与 `docs/shared/03_storage_contract.md`
4. 改全局快捷键：优先更新 `docs/shared/01_global_hotkeys.md`；若改到配置页交互，再同步 `docs/modules/03_hotkey_settings.md`
5. 改整体目标、当前优先级、已知风险或交接方式：必须更新 `docs/AI_HANDOFF.md`
6. 发生线上故障：创建 `docs/incidents/TEMP_*.md`，修复后删除临时文档并在日志中记录“已关闭”
7. 链路级修复完成并通过验证：补充 bug 文档归档，并在必要时生成新的 git 检查点

## 完成标准

1. 不允许“只改代码不改文档”。
1.1 不允许“只看模块主文档，不看模块修改过程文档”。
2. 不允许“只改代码不改 AI 交接状态”。
3. 交付说明里必须列出已更新的文档清单。
4. 若修复了临时故障，必须关闭/移除对应 TEMP 文档。
5. 交付说明里必须显式说明：
   - 已做事项
   - 未做事项
   - 文档同步状态
   - 测试状态
   - git / checkpoint 状态

5.1 不再强制要求在回复中写 `当前轮次` 或 `第 N 轮`
5.2 `git / checkpoint 状态` 必须说明这是“本轮是否执行”的状态汇报，不能只写模糊结论
5.3 `git 状态` 必须显式写明当前处于本轮 `3` 次改动循环中的第几次，例如 `第 1 / 3 次`、`第 2 / 3 次`

## Governance Additions

1. If architecture decision changed, update `docs/adr/*.md`.
2. If config contract changed, update `docs/config/*.md`.
3. If dependency relation changed, update `docs/architecture/DEPENDENCY_MAP.md`.
