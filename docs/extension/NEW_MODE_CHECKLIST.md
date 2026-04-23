# New Mode Checklist

Use this when adding a new top-level mode (example: diary/taskboard).

## Code
1. Add mode state and switch mapping.
2. Add UI tab/button.
3. Add save/load branch in frontend and backend.
4. Add storage section and defaults.
5. Add hotkeys if needed.

## Docs
1. Add/Update module doc in `docs/modules/`.
2. Update shared contracts if cross-cutting.
3. Update `docs/components/20_UI_AND_MODES.md` and API docs.
4. Append `docs/ACTION_LOG.md` maintenance entry.

## Validation
1. Open mode, edit data, save, reload.
2. Restart app and verify persistence.
3. Check no regression in existing modes.
