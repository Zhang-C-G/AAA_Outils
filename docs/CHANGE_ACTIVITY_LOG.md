# 改动流水文档

最近同步：`2026-04-26`  
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。  
满 3 次并完成 git checkpoint + push 后，历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-04-26-after-checkpoint-fix-a-module-add-tab-save-validation`
- 当前连续改动次数：`3`
- 本轮目标：`把 bug / incident 文档机制落地，并补齐 A 模块栏目个性化持久化能力`
- 上一个 git 检查点：`checkpoint: fix a-module add-tab save validation`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 3 次改动窗口

### 第 1 次改动
- 时间：`2026-04-26`
- 内容：构建独立的 BUG / incident 文档机制；新增 `docs/incidents/README.md` 作为 incident 目录入口，并重写 `docs/templates/INCIDENT_TEMPLATE.md` 作为统一模板
- 影响文件：
  - `docs/incidents/README.md`
  - `docs/templates/INCIDENT_TEMPLATE.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 确认 `docs/incidents/README.md` 已创建
  - 确认 `docs/templates/INCIDENT_TEMPLATE.md` 已创建并包含核心段落
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 2 次改动
- 时间：`2026-04-26`
- 内容：把“栏目改名时输入框应贴合外部栏目框”的要求写入全局私人偏好体系，并同步到通用结论层与栏目框偏好层
- 影响文件：
  - `docs/extension/global_preferences/components/10_栏目框偏好.md`
  - `docs/extension/global_preferences/00_通用偏好结论.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 文档校验：确认组件层已新增“编辑态贴合”要求
  - 文档校验：确认通用结论层已同步该偏好
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 3 次改动
- 时间：`2026-04-26`
- 内容：为 A 模块栏目补齐“当前选中栏目”的持久化链路；点击 `Codex` 这类自定义栏目后，会把当前栏目写入 `App.shortcuts_selected_category`，下次重新进入时优先恢复上次选中的栏目
- 影响文件：
  - `webui/config/app-shortcuts.js`
  - `webui/config/server_state/config.ps1`
  - `src/storage/data_load.ahk`
  - `src/storage/data_save.ahk`
  - `docs/extension/global_preferences/components/10_栏目框偏好.md`
  - `docs/extension/global_preferences/00_通用偏好结论.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 语法校验：PowerShell 点载入 `webui/config/server_state/config.ps1` 成功
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例成功
  - 持久化校验：调用 `/api/app/shortcuts-category` 写入 `cat_1777196053431`
  - 配置校验：`config.ini` 已存在 `shortcuts_selected_category=cat_1777196053431`
  - 重启校验：重启后调用 `/api/state`，返回 `shortcuts_selected_category=cat_1777196053431`
- 测试结果：`通过`
- 是否触发 git：`是，本次完成后执行 checkpoint`
