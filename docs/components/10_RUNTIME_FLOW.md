# 运行链路（Runtime Flow）

## 启动入口

- 文件：`main.ahk`
- 角色：仅负责按顺序 `#Include` 模块，并调用 `Init()`。

## Init() 启动顺序

1. 初始化主题与热键定义：`InitTheme()` / `InitHotkeyDefs()`
2. 确保数据文件存在：`EnsureDataFile()` / `EnsureUsageFile()`
3. 读取栏目与条目：`LoadCategories()` / `LoadDataByCategories()`
4. 读取使用频率、热键、策略：`LoadUsageCounts()` / `LoadHotkeys()` / `LoadBehavior()`
5. 构建 UI：`BuildPanelGui()` / `BuildConfigGui()`
6. 注册热键：`RegisterHotkeys()`
7. 启动自动刷新：`RestartAutoRefreshTimer()`
8. 记录启动日志：`WriteLog("startup", "script initialized")`

## 存储层组织（2026-04-20）

- `src/storage.ahk` 仅做聚合 include。
- 具体读写分布在 `src/storage/*.ahk`（data_load/data_save/usage/notes/capture_file_ops/capture_bridge/assistant）。

## 模式层组织（2026-04-20）

- `src/config_modes.ahk` 仅做聚合 include。
- 模式逻辑分布在 `src/config_modes/*.ahk`（mode_state/mode_switch/notes/capture/assistant）。

## 运行时关键链路

### 悬浮窗链路

- 呼出：全局热键 -> `ShowPanelAtCursor()`
- 输入：编辑框变化 -> `UpdateResults()`
- 确认：回车/点击 -> `ConfirmSelection()`
- 执行：插入内容 + usage 计数 + `default_refresh`

### 配置窗链路

- 打开：`ShowConfigWindow()`
- Web 入口优先：`ShowWebConfigWindow()` -> 启动 `webui/config/server.ps1` -> 浏览器打开本地页面
- AHK 配置窗回退：当 Web 入口不可用时，继续使用 AHK 本地配置窗
- 编辑：栏目 tab / 条目表格 / 快捷键策略 / 模式页
- 保存：`SaveData()` + `SaveHotkeys()` + `SaveBehavior()` +（模式相关配置）
- 生效：重注册热键 + 重启自动刷新

### 模式切换链路

- 入口：配置窗标题右侧 mode 下拉
- 切换：`OnConfigModeChanged()` -> 重建模式体区域
- 持久化：`[App] active_mode` 写入 `config.ini`

### 截图问答链路（新增）

- 触发：全局热键 `Alt+Shift+A`（默认）
- 执行：`StartAssistantCaptureFlow()` -> `CaptureFullScreen()` -> `RequestAssistantAnswerFromImage()`（按当前激活提示词模板）
- 展示：`ShowAssistantOverlay()`（可调透明度）
- 悬浮窗滚动：`assistant_overlay_up` / `assistant_overlay_down`（默认 `Alt+Up` / `Alt+Down`）
- 本地模拟：`api_endpoint=mock://local` 或 `model=mock-local` 时，不调用外部 API，返回本地模拟答案

### 简历自动填写链路（新增）

- 编辑：Web 配置页 `resumeView` -> `app-resume.js`
- 保存：`POST /api/resume/save` -> `webui/config/server-resume.ps1`
- 持久化：`resume_profile.json`
- 插件读取：浏览器插件请求 `GET /api/resume/profile`
- 自动填写：内容脚本根据 `字段名 / 别名 / name / placeholder / label` 做启发式匹配并回填输入框

## 排障建议

- 快捷键失效优先检查：`[Hotkeys]` 内容与 `WriteLog("hotkey_register_failed", ...)`
- 模式打不开优先检查：`[App] active_mode` 是否为可用值（`shortcuts/notes/capture/assistant`）
- 截图异常优先检查：`captures\` 目录写权限、上传端点配置、桥接端口占用
- 问答异常优先检查：`[Assistant]` 下 `api_endpoint/api_key/model/active_template` 与 `[AssistantTemplates]` 是否正确、网络是否可访问 API
- 本地链路回归可执行：`scripts/test_assistant_mock.ps1`
