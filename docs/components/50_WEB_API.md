# Web 配置 API（供下一个 AI 快速接手）

## 作用

- Web UI 的所有数据读写通过本地 HTTP API 完成。
- 服务脚本入口：`webui/config/server.ps1`
- 服务模块：`server-common.ps1` / `server-state.ps1` / `server-notes.ps1` / `server-capture.ps1` / `server-assistant.ps1` / `server-resume.ps1`
- `server-state.ps1` 现为聚合入口，内部继续拆分到 `webui/config/server_state/*.ps1`（capture/assistant/config）。
- AHK 桥接：`src/web_config.ahk`

## 基础接口

- `GET /api/ping`：健康检查
- `GET /api/state`：读取快捷键主配置页数据
- `POST /api/save`：保存快捷键主配置页数据
- `POST /api/version/save`：保存版本快照
- `POST /api/version/restore`：恢复版本快照
- `POST /api/app/mode`：切换并持久化当前模式
- 说明：Web 中“快捷键”按钮是快捷键专用视图入口，仍使用 `shortcuts` 持久化模式，不新增后端 mode 枚举

## 笔记接口

- `GET /api/notes/list`：笔记列表（按更新时间倒序）
- `GET /api/notes/get?id=<noteId>`：读取单条笔记
- `POST /api/notes/create`：新建笔记，body: `{ title }`
- `POST /api/notes/save`：保存笔记，body: `{ id, title, content }`
- `POST /api/notes/delete`：删除笔记，body: `{ id }`

## 截图发手机接口

- `GET /api/capture/state`：读取截图模式状态
- `POST /api/capture/save-settings`：保存截图设置
- `POST /api/capture/start-link`：启动连接桥接
- `POST /api/capture/stop-link`：停止连接桥接
- `POST /api/capture/capture-screen`：执行全屏截图
- `POST /api/capture/upload`：上传最新截图
- `POST /api/capture/open-phone`：打开手机连接页
- `POST /api/capture/open-folder`：打开截图目录

## 截图问答接口

- `GET /api/assistant/state`：读取助手配置状态
- `GET /api/assistant/state` 返回 `assistant.model_options`（后端真实可用模型清单），前端“模型选择”下拉框以此渲染
- `POST /api/assistant/save-settings`：保存助手设置（endpoint/key/model/opacity + templates + active_template）
- `save-settings` 对 `model` 做白名单校验：若传入模型不在 `model_options` 中，自动回退默认模型，避免主界面与后端模型不一致
- `POST /api/assistant/capture-ask`：截图并调用模型问答，返回回答文本
- 本地模拟模式：当 `api_endpoint=mock://local` 或 `model=mock-local` 时，`/api/assistant/capture-ask` 返回模拟回答，不调用外部 API。
- `save-settings` 安全规则：明文 key 不回传，后端只持久化 `api_key_protected`
- `capture-ask` 限流规则：按每小时窗口计数，超限返回错误（`assistant_rate_limited`）

## 简历自动填写接口

- `GET /api/resume/state`：读取简历模块状态，返回 `profile + flat_map`
- `POST /api/resume/save`：保存分区式简历 Profile
- `GET /api/resume/profile`：供浏览器插件读取简历 Profile 与平铺键值映射
- `flat_map` 规则：按 `字段名 / 字段 id / 别名` 展开为统一键值表，供插件按启发式规则匹配网页表单
- 当前本地简历资料持久化文件为 `resume_profile.json`

## 前端拆分

- `webui/config/app-common.js`：共享状态、API、通用工具
- `webui/config/app-shortcuts.js`：快捷键模式逻辑
- `webui/config/app-notes.js`：笔记模式逻辑
- `webui/config/app-capture.js`：截图模式逻辑
- `webui/config/app-assistant.js`：截图问答模式逻辑
- `webui/config/app-resume.js`：简历自动填写模式逻辑
- `webui/config/app-main.js`：入口、模式切换、全局事件
- `webui/config/app-main.js` 含快捷键页草稿保护：刷新/离开前写入 session 草稿，重载后自动恢复

## AHK 同步机制

- Web 保存后写入 action 文件：`reload`
- AHK 定时监听 action 文件并执行 `ReloadAppStateFromDisk`
- 热加载后会重注册热键与刷新策略
