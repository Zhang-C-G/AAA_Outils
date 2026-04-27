# 改动流水文档

最近同步：`2026-04-27`  
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。  
满 3 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-04-27-post-checkpoint-api-center-ui-polish`
- 当前连续改动次数：`2`
- 本轮目标：
  - 收掉 E 模块高级设置中的无用 API 输入项
  - 修正 F 模块字段页与公司页内容从中间起排的问题
- 上一个 git 检查点：`checkpoint: api center ui polish and resume layout`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 1-3 次改动窗口

### 第 1 次改动
- 时间：`2026-04-27`
- 内容：
  - 删除 E 模块高级设置中的 `问答模型 API` 与 `语音模型 API` 文案和输入框
  - 删除前端对应的输入监听、回填逻辑
  - 保留保存时沿用后端已有 key 的行为，避免因 UI 删除而误清空历史配置
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/app-assistant.js`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-assistant.js`
  - `rg` 确认前端文件中已不再存在 `assistantApiKey`、`assistantVoiceApiKey`、`问答模型 API`、`语音模型 API`
  - 通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk`
  - 延迟复查后确认当前仅存在 1 个 `AutoHotkey64.exe` 实例
  - `GET http://127.0.0.1:8798/` 返回 HTML，确认页面中已不再包含这两组 API 字段
- 测试结果：`通过`
- 是否触发 git：`否`

### 第 2 次改动
- 时间：`2026-04-27`
- 内容：
  - 修正 F 模块字段页与公司页的内容输入方式
  - 让单行内容也从顶部开始显示，并继续向下扩展
  - 公司页的“公司名称 / 链接地址”改为顶部起排的多行输入区
  - 新增公司、删除公司、编辑公司信息时也纳入自动保存
- 影响文件：
  - `webui/config/app-resume.js`
  - `webui/config/styles.css`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
  - `docs/modules/changelog/F_简历自动填写_修改过程.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg` 确认公司页已改为 `textarea`，并且样式包含 `min-height: 72px` 与顶部对齐设置
  - 通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk`
  - 延迟复查后确认当前仅存在 1 个 `AutoHotkey64.exe` 实例
- 测试结果：`通过`
- 是否触发 git：`否`
### 第3次改动
- 时间：`2026-04-27`
- 内容：
  - E 模块高级设置新增 `悬浮球主色`
  - 使用原生色轮选择颜色，并把十六进制值回填到只读文本框
  - 后端保存链路、AHK 配置默认值、运行时悬浮窗主题色同步接入 `overlay_ball_color`
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/styles.css`
  - `webui/config/app-common.js`
  - `webui/config/app-assistant.js`
  - `webui/config/server_state/assistant.ps1`
  - `webui/config/server_state/config.ps1`
  - `src/storage/data_load.ahk`
  - `src/storage/assistant.ahk`
  - `src/assistant_overlay.ahk`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-assistant.js`
  - PowerShell Parser 校验 `webui/config/server_state/assistant.ps1` 与 `webui/config/server_state/config.ps1`
  - `scripts/restart_main_ahk.ps1`
  - 确认仅存在 `1` 个 `AutoHotkey64.exe`
  - `GET /api/assistant/state` 返回 `overlay_ball_color=#111111`
  - `POST /api/assistant/save-settings` 可成功回写 `overlay_ball_color`
- 测试结果：`通过`
- 是否触发 git：`是（本次达到 3/3）`

### 第4次改动
- 时间：`2026-04-27`
- 内容：
  - 主界面标题栏右侧新增 `设置`
  - 抽出可复用 `theme-picker.js`，支持 4 个预设、纯色/渐变切换、主色/副色色轮
  - App 层新增主题持久化字段，主界面主题可通过 `/api/app/theme` 保存
- 影响文件：
  - `webui/config/index.html`
  - `webui/config/theme-picker.js`
  - `webui/config/app-main.js`
  - `webui/config/app-common.js`
  - `webui/config/styles.css`
  - `webui/config/server.ps1`
  - `webui/config/server_state/config.ps1`
  - `src/storage/data_load.ahk`
  - `src/storage/data_save.ahk`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-main.js`
  - `node --experimental-default-type=module --check webui/config/theme-picker.js`
  - PowerShell Parser 校验 `webui/config/server_state/config.ps1`
  - `scripts/restart_main_ahk.ps1`
  - 确认仅存在 `1` 个 `AutoHotkey64.exe`
  - `GET /api/app/state` 返回主题字段
  - `POST /api/app/theme` 可成功保存并读取主题字段
- 测试结果：`通过`
- 是否触发 git：`已纳入本次 checkpoint`
