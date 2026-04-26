# 动作记录文档（Action Log）

日志文件：`action.log`

本文件定义软件关键动作日志，便于排障、回溯操作和分析使用习惯。每行一条记录。

## 日志格式

```text
yyyy-MM-dd HH:mm:ss | action_name | detail
```

- `action_name`：动作名称（英文短语）
- `detail`：扁平键值细节，建议 `key=value` 格式

## 与代码对齐状态

- 最近对齐日期：`2026-04-24`
- 对齐方式：扫描 `src/*.ahk` 中全部 `WriteLog(...)` 调用
- 结论：以下清单与当前代码动作名一致

## 当前动作清单（按功能域）

### 启动与面板

- `startup`：脚本启动完成
- `panel_open`：悬浮面板打开
- `panel_close`：悬浮面板关闭
- `selection_confirm`：确认候选项
- `usage_update`：触发词使用次数 +1
- `default_refresh`：默认展示列表自动刷新（来源：`usage` / `timer`）
- `insert_success`：内容插入成功
- `insert_failed`：内容插入失败

### 配置与栏目条目

- `config_open`：配置主界面打开
- `config_add` / `config_add_failed`：新增条目 成功/失败
- `config_update` / `config_update_failed`：更新条目 成功/失败
- `config_delete` / `config_delete_failed`：删除条目 成功/失败
- `config_move` / `config_move_failed` / `config_move_ignored`：条目移动 成功/失败/忽略
- `config_save` / `config_save_failed`：配置保存 成功/失败

### 栏目与版本

- `category_add`：新增栏目
- `category_rename`：栏目改名（内联）
- `category_delete`：栏目删除（二级确认后）
- `category_reorder`：栏目拖拽重排
- `version_save`：保存版本快照
- `version_restore`：恢复最近保存版本

### 快捷键与策略

- `hotkey_register_failed`：动态注册热键失败
- `hotkey_reset_default`：快捷键恢复默认并生效
- `behavior_reset_default`：策略恢复默认并生效

### Web 配置桥接

- `web_config_start`：Web 配置服务启动成功
- `web_config_start_failed`：Web 配置服务启动失败
- `web_config_stop`：Web 配置服务停止
- `web_config_reload`：Web UI 保存后触发 AHK 热加载
- `testing_open_probe`：从 Web 测试页打开按键焦点探针
- `testing_run_overlay_record_capture`：从 Web 测试页执行录屏捕获检测

### 模式与笔记

- `mode_switch`：模式切换（快捷字段/笔记/截图发手机/截图问答/简历自动填写/快捷键）
- `notes_select`：切换当前笔记
- `notes_new`：新建笔记
- `notes_save`：保存当前笔记
- `notes_autosave`：自动保存当前笔记
- `notes_delete`：删除当前笔记

### 截图发手机

- `capture_settings_save`：保存截图上传配置
- `capture_bridge_start` / `capture_bridge_stop`：启动/停止手机连接桥接
- `capture_phone_open`：打开手机连接页
- `capture_create` / `capture_create_failed`：截图成功/失败
- `capture_upload_success` / `capture_upload_failed`：上传成功/失败
- `capture_qr_open`：打开二维码页
- `capture_url_copy`：复制手机访问链接

### 截图问答助手

- `assistant_settings_save`：保存问答助手配置（含激活模板）
- `assistant_capture` / `assistant_capture_failed`：截图问答链路中的截图成功/失败
- `assistant_capture_btn_click`：点击悬浮窗内“截图问答”按钮触发问答
- `assistant_answer_show` / `assistant_answer_failed`：模型回答展示成功/失败
- `assistant_rate_consume` / `assistant_rate_limited`：每小时限流计数消耗 / 命中上限
- `assistant_secret_protect_failed` / `assistant_secret_unprotect_failed`：密钥加解密失败（排障用）

### 简历自动填写

- `resume_profile_save`：保存分区式简历 Profile

## 动作与模块映射（帮助下一个 AI 快速定位）

- 悬浮窗链路：`src/panel_ui.ahk`
- 主配置壳层：`src/config_ui.ahk`
- 栏目条目层：`src/config_category_items.ahk`
- 栏目 tab 与版本层：`src/config_category_tabs.ahk`、`src/config_tabs/*.ahk`
- 模式页：`src/config_modes.ahk`、`src/config_modes/*.ahk`
- Web 配置桥接：`src/web_config.ahk`、`webui/config/server*.ps1`、`webui/config/server_state/*.ps1`
- 存储层：`src/storage.ahk`、`src/storage/*.ahk`
- 截图问答悬浮窗：`src/assistant_overlay.ahk`
- 快捷键与策略：`src/config_behavior_hotkeys.ahk`、`src/hotkeys.ahk`、`src/strategy.ahk`
- 启动流程：`src/app_state.ahk`
- 日志函数定义：`src/helpers.ahk` (`WriteLog`)

## 最近维护记录

- `2026-04-20`：执行动作名对齐检查，确认文档清单与代码一致。
- `2026-04-20`：组件文档拆分为 `docs/components/*.md`，减少单文件膨胀，便于分域维护。
- `2026-04-20`：Web UI 升级为三模式（快捷键/笔记/截图），新增 `webui/config/server.ps1` 与前端多文件模块拆分。
- `2026-04-20`：Web 服务继续拆分为 `server-common/state/notes/capture` 四个模块，降低单文件复杂度。
- `2026-04-20`：`src/storage.ahk` 拆分为 6 个子模块（data_load/data_save/usage/notes/capture_file_ops/capture_bridge），并保留聚合入口，减少单文件体积。
- `2026-04-20`：`src/config_modes.ahk` 拆分为 8 个子模块（mode_state/mode_switch/notes_mode_ui/notes_mode_actions/capture_mode_ui/capture_mode_actions/assistant_mode_ui/assistant_mode_actions），并保留聚合入口，减少单文件体积。
- `2026-04-20`：文档全量对齐更新（README、组件索引、数据文件、样式 token），确保代码拆分结构与文档一致。
- `2026-04-20`：新增第 4 模块“截图问答助手”（热键触发截图 + API 问答 + 可调透明度悬浮窗）并同步 Web API 与文档。
- `2026-04-21`：截图问答助手升级为多提示词模板持久化（`[AssistantTemplates]` + `active_template`），并同步 Web API 与组件文档。
- `2026-04-21`：新增截图问答本地模拟测试模式（`mock://local` / `mock-local`）与悬浮窗答案滚动热键（`assistant_overlay_up/down`）。
- `2026-04-21`：补充文件体量审计文档 `docs/components/60_SIZE_AUDIT.md`，并更新扩展拆分优先级。
- `2026-04-21`：完成两处结构拆分：`src/config_category_tabs.ahk` -> `src/config_tabs/*.ahk`，`webui/config/server-state.ps1` -> `webui/config/server_state/*.ps1`。
- `2026-04-21`：截图问答新增“密钥加密存储 + 每小时限流”，文档补齐对应动作名。
- `2026-04-21`：Web 顶部模式按钮拆分为“快捷字段”与“快捷键”双入口；快捷键入口为专用视图入口（不与字段条目混淆）。
- `2026-04-21`：新增模块化文档目录 `docs/modules/`，按小功能拆分独立维护文档（热键悬浮窗、快捷字段、快捷键、笔记、截图发手机、截图问答、Web 前后端、存储、运行态）。
- `2026-04-21`：新增文档更新执行清单 `docs/UPDATE_CHECKLIST.md`，统一“每次改代码后必须更新文档”的流程。
- `2026-04-21`：文档体系升级为三层：Domain/Module/Shared；新增 `docs/DOC_SYSTEM.md`、`docs/shared/*.md`、`docs/templates/MODULE_TEMPLATE.md`，明确“全局快捷键”为公用块。
- `2026-04-21`：修复 Web 配置保存“部分载荷误清空”问题：`server_state/config.ps1` 改为合并写盘，未提交栏目/热键保留原值，并增加空覆盖保护，避免刷新后栏目条目整体消失。
- `2026-04-21`：增强内置字段保护：`fields/prompts` 在读取与写入阶段增加默认回填兜底，避免异常空保存后主界面字段全部消失。
- `2026-04-21`：修正保存策略过度保护导致“增删不生效”：`server_state/config.ps1` 恢复为“提交即写入”，仅在未提交某栏目时保留旧值；删除栏目与清空条目可正确持久化。
- `2026-04-21`：针对“字段/快捷字段加载丢失”建立临时故障档案 `docs/incidents/TEMP_field_loading_incident.md`，按轮次记录排障结论，待用户确认修复后再删除。
- `2026-04-21`：修复 Web 前端脚本中断问题：重写 `webui/config/app-common.js`（损坏字符串导致解析失败）并修复 `webui/config/app-shortcuts.js` 热键模板渲染语法错误。
- `2026-04-21`：修复 AHK 读取映射不一致：`src/storage/data_load.ahk` 将 `quick_fields` 对齐到 `QuickFields` section，并补齐内置分类与默认结构，避免读取为空。
- `2026-04-21`：修复 Web 保存“假成功”风险：`Read-BodyJson` 改为 JSON 解析失败直接报错；`/api/save` 增加 `categories/data/hotkeys` 必填校验与 payload 行数日志。
- `2026-04-21`：修复静态资源缓存导致旧脚本持续生效：`Serve-Static` 增加 no-store/no-cache 响应头。
- `2026-04-21`：降低 AHK 覆盖 Web 保存竞态风险：`SaveData()` 前先处理 pending 的 web reload action。
- `2026-04-21`：补充保存诊断：`config_save_payload` 记录前端提交行数，`config_save_result` 记录最终落盘行数；用于快速判断“未提交/未写入/被覆盖”。
- `2026-04-21`：排障确认 `8798` 旧进程问题并执行进程重启，确保运行版本与源码一致。
- `2026-04-21`：按体验调整 Web 快捷字段页：去除 `Ctrl+S` 保存提示/监听，改为自动保存；栏目删除改为单次确认。
- `2026-04-21`：增强 `/api/save` 请求体解码：优先 UTF-8 原始字节解析，回退 `ContentEncoding`，减少乱码导致的 JSON 解析异常。
- `2026-04-21`：优化快捷键页布局占用：移除窄面板宽度限制，快捷键组与组内字段改为自适应多列，充分利用右侧区域。
- `2026-04-21`：故障收口：将 `docs/incidents/TEMP_field_loading_incident.md` 关闭并移除，新增 `docs/incidents/RESOLVED_2026-04-21_field_loading.md` 作为归档记录。
- `2026-04-21`：文档可读性修复：重写乱码模块文档（模块 02/03/08 与更新清单），并同步 README 最新交互（自动保存、单次确认、快捷键页全宽）。
- `2026-04-21`：截图问答默认提示词修复：统一默认模板为 `default_template`，并在前端/AHK/后端三处增加“问号坏值自动回填默认提示词”逻辑。
- `2026-04-21`：截图问答链路测试：`scripts/test_assistant_mock.ps1` 通过；真实接口调用出现 `assistant_capture` 与 `assistant_answer_show` 日志，确认模型调用链路可触发。
- `2026-04-21`：截图问答实测补充：`/api/assistant/save-settings` 提交 `???` 会被自动回填默认提示词；`/api/assistant/capture-ask` 真实请求返回 `ok=true` 且生成截图文件。
- `2026-04-22`：按交互调整截图问答 Web 页：移除“回答结果”展示框（`assistantAnswer`），页面仅保留配置与触发入口，回答统一走悬浮弹出窗。
- `2026-04-22`：修复 AHK 启动报错 `Missing """"`：`src/storage/assistant.ahk` 的 `BuildAssistantMockAnswer` 字符串因编码污染导致引号缺失，已重写为稳定文本拼接。
- `2026-04-22`：修复 AHK 启动 `Syntax error`：`src/storage/assistant.ahk` 限流错误文案字符串损坏，已改为标准拼接 `"已达到每小时调用上限（" limit " 次）。"`。
- `2026-04-22`：截图问答热键升级：`Alt+Shift+A` 改为“启动问答悬浮窗”，新增 `F1` 为“截图并问答”；Web Assistant 新增“启动悬浮窗”按钮与 `/api/assistant/show-overlay`、`/api/assistant/trigger-capture` 接口。
- `2026-04-22`：问答悬浮窗启用系统级防截屏标记（`SetWindowDisplayAffinity`：`WDA_EXCLUDEFROMCAPTURE`，失败回退 `WDA_MONITOR`），并新增对应动作日志用于兼容性排查。
- `2026-04-22`：新增快捷字段示例 `更新`（文档同步 + 大文件拆分目标），写入 `[QuickFields]` 并补充到默认初始化模板。
- `2026-04-23`：按交互回退悬浮面板数字秒插能力：移除 `1-9` / `Numpad1-9` 候选直插，仅保留 `↑/↓` 选中与 `Enter` 确认插入。
- `2026-04-22`：截图问答悬浮窗展示优化：开启自动换行，新增代码段换行格式整理，减少“一行到底”显示问题。
- `2026-04-22`：修复 `src/assistant_overlay.ahk` 的 `Missing """"`：代码块格式化正则中的三连反引号导致字符串转义冲突，改为 `fence := Chr(96) Chr(96) Chr(96)` 拼接写法。
- `2026-04-22`：截图问答悬浮窗透明度修复：滑杆按百分比映射到实际 alpha，100% 改为 `WinSetTransparent("Off")`，避免“100% 仍半透明”。
- `2026-04-22`：截图问答过程状态可视化：新增状态栏，显示“正在截图 / 截图成功 / 正在思考（已思考X秒）/ 回答完成或失败”；模型请求阶段改为可轮询进度回调。
- `2026-04-22`：按交互要求移除问答悬浮窗中的两行说明文字（防截屏说明、Alt+Up/Down 说明），改为仅保留状态栏与答案区。
- `2026-04-22`：Assistant Web 页移除“本地模拟测试”按钮及前端触发逻辑；新增只读“快捷键说明”行，动态显示真实配置中的问答快捷键。
- `2026-04-22`：Assistant Web 配置持久化增强：模板新增/删除/重命名/提示词修改与限流参数（开关、每小时次数等）改为自动保存到本地（防止刷新后丢失）。
- `2026-04-22`：修复截图问答链路 `Invalid base` 防崩：`StartAssistantCaptureFlow` 对回答结果增加 `try/catch + IsObject` 兜底，避免 `res["path"]` 在异常返回时导致脚本中断。
- `2026-04-22`：增强防截图黑块处理：问答悬浮窗可见时拦截 `PrintScreen / Win+Shift+S / Ctrl+Alt+A`，执行“临时隐藏后转发截图热键”；同时调整 `F1` 内部截图隐藏/恢复时机，降低黑块残留概率。
- `2026-04-22`：防截图链路加固：问答进入“思考/传输”阶段时强制隐藏悬浮窗；显示阶段增加截图风险轮询（按键/进程命中即隐藏，解除后恢复）；并移除 `WDA_MONITOR` 回退，仅保留 `WDA_EXCLUDEFROMCAPTURE`，避免黑块占位。
- `2026-04-22`：修复“思考秒数始终为 0”体验问题：截图问答增加本地读秒定时器（每秒刷新状态），不再依赖后端回调与 PID 轮询精度。
- `2026-04-22`：稳定性修正：取消“思考阶段强制隐藏悬浮窗”，改为仅在截图瞬间与真实截图风险触发时临时隐藏；同时收紧风险检测（去除进程常驻误判），避免 `F1` 后悬浮窗长期消失。
- `2026-04-22`：问答悬浮窗“原位更新”修复：`F1` 流程移除内部 `Hide/Show`，改为同一窗口内更新状态与答案；`ShowAssistantOverlay` 改为仅首次定位，后续显示保留用户拖拽位置，避免回答后窗口跳位。
- `2026-04-22`：防黑块与稳定性折中优化：默认关闭 `WDA`（避免黑色占位块）；`F1` 改为“截图瞬间短隐藏 + 原位恢复”；截图风险轮询在思考阶段同样生效，确保外部截图触发时也能临时隐藏并恢复。
- `2026-04-22`：新增录屏防护：风险检测引擎增加常见录屏器（OBS/Bandicam/Camtasia/Snagit/Game Bar/ShareX/ffmpeg 等）进程与窗口识别；命中时自动临时隐藏问答悬浮窗，解除后原位恢复。
- `2026-04-22`：策略升级为“可见且不可录/不可截”优先：默认启用 `WDA_EXCLUDEFROMCAPTURE` 并记录激活状态；当 `WDA` 生效时不再执行临时隐藏（保持悬浮窗可见），仅在 `WDA` 失效时回退到截图/录屏风险隐藏策略。
- `2026-04-22`：文档整治：重写乱码文档（模块索引/运行态/共享契约/模板/总图）并与当前实现对齐（原位更新、防截图、防录屏、WDA 优先回退策略）。
- `2026-04-22`：文档口径澄清：业务模块固定为 5 个（快捷字段/笔记/截图发手机/截图问答/简历自动填写）；全局快捷键归类 Shared 公用能力，不计入业务模块数量。
- `2026-04-22`：截图问答限额调整：默认 `rate_limit_per_hour` 从 30 提升为 100，并同步更新当前 `config.ini` 生效值。
- `2026-04-23`：截图问答模型扩展：新增 `doubao-seed-2-0-pro-260215`，并将主界面模型输入改为后端驱动下拉选择（`assistant.model_options`）。
- `2026-04-23`：模型一致性加固：后端保存路径对模型做白名单校验，非法模型自动回退默认 `doubao-seed-2-0-lite-260215`，避免“前端显示可选但后端不可用”。
- `2026-04-23`：截图问答状态链路升级：悬浮窗状态栏新增“模型名 + 阶段态”展示（准备截图/正在截图/截图完毕/正在分析(秒)/回答完成或失败）。
- `2026-04-23`：截图问答新增“禁止复制悬浮窗答案”开关（主界面 Assistant 栏目），默认开启；运行时拦截悬浮窗文本复制消息。
- `2026-04-23`：截图问答回答区交互收敛：鼠标划入回答区不再变为文本光标，点击/双击不再选中文字（保持纯展示态）。
- `2026-04-23`：截图问答悬浮窗精简：删除底部“复制”与“关闭”按钮，回答区高度扩展到底部。
- `2026-04-23`：截图问答悬浮窗改为 NoActivate 展示（`WS_EX_NOACTIVATE` + `Show NA`），点击悬浮窗不再抢焦点、避免被判定为切后台。
- `2026-04-23`：新增浏览器侧探针测试工具（`scripts/hotkey_focus_probe.html` + `scripts/run_hotkey_focus_probe.ps1`），用于实测焦点切换与 F1/F2 事件可见性。
- `2026-04-23`：测试工具文档化：新增 `docs/testing/HOTKEY_FOCUS_PROBE.md`，沉淀探针用途、运行方式、判定标准与维护约定。
- `2026-04-23`：防黑块策略回调：`gAssistantOverlayAffinityEnabled` 默认改为 `false`，优先“风险触发临时隐藏”以避免第三方截图/录屏出现黑色块。
- `2026-04-23`：新增录屏捕获检测脚本 `scripts/test_overlay_record_capture.ps1`，通过可见帧/隐藏帧差异对比给出 PASS/WARN/FAIL。
- `2026-04-23`：按用户回退到更严格防录屏方案：`gAssistantOverlayAffinityEnabled` 默认恢复为 `true`，并在分析阶段启用强制隐藏/完成后恢复（`assistant_overlay_sensitive_hide/restore`）。
- `2026-04-23`：软件命名更新：主程序/主界面/自启动快捷方式统一为 `ZCG-Raccourci Control`。
- `2026-04-23`：主界面新增“测试”栏目入口（位于最右侧），接入测试页并连通探针/录屏检测后端接口。
- `2026-04-23`：截图问答 Web 页改为“基础设置/高级设置”分层布局；高级设置默认隐藏，降低新手使用门槛。
- `2026-04-23`：截图问答“快捷键说明（自动同步配置）”框样式升级为统一斜线背景（低对比强调）；说明文案归档为固定句式并动态替换真实热键值。
- `2026-04-23`：Web UI 全局滚动条改为隐藏显示（保留滚动能力），统一各栏目切换时的视觉表现。
- `2026-04-23`：快捷字段页移除“自动刷新策略”可视配置（策略转为系统内部保存），并改为单栏全宽编辑布局。
- `2026-04-23`：主界面右上角按钮（恢复版本/保存版本/刷新/保存）全部移除；前端绑定改为按钮存在时才注册，避免空节点报错。
- `2026-04-23`：截图问答防捕捉链路加固为“双保险”：WDA 持续重试 + 风险触发强制隐藏（即使 WDA 已启用也执行），并扩展录屏/共享进程与窗口关键词识别。
- `2026-04-23`：截图问答悬浮窗透明度滑条移除鼠标悬浮/拖动数字气泡提示（禁用 slider tooltip）。
- `2026-04-23`：版本验收归档：当前版本悬浮窗安全功能已完成并作为稳定基线提交。
- `2026-04-23`：按最终需求修正 F1 分析阶段可见性：WDA 生效时 `EnterAssistantSensitivePhase` 不再隐藏悬浮窗（录屏期间保持可见）。
- `2026-04-23`：截图问答悬浮窗新增“截图问答”按钮（无需快捷键），点击与 F1 共用同一安全链路并记录 `assistant_capture_btn_click`。
- `2026-04-24`：根据日志排查发现“WDA 成功即跳过风险隐藏”导致回归；已恢复为安全优先基线，录屏/截图风险检测命中时即使 WDA 生效也要隐藏悬浮窗。
- `2026-04-24`：截图问答悬浮窗防漂移加固：保护轮询从“盲目重复调用 `SetWindowDisplayAffinity`”改为“先读 `GetWindowDisplayAffinity` 再按需重建”，并新增 `assistant_overlay_protect_rearm` / `affinity_drift_*` 日志用于定位切屏后保护态丢失。
- `2026-04-24`：截图问答回答区从 `Edit` 控件收敛为轻量只读文本渲染，保留 `Alt+Up / Alt+Down` 滚动，降低 `WDA + 子编辑控件 + 切屏/DWM 变化` 组合导致录屏出现黑块的概率。
- `2026-04-24`：截图问答录屏口径回调：录屏期间悬浮窗对本地用户保持可见，不再因为录屏进程或分析阶段自动隐藏；自动隐藏仅保留给真实截图动作。
- `2026-04-24`：截图问答 Web 页重排：快捷键说明移至顶部，基础设置承载模板管理，高级设置改为开关式显隐，关闭时整块隐藏。
- `2026-04-24`：截图问答透明度改为四档离散值（`0 / 50 / 75 / 100`），Web 与悬浮窗统一为点击切换，不再使用自由拖动滑杆。
- `2026-04-24`：截图问答悬浮窗细节收敛：移除“回答区”提示字样，继续增强长文本与代码块换行整理。
- `2026-04-24`：简历自动填写主 UI 收敛：前端表格仅保留“字段名 / 值 / 操作”，移除别名、类型、复制 JSON 与 Profile 预览；别名与类型默认由后端字段表维护。
- `2026-04-24`：截图问答保存目录改为可配置：主界面新增“修改目录”，并同步落盘到 `[App].capture_dir` 与运行时状态。
- `2026-04-24`：截图问答悬浮窗显示链路收敛：移出任务栏/常规切换列表，首次显示先重绘再挂保护，降低按钮区黑块与透明度切换闪烁。
- `2026-04-24`：截图问答透明度口径更新为 `20 / 50 / 75 / 100`，且透明度仅允许在主界面修改，悬浮窗内不再提供修改入口。
- `2026-04-24`：简历自动填写继续收敛界面信息密度：移除左侧与右侧分区说明小字，仅保留分区标题与字段编辑表。
- `2026-04-23`：新增 AI 交接总文档 `docs/AI_HANDOFF.md`，并将其纳入组件总览与文档更新清单，要求后续改动同步维护当前状态、优先级与风险。
- `2026-04-23`：补充文档治理提醒：明确 AHK 开发态默认启用源码自动热重载，要求后续 AI 在交接与排障时显式考虑该行为。
- `2026-04-23`：简历自动填写推进为第一版可用模块：新增 `resume_profile.json` 本地简历存储、`server-resume.ps1` 接口、Web 分区式编辑页，以及浏览器插件骨架 `browser_extension/resume_autofill/`。
- `2026-04-26`：恢复助手麦克风链路：重新接回设备检测/设备选择/实时转写预览提交，并修正 `Get-AssistantVoiceInputScriptPath` 路径解析与 `/api/assistant/audio-input-devices` 数组返回格式。
- `2026-04-26`：按现有故障文档机制归档麦克风链路问题，新增 `docs/incidents/RESOLVED_2026-04-26_assistant_microphone_chain.md`。
- `2026-04-26`：补齐文档创建指南体系：新增第一阶段文档、第二阶段能力说明、故障文档模板，并新增 `docs/extension/DOC_CREATION_GUIDE.md` 作为统一入口。

## 维护约定

- 新增关键行为时，必须同步补充本文件动作清单。
- `detail` 必须保持单行扁平结构，避免多行长文本。
- 不记录敏感凭据（密码、完整 token、私密密钥）。



- `2026-04-21`: Documentation governance upgrade completed (ADR/config/dependency/extension/testing/glossary/encoding policy + doc changelog).

