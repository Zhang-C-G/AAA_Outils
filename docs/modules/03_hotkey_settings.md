# 模块 03：快捷键设置（配置页 / 公用能力入口）

## 模块目标

- 在独立“快捷键”页维护全部热键。
- 支持友好写法与 AHK 写法互转、格式校验、冲突检测、恢复默认。
- 布局采用全宽主区域，充分利用右侧空间。
- 说明：该页服务于 Shared 公用能力（全局快捷键），不计入业务模块数量。

## 主要文件

- `src/config_behavior_hotkeys.ahk`
- `src/hotkeys.ahk`
- `webui/config/app-shortcuts.js`
- `webui/config/index.html`（`modeHotkeysBtn` + `hotkeysView`）
- `webui/config/styles.css`

## 存储位置

- `config.ini` 的 `[Hotkeys]`

## 默认关键热键

- `toggle_panel=!q`
- `open_config=!+q`
- `assistant_capture=!+a`（启动问答悬浮窗）
- `assistant_capture_now=F1`
- `assistant_overlay_up=!Up`
- `assistant_overlay_down=!Down`

## 改动后必查

1. 快捷字段页不再混入快捷键编辑区。
2. 快捷键页为全宽布局，分组与分组内字段可多列展示。
3. 修改快捷键后可自动保存，重载后仍生效。
4. 非法格式与冲突可正确提示。
