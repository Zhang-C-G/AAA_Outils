# Config Schema

Last updated: 2026-04-21

## File
- `config.ini`

## Sections
- `[Categories]`: category id -> display name
- `[Fields]` / `[Prompts]` / `[QuickFields]` / `[Category_*]`: trigger -> content
- `[Hotkeys]`: action id -> AHK hotkey
- `[Behavior]`: auto refresh strategy
- `[App]`: active mode
- `[Capture]`: upload endpoint, bridge port, QR behavior
- `[Assistant]`: model/API/opacity/rate limit
- `[AssistantTemplates]`: template name -> prompt

## Required defaults
- Categories must include: `fields`, `prompts`, `quick_fields`
- Hotkeys must include default action set
