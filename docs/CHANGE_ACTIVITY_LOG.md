# 改动流水文档

最近同步：`2026-04-26`  
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。  
满 3 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-04-26-after-checkpoint-doc-stage-and-e-toggle`
- 当前连续改动次数：`2`
- 本轮目标：`补齐第二阶段风险输入层，并统一修平入口文档口径`
- 上一个 git 检查点：`checkpoint: stage docs and E overlay toggle`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 1-3 次改动窗口

### 第 1 次改动
- 时间：`2026-04-26`
- 内容：`新增第二阶段风险知识库 STAGE2_RISK_KB.md，并将其正式接入 AI_DEVELOPMENT_PLAYBOOK.md，作为第二阶段真实闭环开发前的风险输入文档。`
- 影响文件：
  - `docs/incidents/STAGE2_RISK_KB.md`
  - `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 文档结构校验：确认已新增 `docs/incidents/STAGE2_RISK_KB.md`
  - 文档结构校验：确认 `AI_DEVELOPMENT_PLAYBOOK.md` 已把风险知识库接入第二阶段入口与执行顺序
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例
  - 进程校验：确认当前仅存在 1 个绑定 `main.ahk` 的 AutoHotkey 进程
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 2 次改动
- 时间：`2026-04-26`
- 内容：`统一修平 5 份入口文档口径；让文档体系总图、全局私人偏好总入口、新模块清单、文档创建指南、AI_HANDOFF 与现行规则保持一致，全部明确第一阶段读取 UI 类偏好，第二阶段读取 STAGE2_RISK_KB 风险知识库。`
- 影响文件：
  - `docs/extension/文档体系总图.md`
  - `docs/extension/全局私人偏好文档.md`
  - `docs/extension/NEW_MODE_CHECKLIST.md`
  - `docs/extension/DOC_CREATION_GUIDE.md`
  - `docs/AI_HANDOFF.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 交叉校验：确认 5 份入口文档均已包含“第一阶段 UI 类偏好读取”与“第二阶段风险知识库读取”口径
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例
  - 进程校验：确认当前仅存在 1 个绑定 `main.ahk` 的 AutoHotkey 进程
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 3 次改动
- 时间：`2026-04-26`
- 内容：`将“Codex 每轮任务完成后可提出优化建议，但必须先自评；仅在强相关、低风险、边界不变、无需新决策、且可在当前轮完成实现测试记录时才允许直接落地”的规则正式写入开发总指引与 AI 接手文档。`
- 影响文件：
  - `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`
  - `docs/AI_HANDOFF.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 文本校验：确认 `AI_DEVELOPMENT_PLAYBOOK.md` 已写入优化建议自评与可直做条件
  - 文本校验：确认 `AI_HANDOFF.md` 已写入同口径稳定共识
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例
  - 进程校验：确认当前仅存在 1 个绑定 `main.ahk` 的 AutoHotkey 进程
- 测试结果：`通过`
- 是否触发 git：`是`
