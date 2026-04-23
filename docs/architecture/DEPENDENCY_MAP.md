# Dependency Map

Last updated: 2026-04-21

## Runtime path
- `main.ahk` -> `src/app_state.ahk` -> core modules (`hotkeys`, `panel_ui`, `storage`, `config_ui`, `web_config`)

## Web config path
- `src/web_config.ahk` -> `webui/config/server.ps1`
- `server.ps1` routes to state/notes/capture/assistant handlers

## Dependency constraints
1. Entry files should remain thin.
2. Feature modules should depend on shared helpers, not vice versa.
3. `server_state/config.ps1` is config-contract critical; avoid UI-specific logic there.
