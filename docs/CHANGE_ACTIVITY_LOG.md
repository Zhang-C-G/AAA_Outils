# 改动流水文档

最近同步：`2026-04-26`
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。
满 3 次并完成 git checkpoint + push 后，旧历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-04-26-after-checkpoint-fix-a-module-tab-double-click-rename`
- 当前连续改动次数：`3`
- 本轮目标：`继续修复 A 模块栏目/字段改动在重新进入后丢失的问题，并补强自动保存后的落盘保护`
- 上一个 git 检查点：`checkpoint: fix a-module tab double-click rename`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 3 次改动窗口

### 第 1 次改动

- 时间：`2026-04-26`
- 内容：把 A 模块栏目新增、改名、删除、拖拽排序这 4 类结构性改动统一改为立即保存，避免刚改完就退出时丢失
- 影响文件：
  - `webui/config/app-shortcuts.js`
  - `docs/incidents/TEMP_2026-04-26_storage_write_failure.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 静态检查 4 条结构改动链路都已改为立即保存
  - 真实 `/api/save -> /api/state` 回路验证空栏目可写入并可回读
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 2 次改动

- 时间：`2026-04-26`
- 内容：为 A 模块默认页增加首屏预取；当上次停留在 `shortcuts / hotkeys` 时，`/api/app/state` 直接返回 `shortcuts_prefetch`，前端启动时不再额外补打一遍 `/api/state`
- 影响文件：
  - `webui/config/server_state/config.ps1`
  - `webui/config/app-main.js`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 真实接口测试 `http://127.0.0.1:8798/api/app/state`
  - 结果确认：`active_mode=shortcuts` 且 `has_shortcuts_prefetch=true`
  - 数据确认：预取数据直接包含 A 模块栏目和字段
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 3 次改动

- 时间：`2026-04-26`
- 内容：补强 AHK 侧的落盘保护；`SaveData()` 除了继续处理 web reload action 外，新增“比较 `config.ini` 修改时间”的二次保护。只要磁盘版本比当前内存新，就先 `ReloadAppStateFromDisk()`，再继续保存，避免旧内存把 Web 刚保存的栏目/字段覆盖回去
- 影响文件：
  - `src/app_state.ahk`
  - `src/web_config.ahk`
  - `src/storage/data_save.ahk`
  - `docs/incidents/TEMP_2026-04-26_storage_write_failure.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 主程序重启测试：`main.ahk` 重启后正常拉起
  - 真实 Web 配置服务测试：手动启动本地配置服务后，`/api/ping` 返回 `ok=true`
  - 真实保存回路测试：`/api/save -> /api/state` 验证保存链路仍然可写入、可回读
  - 测试清理：已删除测试用 `cat_save_probe`，确认未残留到当前配置
- 测试结果：`通过`
- 是否触发 git：`是，按第 3 次改动执行 checkpoint`

## 4. 使用说明

- 当前轮次已满 `3` 次，下一步必须执行 git checkpoint 并推送远端
- git 完成后，本文件进入下一轮，只保留新的 `1-3` 次改动
