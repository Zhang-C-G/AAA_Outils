# 改动流水文档。

最近同步：`2026-04-26`  
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。  
满 3 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-04-26-after-checkpoint-codex-optimization-self-eval`
- 当前连续改动次数：`1`
- 本轮目标：`修复 A 模块悬浮窗候选插入复用旧剪贴板的问题，并把 checkpoint 后的文档计数轮次恢复到新一轮`
- 上一个 git 检查点：`checkpoint: codex optimization self-eval rule`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 1-3 次改动窗口

### 第 1 次改动
- 时间：`2026-04-26`
- 内容：`修复 A 模块悬浮窗选择候选后，目标窗口偶发插入旧剪贴板内容的问题；插入链路改为先粘贴目标值，再延迟恢复原剪贴板。同时修正文档机制在上次 checkpoint 后未开启新轮计数的问题。`
- 影响文件：
  - `src/app_state.ahk`
  - `src/panel_ui.ahk`
  - `docs/modules/02_field_prompt_quickfield.md`
  - `docs/modules/changelog/A_快捷字段_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例
  - 进程校验：确认当前仅存在 1 个绑定 `main.ahk` 的 AutoHotkey 进程
  - 自动化插入测试：预置旧剪贴板 `OLD_CLIP_16`，在 Notepad 中通过 A 模块悬浮窗选择 `16`，确认最终文本为 `16680512973`
  - 日志校验：确认出现 `insert_success | restore=delayed` 与 `clipboard_restore | source=panel_insert ok=1`
- 测试结果：`通过`
- 是否触发 git：`否`
