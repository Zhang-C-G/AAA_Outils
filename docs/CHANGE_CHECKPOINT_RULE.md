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

- 当前轮次：`2026-05-11-post-assistant-voice-model-checkpoint`
- 每 `3` 次改动强制 git：`是`
- 当前连续改动次数：`3`
- 下一次强制 git 阈值：`已达到 3/3，需立即执行 checkpoint commit 并 push 到 origin/main`
- 上一个 git 检查点：`checkpoint: wire assistant voice model persistence`
- 当前计数说明：
  - 第 1 次：E 模块 F3 已真实接入讯飞 WebSocket 语音识别链路，包含本地录音、讯飞识别上传、识别结果回写、本机密钥持久化与 AHK 停止等待时间补强
  - 第 2 次：E 模块新增 DeepSeek V4 Pro 问答模型，接入独立密钥持久化、按模型自动切换 endpoint，并完成真实 API 冒烟测试
  - 第 3 次：E 模块 F3 讯飞语音识别继续排障，已将链路推进到真实讯飞鉴权层；当前服务端明确返回 `HMAC signature does not match`，并已切换为 Python WebSocket worker 透传真实错误

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
