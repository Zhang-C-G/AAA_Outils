# 模块 07：Web 配置前端

## 模块目标

- 提供统一的 Web 配置界面（多模块切换、编辑、保存）。
- 与后端 API 通信并处理前端状态同步。

## 主要文件

- `webui/config/index.html`
- `webui/config/styles.css`
- `webui/config/app-common.js`
- `webui/config/app-main.js`
- `webui/config/app-shortcuts.js`
- `webui/config/app-notes.js`
- `webui/config/app-capture.js`
- `webui/config/app-assistant.js`

## 关键规则

- `快捷字段` 与 `快捷键` 为独立视图。
- 自动保存优先，减少手动保存依赖。
- 页面文案与热键显示须跟随真实配置同步。

## 改动后必查

1. 模式切换按钮和内容视图一一对应。
2. 关键数据刷新后不丢失。
3. 快捷字段页不混入快捷键编辑区。
