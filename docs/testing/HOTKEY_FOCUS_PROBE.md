# Hotkey / Focus Probe（浏览器焦点与按键探针）

最后更新：2026-04-23

## 目的

- 用于实测两类问题：
- 点击截图问答悬浮窗时，浏览器是否发生失焦（`window.blur` / `visibilitychange`）。
- 按下 `F1` / `F2`（或其他快捷键）时，浏览器事件层是否能感知到 `keydown/keyup`。

该工具是“观察与验证”工具，不修改业务逻辑。

## 文件位置

- 探针页面：`scripts/hotkey_focus_probe.html`
- 启动脚本：`scripts/run_hotkey_focus_probe.ps1`
- 录屏捕获检测脚本：`scripts/test_overlay_record_capture.ps1`

## 快速使用

在项目根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_hotkey_focus_probe.ps1
```

启动后浏览器会打开探针页。

## 标准测试流程

1. 保持探针页在前台，点击一次“打标记（手动）”。
2. 点击截图问答悬浮窗。
3. 按 `F2`（呼出悬浮窗）与 `F1`（截图问答）。
4. 观察日志区域：
- 是否出现 `window.blur` / `visibilitychange`
- 是否出现 `keydown/keyup`（`key="F1"`、`key="F2"`）

## 判定说明

- 若点击悬浮窗后无 `window.blur`：通常表示 NoActivate 路径生效，点击未触发浏览器焦点切换。
- 若出现 `F1/F2 keydown`：表示浏览器事件层在当前场景可感知到按键事件。
- 若未出现 `F1/F2 keydown`：仅代表探针页未感知，不等于系统其他组件完全不可感知。

## 日志导出

- 页面右上有“下载日志”按钮，可导出 `txt` 文件用于复盘。

## 常见误判与注意事项

- 探针页若不在前台，日志可能缺失，先确认页面前台状态。
- 浏览器插件、输入法、远控软件可能影响键盘事件表现，建议在同一环境重复 3 轮。
- 该工具主要验证“浏览器侧可见性”，不等同于系统级全量检测结论。

## 维护约定

- 若新增快捷键（如改为 `F3/F4` 或鼠标侧键），需同步更新本文件“标准测试流程”。
- 若探针页面增加新事件字段，需同步更新本文件“判定说明”。

## 录屏捕获检测（自动对比）

用途：检测“悬浮窗可见帧”与“悬浮窗隐藏帧”在录屏结果中的差异，判断录屏是否捕获到悬浮窗内容。

运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test_overlay_record_capture.ps1
```

前置条件：

1. 已呼出截图问答悬浮窗  
2. 本机可用 `ffmpeg`（在 PATH 中可直接执行）

输出结果：

- `PASS`：差异小，录屏中未明显捕获悬浮窗内容  
- `WARN`：差异中等，建议人工复核帧图  
- `FAIL`：差异大，录屏很可能捕获到悬浮窗
