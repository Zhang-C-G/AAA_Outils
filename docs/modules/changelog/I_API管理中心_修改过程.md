# 模块修改过程记录：I API管理中心

最近同步：`2026-04-26`  
状态：`active`

## 1. 当前状态

- 核心范围：统一展示项目已接入 API、本地接入信息、官方管理中心入口
- 当前重点：完成第一阶段 UI 壳并验证模式接入链路

## 2. 修改记录

### 2026-05-15 / 讯飞配置状态恢复
- 改动内容：
  - 排查确认 I 模块一直显示“未配置”的直接原因，是本地 `config.ini` 中 `xunfei_app_id / xunfei_api_key_protected / xunfei_api_secret_protected` 之前已被清空
  - 根据用户提供的讯飞 WebSocket 凭据，重新补齐本机 `xunfei_app_id`
  - 重新写入本机 `xunfei_api_key_protected / xunfei_api_secret_protected`，继续沿用现有受保护存储格式，不改成明文持久化
  - 通过后端现有读取链路复核：`xunfei_app_id=3e01888e`、`has_xunfei_api_key=1`、`has_xunfei_api_secret=1`、`voice_model=xunfei_websocket_asr`
- 影响文件：
  - `config.ini`
  - `docs/modules/changelog/I_API管理中心_修改过程.md`
  - `docs/modules/changelog/E_截图问答_修改过程.md`
  - `docs/ACTION_LOG.md`
  - `docs/DOC_CHANGELOG.md`
  - `docs/CHANGE_ACTIVITY_LOG.md`
  - `docs/CHANGE_CHECKPOINT_RULE.md`
- 测试：
  - 本地配置核对：确认 `config.ini` 中讯飞三件套已存在
  - PowerShell 读回校验：确认后端返回 `xunfei_app_id=3e01888e`、`has_xunfei_api_key=1`、`has_xunfei_api_secret=1`
- 测试结果：`通过`

### 2026-04-26 / 第一阶段建模
- 改动内容：
  - 新增 `I API管理中心` 模式入口
  - 接入第一阶段页面结构：说明条、摘要卡、API 表格、刷新按钮
  - 基于 `E截图问答` 与 `D截图发手机` 的本地配置推导 API 行
  - 为问答 API、语音 API、截图上传 API 增加官方入口占位
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-main.js`
  - `node --experimental-default-type=module --check webui/config/app-common.js`
  - `node --experimental-default-type=module --check webui/config/app-api-center.js`
  - `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk`
  - 确认仅存在 1 个 `AutoHotkey64.exe` 实例
  - `GET /api/ping` 返回正常
  - `GET /api/app/state` 确认 `mode_order` 含 `api_center`
  - `POST /api/app/mode` 验证 `active_mode` 可切换到 `api_center` 并恢复
- 测试结果：`通过`

### 2026-04-27 / 标题命名修正
- 改动内容：
  - API管理中心页面顶部补齐明确标题 `API管理中心`
  - 原先孤立显示的表头 `API` 改为 `接入项目`
  - 避免用户进入页面时误以为模块名仅为 `API`
- 测试：
  - `rg` 检查 `API管理中心`、`接入项目`、`api-center-title` 已写入页面与样式
  - `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk`
  - 确认仅存在 1 个 `AutoHotkey64.exe` 实例
  - `GET http://127.0.0.1:8798/` 返回 HTML，确认包含 `API管理中心` 与 `接入项目`
- 测试结果：`通过`

### 2026-04-27 / API 列表结构修正
- 改动内容：
  - 表头从 `接入项目` 改回 `API`
  - API 列表调整为 3 个豆包 API 与 1 个讯飞 API
  - 删除截图上传 API 行
  - `当前接入` 改为隐藏 API Key，已配置时显示星号掩码
  - 豆包管理中心改为火山引擎指定入口
  - 讯飞管理中心改为 `https://console.xfyun.cn/services/bmc`
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-api-center.js`
  - `rg` 校验表头、掩码 key、火山引擎入口、讯飞入口已写入
  - `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk`
  - 确认仅存在 1 个 `AutoHotkey64.exe` 实例
  - `GET /` 返回 HTML，确认包含 `API管理中心` 与 `<th>API</th>`
  - `GET /api/assistant/state` 返回正常，确认存在 3 个豆包模型选项
- 测试结果：`通过`

### 2026-04-27 / 第一阶段 UI 微调
- 改动内容：
  - `当前接入` 列改为“密钥状态”表达：未配置时显示 `未配置`
  - API 行新增平台归属标签：`豆包 / 火山引擎`、`讯飞`
  - 官方管理中心列改为统一操作按钮样式，文案统一为 `进入控制台`
  - 摘要区调整为：`已登记 API`、`已配置密钥数`、`官方读取状态`
  - 说明条与副标题收紧，整体更贴近管理中心气质
- 测试：
  - `node --experimental-default-type=module --check webui/config/app-api-center.js`
  - `rg` 校验 `未配置`、平台标签、按钮样式、`apiCenterConfiguredCount`、`官方读取状态` 已接入
  - `scripts/restart_main_ahk.ps1` 重启原有 `main.ahk`
  - 延迟复查后确认当前仅存在 1 个 `AutoHotkey64.exe` 实例
- 测试结果：`通过`
