# 界面颜色与文字样式映射（UI Style Tokens）

目的：统一记录“哪些文字/区域使用同一颜色”，后续改界面时只需改 token。

## 单一来源

- AHK 主题源：`src/theme.ahk` 的 `InitTheme()`。
- Web 主题源：`webui/config/styles.css` 的 `:root` CSS 变量。
- 原则：优先改 token，不直接散改硬编码色值。

## AHK Token（`gTheme[...]`）

- `bg_app`：整体深色背景（主界面主体、悬浮窗外层）
- `bg_surface`：深色卡片层（列表区域、头部主栏）
- `bg_surface_alt`：深色次级按钮层（删除/上移/下移）
- `bg_header`：白色按钮或白底输入区背景
- `text_primary`：主文字（亮色）
- `text_on_light`：白底上的深色文字
- `text_muted`：次级文字（说明副标题）
- `text_hint`：提示文字（弱化信息）
- `text_dark_hint`：白底区域上的灰色副标题
- `line`：分割线

## Web CSS 变量（`styles.css :root`）

- `--bg`：页面主背景基色
- `--bg2`：次级背景基色
- `--line`：边框/分割线
- `--text`：主文字
- `--muted`：次级文字
- `--shadow`：卡片阴影

## 同色分组（便于统一改）

- A组（主文字）：`text_primary` / `--text`
- B组（提示文字）：`text_hint`、`text_muted` / `--muted`
- C组（主按钮白底）：`bg_header + text_on_light` / `.btn.primary`、`.mode-btn.active`、`.tab.active`
- D组（深色容器）：`bg_surface` / `.topbar`、`.panel`、`.table-wrap`
- E组（状态灯）：
- 绿色连通：AHK `c22AA44`，Web `.badge.on`
- 红色断开：AHK `cCC3333`，Web `.badge.off`
- 黄色等待：AHK `cC99922`，Web `.badge.wait`

## 当前组件映射

- 悬浮窗：`src/panel_ui.ahk`
- 问答悬浮窗：`src/assistant_overlay.ahk`
- 主配置 AHK 壳层：`src/config_ui.ahk`
- 模式页 AHK：`src/config_modes/*.ahk`
- Web 配置页：`webui/config/index.html` + `webui/config/styles.css`

## 维护规则

- 新增 UI 时先选 token，再落代码。
- 若必须新增颜色，先在 `InitTheme()` 或 `:root` 增加变量，再引用。
- 改动说明里写明“新增/修改了哪些 token”。
