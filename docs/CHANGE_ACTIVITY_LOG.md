# 改动流水文档

最近同步：`2026-04-26`
状态：`active`

## 1. 文档定位

这份文档只记录“当前连续这一轮”的改动流水。

规则是：

- 最多只保留当前轮次的 `3` 次改动
- 一旦第 `3` 次改动触发 git 并成功推送远端，本文件就不继续累积旧历史
- 更早的历史版本统一通过 git 提交记录追溯

## 2. 当前轮次

- 轮次标识：`2026-04-26-after-checkpoint-fix-a-module-tab-double-click-rename`
- 当前连续改动次数：`0`
- 本轮目标：`按模块懒加载 Web 配置前端，并完成当前轮次 git 检查点`
- 上一个 git 检查点：`checkpoint: fix a-module tab double-click rename`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 3 次改动窗口

#### 第 1 次改动

- 时间：`2026-04-26`
- 内容：新建 TEMP 故障文档，聚焦“A 模块或其他模块信息没有成功写入数据库或维护文件”的持久化链路问题，并同步写入交接风险
- 影响文件：
  - `docs/incidents/TEMP_2026-04-26_storage_write_failure.md`
  - `docs/AI_HANDOFF.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
- 测试：
  - 文档机制复核：已检查故障文档路径、命名、结构是否符合 `docs/extension/DOC_CREATION_GUIDE.md` 与 `docs/templates/INCIDENT_TEMPLATE.md`
- 测试结果：`通过`
- 是否触发 git：`否`
- 备注：这是新轮次的第 `1` 次改动；当前只完成问题建档，尚未进入实际修复

## 4. 使用说明

- 第 `2` 次、第 `3` 次改动继续直接追加在本文档下方
- 当第 `3` 次改动完成并成功 git 后：
  1. 由 git 提交承担长期历史
  2. 本文档进入下一轮，只保留新的 1-3 次改动

#### 第 2 次改动

- 时间：`2026-04-26`
- 内容：沿 TEMP 故障文档继续排查持久化链路；确认后端 `/api/save -> config.ini` 能真实写盘，并把 A 模块栏目改名提交改为立即保存，减少延迟自动保存导致的丢失窗口
- 影响文件：
  - `webui/config/app-shortcuts.js`
  - `docs/incidents/TEMP_2026-04-26_storage_write_failure.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 静态检查：确认栏目改名提交后调用 `scheduleAutoSave(true)`
  - 真实闭环：通过 `/api/save` 临时写入测试栏目与测试行，再恢复原始状态，并直接核对 `config.ini` 片段
- 测试结果：`通过`
- 是否触发 git：`否`
- 备注：当前阶段性结论为“后端写盘链路可工作，问题更偏向前端触发时机或具体模块交互链路”

#### 第 3 次改动

- 时间：`2026-04-26`
- 内容：将 Web 配置前端改为按模块懒加载；启动时只拉取壳层状态（当前模式、模块顺序、全局热键），点击对应模块后才加载该模块数据，不再一次性加载全部模块
- 影响文件：
  - `webui/config/server_state/config.ps1`
  - `webui/config/server.ps1`
  - `webui/config/app-main.js`
  - `docs/modules/07_web_config_frontend.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 真实接口验证：`/api/app/state` 已返回轻量壳层状态，未返回 `categories/data/assistant` 整包数据
  - 静态代码验证：`app-main.js` 已包含 `ensureModeLoaded` 懒加载入口，启动路径改为 `/api/app/state`，且已移除旧的 `Promise.all` 全量预加载
- 测试结果：`通过`
- 是否触发 git：`是`
- git 检查点：`checkpoint: lazy load web config modules`
- 备注：这是当前轮次的第 `3` 次改动；测试通过后立即执行 git，并推送到远端

## 4. 当前状态

- 本轮第 `3` 次改动已完成，并已满足触发 git 的条件
- 下一轮开始时，本文档将按新轮次重新维护最多 `3` 次改动
