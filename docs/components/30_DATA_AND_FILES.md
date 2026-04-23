# 状态与数据文件（State and Data）

## 全局状态变量（`src/app_state.ahk`）

- `gCategories`：栏目列表（默认 + 自定义）
- `gData`：栏目条目数据 `Map<catId, rows[]>`
- `gUsage`：使用频率 `Map<catId, map<key,count>>`
- `gHotkeys`：快捷键映射
- `gBehavior`：默认展示自动刷新策略
- `gActiveMode`：当前主界面模式（`shortcuts/notes/capture/assistant`）
- `gCaptureSettings`：截图上传配置
- `gAssistantSettings`：截图问答助手配置（含激活模板与模板列表）
- `gCaptureLastPath`：最近截图路径
- `gAssistantRateFile`：助手限流计数文件路径（`assistant_rate.ini`）

## 存储模块拆分（2026-04-20）

- `src/storage.ahk`：存储聚合入口
- `src/storage/data_load.ahk`：配置读取（栏目/热键/策略/模式/截图设置）
- `src/storage/data_save.ahk`：配置写盘与版本快照
- `src/storage/usage.ahk`：usage.ini 读写
- `src/storage/notes.ahk`：笔记文件读写
- `src/storage/capture_file_ops.ahk`：截图、上传、路径与 IP 相关工具
- `src/storage/capture_bridge.ahk`：手机桥接状态与进程控制
- `src/storage/assistant.ahk`：截图问答助手配置与模型请求

## 数据文件

- `config.ini`
- `[Categories]`：栏目定义
- `[Fields]/[Prompts]/[QuickFields]/[Category_<id>]`：栏目条目
- `[Hotkeys]`：快捷键
- `[Hotkeys]` 当前关键项：`toggle_panel/open_config/assistant_capture/assistant_overlay_up/assistant_overlay_down/close_panel/confirm_selection/move_up/move_down`
- `[Behavior]`：自动刷新策略
- `[App]`：`active_mode`
- `[Capture]`：上传端点、桥接端口、二维码开关
- `[Assistant]`：模型端点、密钥、模型名、激活模板、悬浮窗透明度、限流参数
- `[Assistant]` 密钥策略：`api_key` 为空，密钥写入 `api_key_protected`
- `[AssistantTemplates]`：提示词模板（`模板名=提示词`）
- `usage.ini`
- `[Usage_<id>]`：各栏目条目使用次数
- `config.snapshot.ini`
- 最近一次“保存版本”快照
- `notes\*.md`
- 每条笔记独立文件
- `captures\*.png`
- 截图文件
- `action.log`
- 关键动作事件日志
- `assistant_rate.ini`
- 截图问答每小时限流窗口与计数（`[Rate] window/count`）

## 运行时临时文件（自动生成）

- `gWebConfigPidFile`：Web 配置服务进程 PID 文件（位于 `%TEMP%`）
- `gWebConfigActionFile`：Web -> AHK 热加载动作文件（位于 `%TEMP%`）
- `gCaptureBridgePidFile`：手机桥接服务 PID 文件（位于 `%TEMP%`）
- `gCaptureBridgeStatusFile`：手机桥接状态文件（位于 `%TEMP%`）
- `gCaptureBridgeScript`：桥接服务脚本临时文件（位于 `%TEMP%`）

## 数据一致性约定

- 删除条目时同步清理 usage（避免展示脏频率数据）
- 删除栏目时同步删除栏目数据与 usage 分区
- 栏目重命名不改变栏目 id（id 稳定，name 可变）
- 所有写盘动作优先记录日志，便于回溯
