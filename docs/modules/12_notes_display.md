# 模块 12：笔记显示

## 模块目标

- 通过独立快捷键 `F4` 呼出“笔记显示悬浮窗”。
- 左侧显示根据 Markdown 标题生成的目录，右侧显示正文内容。
- 在不牺牲保护能力的前提下，为本地用户提供可见的笔记悬浮展示。

## 核心主功能

- 核心是“笔记显示”作为独立模块存在，不与“笔记”模块混为同一个模块。
- 本模块负责悬浮展示、目录生成、截图避让、录屏保护。
- 本模块当前拥有自己的内容编辑与保存区，悬浮窗只读取本模块自己的数据源。
- 任何 UI 微调、说明文本、交互优化，都不能以牺牲悬浮展示与保护主链路为代价。

## 与笔记模块的关系

- `04_notes.md` 负责编辑、保存、删除、自动保存。
- 本模块负责自己的内容编辑、悬浮展示与保护。
- 两者现在不再共享同一套笔记文件；模块身份、数据源、验证项都独立维护。

## 主要文件

- `src/notes_overlay.ahk`
- `src/hotkeys.ahk`
- `webui/config/index.html`
- `webui/config/app-main.js`
- `webui/config/app-common.js`
- `webui/config/server-common.ps1`

## 结构约束

- 本模块必须保持“展示模块”定位，禁止把笔记编辑、保存、删除逻辑继续塞回本模块。
- 本模块只允许读取 `notes/*.md` 作为展示数据源；写入动作仍归 `04_notes.md` 模块负责。
- AHK 侧以 `src/notes_overlay.ahk` 为主入口；若该文件继续增长，优先拆成：
  - 渲染/目录解析
  - 悬浮窗显示与滚动
  - 保护与临时隐藏
- Web 侧禁止把“笔记显示”逻辑长期堆在 `webui/config/app-main.js` 中；若继续增加交互，需拆出独立文件，例如 `webui/config/app-notes-display.js`。
- 热键定义只保留注册与映射，不能在 `src/hotkeys.ahk` 中堆业务细节。
- 公共配置项仅在 `app-common.js` / `server-common.ps1` 中登记，不在其他文件重复声明。

## 文件体量警戒线

- `src/notes_overlay.ahk` 超过 `450` 行时，必须拆分子文件，避免保护逻辑、解析逻辑、GUI 逻辑缠在一起。
- `webui/config/app-main.js` 不应继续承接笔记显示的新业务；当前已经偏重，后续新增功能应拆出独立模块文件。
- `webui/config/index.html` 中“笔记显示”区域只保留模块入口与状态展示，复杂交互不要继续直接堆模板。

## 数据来源

- `notes_display/*.md`

## 关键动作日志

- `notes_overlay_open`
- `notes_overlay_close`
- `notes_overlay_protect_on`
- `notes_overlay_protect_off`
- `notes_overlay_temp_hide`
- `notes_overlay_temp_restore`

## 改动后必查

1. `F4` 可正常呼出/关闭笔记显示悬浮窗。
2. 悬浮窗左侧目录可根据 Markdown 标题生成。
3. 点击目录后，右侧正文能跳到对应位置。
4. Web 主界面中的“笔记显示”页签可以独立新建、编辑、保存、删除自己的内容。
5. 悬浮窗读取的是 `notes_display/*.md`，不是 `notes/*.md`。
6. 截图时笔记显示悬浮窗会避让，不出现在截图结果里。
7. 录屏结果中笔记显示悬浮窗不应直接出现。
8. Web 主界面中的“笔记显示”页签和“笔记”页签是两个独立模块入口。

## 当前风险分析

- 主要风险 1：`src/notes_overlay.ahk` 已达中等体量，后续若继续把解析、滚动、保护、状态缓存都加进去，维护成本会明显上升。
- 主要风险 2：Web 侧当前通过 `app-main.js` 承接“笔记显示”模式切换与状态渲染，继续增长后会和其他模块互相缠绕。
- 主要风险 3：本模块天然依赖笔记数据源，若边界不写死，后面很容易再次回退成“笔记模块的附属页面”。
