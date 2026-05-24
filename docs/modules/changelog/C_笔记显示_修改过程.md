# 模块修改过程记录：C 笔记显示

最近同步：`2026-04-26`
状态：`active`

## 1. 当前状态

- 核心范围：Markdown 预览、目录解析、悬浮窗读取显示
- 当前重点：保持目录与正文联动稳定

## 2. 修改记录

### 2026-05-15 / F4 悬浮窗位置与尺寸持久化加固
- 改动内容：
  - 为 `src/notes_overlay.ahk` 新增窗口位置监听与延迟保存机制
  - 不再只在关闭时保存 F4 悬浮窗位置，而是在用户拖拽或缩放稳定后自动落盘
  - 截图避让、临时隐藏、再次呼出等链路现在都会优先复用最近一次手动调整后的坐标和尺寸
- 测试：
  - 代码链路人工校对：确认 `Size` 回调、可见期轮询、关闭时保存三条路径同时存在
  - 配置链路校对：确认仍写入 `notes_overlay_x / y / w / h`
- 测试结果：`通过`

### 2026-05-12 / C 工作区改为正式继承模板文档
- 改动内容：
  - C 模块不再只写“对标 B”，改为正式引用“列表 + 目录 + 正文工作区”模板文档
  - 在 C 的第一阶段文档中补入模板输入文档、默认继承范围以及与 B 专属扩展层的边界说明
  - 补充左栏列表排序等模板级细节的默认继承口径，减少未来实现时的歧义
- 测试：
  - 文档一致性人工校对
- 测试结果：`通过`

### 2026-05-07 / C 工作区对标 B 的第一轮界面重构
- 改动内容：
  - 将 C 模块页面从“输入框 + 目录预览框”旧结构，改为对标 B 的“列表 / 结构目录 / 正文工作区”
  - 新增左侧内容列表与内嵌新建按钮，保留删除入口
  - 新增 `展开列表 / 收起列表`，并默认持久化记住 C 模块自己的列表状态
  - 中栏改为独立结构目录区，目录不再嵌在预览框里，并补上 `复制目录`
  - 右栏改为同一块正文工作区，并加入 `Markdown / 最终版本` 视图切换
  - 目录点击可根据当前视图联动 `Markdown` 或 `最终版本`
  - C 模块继续使用自己的 `notes_display/*.md` 数据源，不并入 B
- 测试：
  - `node --check --experimental-default-type=module webui/config/app-notes-display.js`
  - `node --check --experimental-default-type=module webui/config/app-common.js`
  - `rg -n "toggleNotesDisplaySidebarBtn|notes_display_sidebar_compact|persistNotesDisplaySidebarCompact|Set-AppNotesDisplaySidebarCompact|/api/app/notes-display-sidebar" webui/config/index.html webui/config/app-common.js webui/config/app-notes-display.js webui/config/server.ps1 webui/config/server_state/config.ps1`
  - `scripts/restart_main_ahk.ps1`
  - 确认当前仅存在 `1` 个 `AutoHotkey64.exe`
- 测试结果：`通过`

### 2026-05-07 / 启动 C 模块工作区重构建档
- 改动内容：
  - 启动 C 模块对标 B 模块的第一阶段工作区重构
  - 先建立本轮重构文档，明确“目录 + 正文工作区 + Markdown / 最终版本”的结构边界
  - 保持 C 模块数据源与展示模块身份独立，不直接并入 B
- 测试：
  - 文档创建校验
- 测试结果：`通过`

### 2026-04-26 / 初始建档
- 改动内容：
  - 建立模块修改过程文档，后续独立记录 C 模块演进
- 测试：
  - 文档创建校验
- 测试结果：`通过`
