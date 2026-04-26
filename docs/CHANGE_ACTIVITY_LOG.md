# 改动流水文档

最近同步：`2026-04-26`
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。
满 3 次并完成 git checkpoint + push 后，旧历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-04-26-after-checkpoint-harden-a-module-persistence`
- 当前连续改动次数：`3`
- 本轮目标：`收紧排查方法，避免持久化问题继续空转；同时修正 AHK 重启方式，禁止重复拉起多个实例`
- 上一个 git 检查点：`checkpoint: harden a-module persistence and startup load`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 3 次改动窗口

### 第 1 次改动

- 时间：`2026-04-26`
- 内容：新增精确重启脚本 `scripts/restart_main_ahk.ps1`，后续统一按“先定位命令行指向本项目 `main.ahk` 的旧实例，再停止，再拉起同一脚本”的方式重启，避免重复开启新 AHK 实例导致托盘图标堆积
- 影响文件：
  - `scripts/restart_main_ahk.ps1`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 实际执行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\restart_main_ahk.ps1`
  - 进程校验：只保留 1 个命令行指向本项目 `main.ahk` 的 AutoHotkey 进程
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 2 次改动

- 时间：`2026-04-26`
- 内容：定位并恢复“A 模块字段内容没有被加载”的当前直接原因；确认不是前端漏渲染，而是现用 `config.ini` 的 `[Fields] / [Prompts] / [QuickFields]` 已被写空。已从最近可用 git 版本恢复这三段数据到当前配置
- 影响文件：
  - `config.ini`
  - `docs/incidents/TEMP_2026-04-26_storage_write_failure.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 真实状态校验：恢复后重新请求 `http://127.0.0.1:8798/api/state`
  - 结果确认：`data.fields=5`、`data.prompts=2`、`data.quick_fields=1`
  - 实例校验：通过 `scripts/restart_main_ahk.ps1` 重启后仍只保留 1 个本项目 `main.ahk` 进程
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 3 次改动

- 时间：`2026-04-26`
- 内容：修复“新增栏目保存失败”的直接原因；前端保存前快捷键冲突校验原本按全局唯一处理，误把不同模块 / 不同作用域的相同按键判成冲突，导致新增栏目触发立即保存时被前端拦下。现已改为只在同一 `scope` 内校验冲突
- 影响文件：
  - `webui/config/app-shortcuts.js`
  - `docs/incidents/TEMP_2026-04-26_storage_write_failure.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 真实保存测试：用当前 `/api/state` 生成 payload，新增空栏目 `cat_test_scope_ok` 后提交 `/api/save`
  - 结果确认：保存成功，`/api/state` 返回测试栏目存在且 `rows=0`
  - 测试清理：测试栏目已删除，确认未残留在当前配置
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启后仍只保留 1 个本项目 `main.ahk` 实例
- 测试结果：`通过`
- 是否触发 git：`是，按第 3 次改动执行 checkpoint`
