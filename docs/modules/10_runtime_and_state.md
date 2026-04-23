# 模块 10：运行态与全局状态

## 模块目标

- 维护启动顺序、全局变量、模式状态与热键注册生命周期。
- 保证新增功能接入时不破坏主链路。

## 主要文件

- `main.ahk`
- `src/app_state.ahk`
- `src/config_modes.ahk`
- `src/config_modes/mode_state.ahk`
- `src/config_modes/mode_switch.ahk`
- `src/theme.ahk`
- `src/helpers.ahk`

## 关键约束

- `main.ahk` 仅做 include 和 `Init()` 调用。
- 新功能优先“子模块 + 聚合 include”，避免入口膨胀。
- 变更后应保证热键、Web 配置桥、模式状态一致可用。

## 改动后必查

1. 冷启动后全局热键正常注册。
2. Web 配置服务可启动并可通信。
3. 模式切换后状态一致，不出现空引用。
