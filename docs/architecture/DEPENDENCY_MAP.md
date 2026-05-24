# Dependency Map

Last updated: 2026-05-24

## Runtime path
- `main.ahk` -> `src/app_state.ahk` -> core modules (`hotkeys`, `panel_ui`, `storage`, `config_ui`, `web_config`)

## Web config path
- `src/web_config.ahk` -> `webui/config/server.ps1`
- `server.ps1` routes to state/notes/capture/assistant handlers
- `webui/config/app-notes.js` is the notes workspace module
- `webui/config/app-note-session.js` is the note session module for save/switch/restore state
- `webui/config/app-notes-display.js` is the notes display workspace module
- `webui/config/app-notes-display-session.js` is the notes display session module for load/save/select/dirty state

## Architecture workflow path
- `CONTEXT.md` defines repo domain language for architecture work
- `docs/architecture/SKILL_ORCHESTRATION.md` defines the closed loop:
  - detection -> `improve-codebase-architecture`
  - generation -> `web-coder`
  - verification -> syntax/contract/runtime checks
  - archive -> module/changelog/architecture docs

## Dependency constraints
1. Entry files should remain thin.
2. Feature modules should depend on shared helpers, not vice versa.
3. `server_state/config.ps1` is config-contract critical; avoid UI-specific logic there.
4. Notes workspace state-machine behavior should deepen into `app-note-session.js`; DOM orchestration should stay in `app-notes.js`.
5. Notes display workspace state-machine behavior should deepen into `app-notes-display-session.js`; DOM orchestration should stay in `app-notes-display.js`.
