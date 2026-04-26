# RESOLVED: 助手麦克风链路缺失 / 设备接口异常（2026-04-26）

## 现象

- 回退到旧版本后，助手页中的麦克风链路不完整。
- Web 端缺少或无法正常使用麦克风设备选择。
- `/api/assistant/audio-input-devices` 初始表现为 `404`，切到新服务后又出现 `500`。

## 根因

- 整体回退到上一个 git 版本时，麦克风链路对应提交未包含在当前版本中。
- Web 配置服务一度仍由旧进程响应，导致新路由未生效。
- `Get-AssistantVoiceInputScriptPath` 在当前加载方式下依赖的路径上下文不稳定，返回了空路径。
- 设备接口返回时未强制包成数组，前后端联调口径不够稳。

## 修复

- 重新接回麦克风链路提交：`feat: wire assistant microphone detection flow`
- 手工重启 Web 配置服务，确认 `8798` 端口由当前仓库版本响应。
- 修正 `webui/config/server_state/assistant.ps1` 中的语音脚本路径解析逻辑。
- 修正 `webui/config/server.ps1` 中设备返回格式，统一使用数组输出。

## 影响文件

- `scripts/assistant_voice_input.ps1`
- `src/assistant_overlay.ahk`
- `src/storage/assistant.ahk`
- `webui/config/app-assistant.js`
- `webui/config/server.ps1`
- `webui/config/server_state/assistant.ps1`
- `webui/config/styles.css`
- `webui/config/top-layer-select.js`

## 验收结论

- `main.ahk` 已重新启动。
- `/api/ping` 返回正常。
- `/api/assistant/audio-input-devices` 已返回设备列表。
- 当前版本可作为“麦克风链路已恢复”的稳定检查点。
