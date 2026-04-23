# Shared 04：日志契约（Logging Contract）

## 定义

统一动作命名规范和日志格式，供所有模块复用。

## 格式

`yyyy-MM-dd HH:mm:ss | action_name | detail`

## 主要来源

- 动作清单：`docs/ACTION_LOG.md`
- AHK 记录函数：`src/helpers.ahk` 的 `WriteLog`
- Web 记录函数：`webui/config/server-common.ps1` 的 `Write-AppLog`

## 约束

1. 新行为先定义动作名，再落代码。
2. 不记录敏感凭据（完整 token、密钥明文、密码）。
3. 动作名尽量稳定，避免频繁重命名影响排障。
