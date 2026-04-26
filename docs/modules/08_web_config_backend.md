# 模块 08：Web 配置后端

## 模块目标

- 提供本地 HTTP API，支撑 Web 配置页读写。
- 聚合配置状态、笔记、截图发手机、截图问答四类服务。
- 保证保存链路可追踪、可回滚、可诊断。

## 核心主功能

- 核心是 API 返回真实状态、保存真实落盘、刷新后状态一致。
- 任何性能、日志、结构拆分或附加接口问题，都不能以牺牲真实读写一致性为代价。

## 主要文件

- `webui/config/server.ps1`
- `webui/config/server-common.ps1`
- `webui/config/server-state.ps1`
- `webui/config/server_state/config.ps1`
- `webui/config/server_state/capture.ps1`
- `webui/config/server_state/assistant.ps1`
- `webui/config/server-notes.ps1`
- `webui/config/server-capture.ps1`
- `webui/config/server-assistant.ps1`
- `webui/config/server-testing.ps1`

## 核心接口

- `GET /api/state`
- `POST /api/save`
- `POST /api/app/mode`
- `POST /api/version/save`
- `POST /api/version/restore`
- `POST /api/testing/open-hotkey-probe`
- `POST /api/testing/run-overlay-record-capture`
- `GET /api/assistant/benchmark-state`
- `GET /api/assistant/benchmark-image`
- `POST /api/assistant/benchmark-run`

## 稳定性机制

- `/api/save` 必填校验：`categories/data/hotkeys`。
- 保存前后日志：
  - `config_save_payload`（提交行数）
  - `config_save_result`（落盘行数）
- `Read-BodyJson`：优先 UTF-8 读取请求体，失败后回退 `ContentEncoding`。
- 静态资源禁缓存：`Cache-Control: no-store`。
- `Send-File`：统一处理静态文件/题图输出与禁缓存头。
- 保存失败回滚：`config.ini.autobak`。
- Assistant benchmark：
  - 后端维护固定默认题图
  - 允许测试请求临时覆盖模型
  - 返回分段耗时（内部毫秒），前端按秒展示

## 改动后必查

1. `config.ps1` 与 `server-common.ps1` 语法可解析。
2. `/api/state` 返回 `categories/data/hotkeys`。
3. 保存后日志出现 `payload + result + save` 三连记录。
4. 刷新后数据与落盘一致，不出现“假成功”。
5. 测试接口可正常返回执行结果（包含 `summary` 与 `output`）。
6. Assistant benchmark 接口可正常返回默认题图与分段耗时结果。
