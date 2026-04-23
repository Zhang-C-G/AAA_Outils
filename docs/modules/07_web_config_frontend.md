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
- `webui/config/app-testing.js`

## 关键规则

- `快捷字段` 与 `快捷键` 为独立视图。
- 自动保存优先，减少手动保存依赖。
- 页面文案与热键显示须跟随真实配置同步。
- `测试` 入口固定在栏目最右侧，并可直接触发测试工具。
- `截图问答` 页面采用“基础设置/高级设置”两段式；高级设置默认折叠隐藏。
- Web UI 全局隐藏滚动条（保持滚动能力），避免各栏目切换时出现可见右侧滚动条干扰。
- “快捷字段”页面移除“自动刷新策略”可视配置区，策略由系统内部保存与管理。
- 主界面右上角操作按钮（恢复版本/保存版本/刷新/保存）已移除，仅保留模式页内操作入口。

## 改动后必查

1. 模式切换按钮和内容视图一一对应。
2. 关键数据刷新后不丢失。
3. 快捷字段页不混入快捷键编辑区。
4. `测试` 按钮可切换到测试页，并能调用后端测试 API。
