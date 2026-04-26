# 改动流水文档

最近同步：`2026-04-26`
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。满 3 次并完成 git checkpoint + push 后，历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-04-26-after-81dc34a`
- 当前连续改动次数：`3`
- 本轮目标：`补齐 E 模块语音模型 API 的受保护回填链路，并继续沉淀全局偏好`
- 上一个 git 检查点：`checkpoint: confirm dialogs, panel summon, resume autosave`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 1-3 次改动窗口

### 第 1 次改动
- 时间：`2026-04-26`
- 内容：补齐 E 模块“语音模型 API”的受保护存储与回填；前端继续用星号显示，公开状态增加 `has_voice_model_api_key`，使其 UI 行为与“问答模型 API”一致
- 影响文件：
  - `webui/config/server_state/assistant.ps1`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 代码校验：确认新增 `voice_model_api_key_protected` / `has_voice_model_api_key`
  - 语法校验：PowerShell Parser 成功解析 `webui/config/server_state/assistant.ps1`
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 2 次改动
- 时间：`2026-04-26`
- 内容：将“说明条允许使用斜杠纹理背景”沉淀为全局偏好；明确这类样式适用于快捷键说明、同步说明、只读提示等辅助区域
- 影响文件：
  - `docs/extension/global_preferences/components/15_说明条偏好.md`
  - `docs/extension/global_preferences/00_通用偏好结论.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 文档校验：确认新增 `15_说明条偏好.md`
  - 文档校验：确认 `00_通用偏好结论.md` 已补入说明条斜杠背景结论
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 3 次改动
- 时间：`2026-04-26`
- 内容：为 F 模块增加第一阶段“公司链接维护界面”UI；将头部改为一行进入提示，点击后切换到公司 / 链接地址 / 允许填充维护表，先只做界面不接填充逻辑
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 模块解析校验：通过 `vm.SourceTextModule` 成功解析 `webui/config/app-resume.js`
  - 代码校验：确认已新增 `resumeEntryBar`、`resumeCompanyPanel`、`resumeCompanyRows`
  - 启动校验：通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk` 实例
- 测试结果：`通过`
- 是否触发 git：`是，完成测试后执行 checkpoint`
