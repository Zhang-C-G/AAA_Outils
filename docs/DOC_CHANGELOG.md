# Doc Changelog

Track documentation-only updates.

## 2026-04-21
- Added ADR/config/dependency/extension/testing/glossary policy docs.
- Added Shared contracts and governance templates.
- Added temporary incident file `docs/incidents/TEMP_field_loading_incident.md` for ongoing field-loading regression tracking.
- Synced `docs/ACTION_LOG.md` with this round of fixes (frontend parse fix + quick_fields mapping alignment).
- Synced incident/action docs for save reliability hardening (JSON parse strict mode, save payload validation, static no-cache, AHK pre-save reload sync).
- Synced docs for auto-save UX update (remove Ctrl+S save hint/handler, single-step delete confirm, UTF-8-first body decode).
- Synced docs for hotkeys layout optimization (full-width panel + multi-column utilization).
- Closed temp incident doc and added resolved incident archive.
- Rewrote garbled module docs (02/03/08) and refreshed UPDATE_CHECKLIST.
- Synced README with latest UX behavior (auto-save, single confirm delete, full-width hotkeys view).

## 2026-04-22
- Rewrote garbled docs with clean UTF-8 Chinese content: `DOC_SYSTEM.md`, `modules/01/04/05/07/09/10/README`, `shared/*`, `templates/MODULE_TEMPLATE.md`.
- Synced module 06 docs with latest assistant behavior (in-place update, anti-capture/anti-recording strategy, WDA-first fallback logic).
- Removed stale action names from module 06 (`assistant_overlay_sensitive_hide/restore`) to match current code.
- Synced top-level `README.md` with current screenshot-QA hotkeys and protection behavior.
- Clarified module taxonomy: business modules are 4 only; global hotkeys moved to Shared capability scope (docs updated in `DOC_SYSTEM.md`, `modules/README.md`, `modules/03_hotkey_settings.md`, `shared/01_global_hotkeys.md`, `UPDATE_CHECKLIST.md`, `README.md`).

## 2026-04-23
- Synced assistant model-selection docs: frontend switched from free text to backend-driven dropdown.
- Added model consistency contract: `/api/assistant/state` exposes `assistant.model_options`, and save path validates model against whitelist with default fallback.
- Updated module 06 and Web API component docs to include newly supported model `doubao-seed-2-0-pro-260215`.
- Added `docs/AI_HANDOFF.md` as the canonical AI handoff entry for project status, priorities, risks, and next-step context.
- Updated `docs/COMPONENTS.md` and `docs/UPDATE_CHECKLIST.md` to require ongoing AI handoff maintenance on future changes.
- Synced hotkey panel docs after removing `1-9` / `Numpad1-9` quick-insert behavior from the floating panel.
- Added cross-entry documentation note that AHK source edits trigger automatic hot reload during development, so future AI handoffs and debugging account for it.
- Documented the first usable resume-autofill module: Web resume editor, local resume API, `resume_profile.json`, and browser extension skeleton.

## 2026-04-25
- Reorganized documentation topology clarifications: rewrote `docs/DOC_SYSTEM.md`, `docs/modules/README.md`, `docs/shared/README.md`, and added `docs/architecture/README.md`.
- Added `docs/extension/README.md` and normalized extension governance docs (`AI_DEVELOPMENT_PLAYBOOK.md`, `OVERLAY_STAGE2_GUIDE.md`, `NEW_MODE_CHECKLIST.md`).
- Rewrote `docs/AI_HANDOFF.md` into a clean UTF-8 handoff entry focused on stable product core, current module status, hard constraints, and safe recovery path.
- Updated `docs/UPDATE_CHECKLIST.md` so each development round must first read the extension playbook, and overlay work must also read the overlay stage-2 guide.
