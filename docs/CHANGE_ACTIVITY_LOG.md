# 改动流水文档

最近同步：`2026-05-11`
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。
满 3 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-05-11-post-assistant-voice-model-checkpoint`
- 当前连续改动次数：`2`
- 本轮目标：
  - 完成 E 模块语音与问答模型的真实接入，让 F3 讯飞识别与 DeepSeek 问答模型都进入可用状态
- 上一个 git 检查点：`checkpoint: wire assistant voice model persistence`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 上一轮已归档 checkpoint 摘要

上一轮在进入 checkpoint 前共完成 3 次改动：

### 第 1 次改动
- 时间：`2026-05-09`
- 内容：
  - 保留 F 模块公司投递表的颜色区分
  - 让下拉框恢复原本黑白风
  - 将颜色信息改为侧边色标承载
- 影响文件：
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resume-company-select-wrap|resume-company-select-indicator|syncCompanySelectTheme" webui/config/app-resume.js webui/config/styles.css`
- 测试结果：`通过`

### 第 2 次改动
- 时间：`2026-05-09`
- 内容：
  - F 模块公司投递表补充分页
  - 分页状态接入保存与草稿恢复
  - 公司名称输入框改为字段贴合宽度
  - 表格规则写入私人偏好，并建立第一个统一表格模板
- 影响文件：
  - `webui/config/app-common.js`
  - `webui/config/app-main.js`
  - `webui/config/app-resume.js`
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `docs/extension/global_preferences/components/18_表格与筛选器偏好.md`
  - `docs/templates/TABLE_STAGE1_TEMPLATE.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resumeCompanyPagination|company_table_view|resume-company-name-input|TABLE_STAGE1_TEMPLATE" webui/config/app-resume.js webui/config/index.html webui/config/styles.css webui/config/app-main.js docs/templates/TABLE_STAGE1_TEMPLATE.md`
- 测试结果：`通过`

### 第 3 次改动
- 时间：`2026-05-09`
- 内容：
  - F 模块公司投递表的顶部筛选条支持多项同时展开
  - 多个 `筛` 按钮允许同时保持绿色激活
  - 顶部筛选区改为承载多个筛选块
  - 表头选择入口改为勾选框本体，去掉“全选”文字
  - 顶部筛选条增加结果统计
  - 删除额外的“收起筛选”入口，筛选展开与关闭只通过对应列表头圆点控制
  - 公司名称与链接地址输入框改为默认单行显示
  - 顶部筛选区压缩为更紧凑的工具条样式
  - 删除筛选卡片内重复字段名
  - 收窄公司名称列
  - 将表头勾选框调整为列内真正居中显示
- 影响文件：
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/extension/global_preferences/components/18_表格与筛选器偏好.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg -n "resumeCompanyFilterBar|resume-company-filter-summary|resume-filter-dot.active|resume-company-select-head" webui/config/app-resume.js webui/config.index.html webui/config/styles.css`
- 测试结果：`通过`
- 是否触发 git：`是，已形成 checkpoint`

## 4. 当前 1-3 次改动窗口

### 第 1 次改动
- 时间：`2026-05-11`
- 内容：
  - E 模块 F3 真实接入讯飞 WebSocket 语音识别链路
  - 保留本地 Windows 识别，同时新增“按住录音，松开上传讯飞识别，再回写文本”的真实执行流程
  - 本机 `config.ini` 接入隐藏持久化字段：`xunfei_app_id`、`xunfei_api_key_protected`、`xunfei_api_secret_protected`
  - AHK 侧为讯飞语音识别补充更长的停止等待时间，避免松开 F3 后过早终止
- 影响文件：
  - `scripts/assistant_voice_input.ps1`
  - `src/storage/assistant.ahk`
  - `config.ini`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - PowerShell Parser 校验 `scripts/assistant_voice_input.ps1`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/assistant_voice_input.ps1 -Mode list -DevicesJsonPath <temp>`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restart_main_ahk.ps1`
  - 进程校验：确认仅存在 1 个 `AutoHotkey64.exe` 主实例
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 2 次改动
- 时间：`2026-05-11`
- 内容：
  - E 模块新增 `DeepSeek V4 Pro` 问答模型
  - 按模型自动切换问答 endpoint 到 `https://api.deepseek.com/chat/completions`
  - 为 DeepSeek 增加独立密钥持久化字段，避免覆盖原有豆包问答密钥
  - 文本问答链路补充 `thinking={ type: enabled }` 与 `reasoning_effort=high`
  - 本机 `config.ini` 已写入 DeepSeek 隐藏密钥字段，便于直接切换模型使用
- 影响文件：
  - `webui/config/server_state/assistant.ps1`
  - `webui/config/server_state/config.ps1`
  - `webui/config/app-common.js`
  - `src/storage/assistant.ahk`
  - `src/storage/data_save.ahk`
  - `src/storage/data_load.ahk`
  - `src/config_modes/assistant_mode_actions.ahk`
  - `config.ini`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-common.js`
  - PowerShell Parser 校验 `webui/config/server_state/assistant.ps1`
  - `rg -n "deepseek-v4-pro|api.deepseek.com/chat/completions|deepseek_api_key_protected|GetAssistantRequestApiKey|Get-AssistantEndpointByModel|Get-AssistantModelProvider" webui/config src config.ini -S`
  - 真实 API 冒烟测试：请求 `https://api.deepseek.com/chat/completions`，确认正常返回回答与 `reasoning_content`
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 3 次改动
- 时间：`2026-05-11`
- 内容：
  - E 模块 F3 讯飞语音识别链路继续排障，定位并修复 PowerShell 端的多处阻塞点：`HMACSHA256` 构造兼容、鉴权 URL 拼接、WebSocket 客户端兼容
  - 新增 `scripts/xunfei_asr.py`，将讯飞 WebSocket 握手与上传切换到 Python `websockets` worker，避免当前机器上的 .NET WebSocket 握手异常
  - 为讯飞识别补充更明确的服务端报错透传；当前已能稳定返回真实错误：`{"message":"HMAC signature does not match"}`
  - 额外兼容了本机当前 `xunfei_api_secret` 的 base64 包裹形态，避免直接拿包裹值参与签名
- 影响文件：
  - `scripts/assistant_voice_input.ps1`
  - `scripts/xunfei_asr.py`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - PowerShell 真机回归：`scripts/assistant_voice_input.ps1 -Mode listen -Provider xunfei_websocket_asr`
  - Python WebSocket 直连校验：确认讯飞服务返回真实鉴权响应，而非本地连接异常
  - 当前回归结果：稳定返回 `{"message":"HMAC signature does not match"}`
- 测试结果：`链路已打通到讯飞鉴权层，当前阻塞为凭据签名不匹配`
- 是否触发 git：`是，达到 3/3，需执行 checkpoint`
