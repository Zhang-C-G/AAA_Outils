# 改动流水文档

最近同步：`2026-04-26`
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。
满 3 次并完成 git checkpoint + push 后，历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-04-26-after-checkpoint-notes-reorder-and-panel-flicker-fix`
- 当前连续改动次数：`3`
- 本轮目标：`落地模块修改过程文档机制，收紧 E 模块语音模型配置，并修正 A 悬浮窗 Top10 来源`
- 上一个 git 检查点：`checkpoint: notes reorder and panel flicker fix`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 3 次改动窗口

### 第 1 次改动
- 时间：`2026-04-26`
- 内容：建立“每个模块都要维护自己的修改过程文档”的机制；新增统一规则、统一模板、模块修改过程索引，并为 A-H 现有模块批量建立各自的修改过程文档
- 影响文件：
  - `docs/modules/CHANGELOG_RULE.md`
  - `docs/modules/changelog/README.md`
  - `docs/modules/changelog/*.md`
  - `docs/templates/MODULE_CHANGELOG_TEMPLATE.md`
  - `docs/modules/README.md`
  - `docs/extension/文档体系总图.md`
  - `docs/AI_HANDOFF.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 文档校验：确认模块修改过程规则文档已创建
  - 文档校验：确认 `docs/modules/changelog/` 已建立 A-H 模块记录文档
  - 文档校验：确认 `README`、`文档体系总图`、`AI_HANDOFF` 已补入口
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例成功
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 2 次改动
- 时间：`2026-04-26`
- 内容：修正 E 模块语音模型选择；明确当前只有讯飞属于语音模型，因此语音模型下拉框只保留 `讯飞 WebSocket 语音识别`，不再把豆包模型列入语音模型候选
- 影响文件：
  - `webui/config/app-assistant.js`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 代码校验：确认 `voice_model` 默认值已改为 `xunfei_websocket_asr`
  - 代码校验：确认 `voice_model_options` 仅保留讯飞一项
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例成功
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 3 次改动
- 时间：`2026-04-26`
- 内容：修正 A 模块悬浮窗的默认 Top 10 来源；不再只从 `fields` 取，而是改为从 A 模块全部条目联合排序获取。搜索范围也同步恢复为 A 模块全部条目
- 影响文件：
  - `src/panel_ui.ahk`
  - `docs/modules/changelog/A_快捷字段_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 代码校验：确认默认榜单遍历 `gCategories`
  - 代码校验：确认搜索不再只限制 `fields`
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例成功
- 测试结果：`通过`
- 是否触发 git：`是，本次完成后执行 checkpoint`
