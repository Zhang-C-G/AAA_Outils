# Shared 02：状态与模式（State / Mode）

## 定义

跨模块共享的运行态变量、活动模式和切换机制。

## 主要文件

- `src/app_state.ahk`
- `src/config_modes/mode_state.ahk`
- `src/config_modes/mode_switch.ahk`
- `webui/config/app-common.js`
- `webui/config/app-main.js`

## 约束

1. 新增模式必须同时接入 AHK 与 Web 两端映射。
2. 模式切换时需处理未保存状态与自动保存策略。
3. 退出/重载后状态恢复逻辑要可预测。
