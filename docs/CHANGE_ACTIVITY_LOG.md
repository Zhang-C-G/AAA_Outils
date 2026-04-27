# 改动流水文档

最近同步：`2026-04-27`  
状态：`active`

## 1. 文档定位

这份文档只记录“当前这一轮、连续 1-3 次改动”的内容。  
满 3 次并完成 git checkpoint + push 后，更早历史统一交给 git 追溯。

## 2. 当前轮次

- 轮次标识：`2026-04-27-post-checkpoint-api-center-ui-polish`
- 当前连续改动次数：`3`
- 本轮目标：
  - 收掉 E 模块高级设置中的无用 API 输入项
  - 修正 F 模块字段页与公司页内容从顶部开始排布
  - 优化主界面模块加载机制，减少启动阶段的一次性加载
- 上一个 git 检查点：`checkpoint: api center ui polish and resume layout`
- 历史追溯方式：`git log` / 远端提交记录

## 3. 当前 1-3 次改动窗口

### 第1次改动
- 时间：`2026-04-27`
- 内容：
  - 删除 E 模块高级设置中的 `问答模型 API` 与 `语音模型 API` 文案和输入框
  - 删除前端对应的输入监听与回填逻辑
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
  - 延迟复查后确认当前仅存在 `1` 个 `AutoHotkey64.exe` 实例
- 测试结果：`通过`
- 是否触发 git：`否`

### 第2次改动
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
  - `docs/modules/changelog/F_简历自动填充_修改过程.md`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-resume.js`
  - `rg` 确认公司页已改为 `textarea`，并且样式包含 `min-height: 72px` 与顶部对齐设置
  - 通过 `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk`
  - 延迟复查后确认当前仅存在 `1` 个 `AutoHotkey64.exe` 实例
- 测试结果：`通过`
- 是否触发 git：`否`

### 第3次改动
- 时间：`2026-04-27`
- 内容：
  - 将 `webui/config/app-main.js` 从模块静态全量导入改为按模块动态 `import()`
  - 新增模块缓存与“首次进入才初始化 handlers”的机制
  - 保留当前的按模式数据加载逻辑，并让 `notes / notes_display / assistant / resume / testing / api_center` 只在需要时加载代码与绑定事件
  - 让主入口启动时只保留公共能力的静态导入，减少页面首开时的一次性前端初始化压力
- 影响文件：
  - `webui/config/app-main.js`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-main.js`
  - `rg -n "^import " webui/config/app-main.js` 确认主入口只保留 `app-common.js` 静态导入
  - `scripts/restart_main_ahk.ps1`
  - 重启后确认当前仅存在 `1` 个 `AutoHotkey64.exe` 实例
  - `GET http://127.0.0.1:8798/api/app/state` 返回成功，服务链路正常
- 测试结果：`通过`
- 是否触发 git：`是，已达到 3/3 checkpoint 阈值`
