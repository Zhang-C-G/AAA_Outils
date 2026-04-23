# UI 与模式（UI and Modes）

## 悬浮窗

- 文件：`src/panel_ui.ahk`
- 目标：输入场景下快速匹配并插入条目
- 默认展示：按使用频率 Top N（受策略控制自动刷新）

## 主配置窗

- 壳层文件：`src/config_ui.ahk`
- Web 壳层：`src/web_config.ahk` + `webui/config/*`（当前默认主入口）
- 子模块-栏目条目层：`src/config_category_items.ahk`
- 子模块-栏目 tab 层：`src/config_category_tabs.ahk`
- 子模块-快捷键/策略层：`src/config_behavior_hotkeys.ahk`
- 子模块-模式页聚合层：`src/config_modes.ahk`
- 子模块-模式页拆分：`src/config_modes/*.ahk`（mode_state/mode_switch/notes/capture/assistant）

## 栏目机制

- 顶部最右 `+`：新增栏目
- 栏目标签双击：内联改名（无弹窗）
- 栏目页右下删除按钮：二级确认后删除
- 支持标签拖拽重排
- 默认栏目 `字段` / `提示词` / `快捷字段` 受保护，不可删除
- `快捷字段` 用于存储“触发词 -> 内容”条目，不用于存储系统热键

## 版本机制

- 标题区按钮：`保存版本` / `恢复版本`
- 保存：写入 `config.snapshot.ini`
- 恢复：回滚到最近一次保存版本

## 模式机制（核心）

- 模式切换不是附加能力，是架构核心
- 当前模式：
- `快捷键面板`：栏目配置 + 快捷键/策略配置
- `笔记面板`：笔记列表、编辑、保存、删除
- `截图发手机`：截图、上传、手机访问链接/二维码
- `截图问答`：全屏截图 + 模型问答 + 结果悬浮窗

## 模式扩展规范

- 新增模式时：
1. 在 `src/config_modes/*.ahk` 新增 `BuildXxxModeBody()` 与 reload/save handler，并在 `config_modes.ahk` 聚合入口挂载
2. 在 `config_ui.ahk` 的 mode 下拉接入新项
3. 在 `src/storage/*.ahk` 增加需要持久化的配置读写
4. 在 `docs/components/*.md` 与 `docs/ACTION_LOG.md` 同步更新

## Web UI 同步机制

- Web 页面通过 `http://127.0.0.1:<port>/api/*` 读写配置。
- 保存后会写入 action 文件（`reload`），AHK 定时监听并执行热加载。
- 热加载会重新读取 `config.ini/usage.ini`，并重注册全局快捷键与刷新策略。

## Web 模式页现状（2026-04-20）

- 快捷键模式：支持栏目拖拽、双击改名、二级删除确认、快捷键/策略校验。
- 笔记模式：支持列表、新建、保存、删除、切换自动保存。
- 截图模式：支持连接状态、保存设置、启动/停止链接、截图、上传、打开手机页。
- 截图问答模式：支持配置 endpoint/key/model/opacity、多模板提示词（新增/删除/重命名/切换）、执行截图问答、显示回答结果。
- 截图问答悬浮窗：支持答案文本滚动热键（默认 `Alt+Up` / `Alt+Down`，可在快捷键配置中改写）。
- 截图问答模式支持本地模拟链路：`endpoint=mock://local` 或 `model=mock-local` 时不调用外部 API。
- 前端已拆分为 `webui/config/app-*.js`，避免单文件膨胀。

## Web 顶部按钮（2026-04-21 更新）

- 按钮顺序：`快捷字段` / `笔记` / `截图发手机` / `截图问答` / `快捷键`
- `快捷字段`：进入主快捷字段页面（左侧栏目条目 + 右侧快捷键配置）
- `快捷键`：进入快捷键专用视图（仅显示快捷键配置区域）
- `快捷键` 按钮在持久化层仍映射到 `shortcuts` 模式，不新增独立后端模式枚举
