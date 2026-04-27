# 模块修改过程记录：I API管理中心

最近同步：`2026-04-26`  
状态：`active`

## 1. 当前状态

- 核心范围：统一展示项目已接入 API、本地接入信息、官方管理中心入口
- 当前重点：完成第一阶段 UI 壳并验证模式接入链路

## 2. 修改记录

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
