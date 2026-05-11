# 改动计数与 Git 检查点规则

最近同步：`2026-05-11`
状态：`active`

## 1. 目的

这份文档只负责三件事：
- 记录当前连续改动次数
- 规定何时必须创建 git 检查点
- 给回退、交接、补档提供统一锚点

## 2. 强制规则

1. 每完成 1 次明确改动，且对应测试执行并通过后，计数 `+1`
2. 每累计满 `3` 次改动，无论大小，都必须立刻创建 1 个 git 检查点
3. 本项目里的 git 默认动作：
   - 本地 `commit`
   - 直接推送到 `origin/main`
4. 只有远端 `push` 成功后，这次 git 检查点才算真正完成
5. git 检查点完成后，连续改动计数清零
6. 高风险改动允许未满 `3` 次提前 git
7. 第一阶段开始前必须 git；第二阶段开始前也必须 git
8. 任何改动只有在测试通过后，才算“完成”
9. `docs/CHANGE_ACTIVITY_LOG.md` 只保留当前这一轮的 `1-3` 次改动

## 3. 什么算 1 次改动

按“一个连续目标的落地”计数，不按修改文件数或代码行数计数。

## 4. 当前状态

- 当前轮次：`2026-05-11-post-assistant-persistence-and-table-docs-checkpoint`
- 每 `3` 次改动强制 git：`是`
- 当前连续改动次数：`2`
- 下一次强制 git 阈值：`下一次完成 3 次通过测试的连续改动后，需执行 checkpoint commit 并 push 到 origin/main`
- 上一个 git 检查点：`checkpoint: sync assistant persistence and table docs`
- 当前计数说明：
  - 第 1 次：修复 F3 语音链路的启动/停止竞态；新增 `gAssistantVoiceInputStarting / gAssistantVoiceStopPending` 防重入状态，避免长按期间重复触发 `start`；同时让讯飞 service 在单次识别结束后保留 `completed / failed` 状态，不再立刻覆盖回 `ready`；并引入开源 `sounddevice` 作为 live 采集优先路径，减少 `ffmpeg dshow` 冷启动成本
  - 第 2 次：修复 F3 “显示未识别到语音内容”的当前主问题；新增 service 存活校验与会话启动确认，避免复用已失活的 service 对象或只发出 `start` 但未真正进入会话；若首次 service 未起效则自动重建并重试一次；停止时若最终 transcript 为空，则优先回退使用悬浮窗实时转写里已经拿到的文本，减少“已经识别出来却被判空”的情况

## 5. 维护方式

每次改动后都要同步两件事：
1. 在 `docs/CHANGE_ACTIVITY_LOG.md` 记录本轮改动内容与测试
2. 更新本文中的连续改动计数与当前状态

## 6. git 提交格式建议

- `checkpoint: ...`
- `archive: ...`

## 7. 远端要求

- 默认远端：`origin`
- 默认目标：`origin/main`
