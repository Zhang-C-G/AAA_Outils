# 改动流水文档

最近同步：`2026-04-26`
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。满 3 次并完成 git checkpoint + push 后，历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-04-26-after-f5bb764`
- 当前连续改动次数：`1`
- 本轮目标：`统一删除确认交互，落地自定义确认弹窗偏好`
- 上一个 git 检查点：`checkpoint: fix a-panel top10 scope and voice model`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 1-3 次改动窗口

### 第 1 次改动
- 时间：`2026-04-26`
- 内容：统一 A 模块栏目删除、B 模块笔记删除、E 模块模板删除的确认链路；全部改为应用内自定义弹窗，并将删除操作收敛为一次确认；同时新增“弹窗确认偏好”文档并更新全局偏好结论
- 影响文件：
  - `webui/config/app-common.js`
  - `webui/config/app-notes.js`
  - `webui/config/app-shortcuts.js`
  - `webui/config/app-assistant.js`
  - `webui/config/styles.css`
  - `docs/extension/global_preferences/components/14_弹窗确认偏好.md`
  - `docs/extension/global_preferences/00_通用偏好结论.md`
  - `docs/modules/changelog/A_快捷字段_修改过程.md`
  - `docs/modules/changelog/B_笔记_修改过程.md`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 代码校验：确认三条删除链路均改为 `confirmDialog`
  - 全局搜索：确认 `webui/config` 中不再残留默认 `confirm()`
  - 模块解析校验：通过 `vm.SourceTextModule` 成功解析 `app-common.js`、`app-notes.js`、`app-shortcuts.js`、`app-assistant.js`
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 2 次改动
- 时间：`2026-04-26`
- 内容：继续收敛 A 模块悬浮窗唤出时的闪帧；改为在隐藏态完成预热、内容刷新、定位和重绘，再一次性显示，尽量去掉“先闪一下再出现”
- 影响文件：
  - `src/app_state.ahk`
  - `src/panel_ui.ahk`
  - `docs/modules/changelog/A_快捷字段_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 代码校验：确认新增 `gPanelPrimed` 预热状态
  - 代码校验：确认 `BuildPanelGui()` 与 `ShowPanel()` 已切换为隐藏态预布局方案
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 3 次改动
- 时间：`2026-04-26`
- 内容：删除 F 模块保存按钮，并将 F 模块切到自动保存；同时覆盖 Web 端与 AHK 配置界面两条入口，统一符合“不要保存按钮、偏好自动保存”的个人偏好
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/app-resume.js`
  - `src/config_modes/resume_mode_ui.ahk`
  - `src/config_modes/resume_mode_actions.ahk`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 代码校验：确认 Web F 模块保存按钮已移除
  - 代码校验：确认 AHK F 模块已改为字段修改后自动保存
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例
- 测试结果：`通过`
- 是否触发 git：`是，完成测试后执行 checkpoint`
