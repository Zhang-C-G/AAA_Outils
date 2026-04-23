# Test Matrix

Last updated: 2026-04-21

## Shortcuts/Quick Fields
- Open panel (`Alt+Q`), match, insert, usage increment.
- Save category changes; reload; verify persistence.

## Hotkeys
- Edit hotkey values in dedicated hotkeys view.
- Validate conflict and invalid format handling.
- Restart and verify applied bindings.

## Notes
- Create/edit/delete note.
- Switch mode and ensure autosave.

## Capture to Phone
- Start/stop bridge.
- Capture screen and upload.
- Verify status indicators update.

## Assistant
- Trigger capture ask (`Alt+Shift+A`).
- Verify template selection and overlay output.
- Verify hourly rate limit.

## Browser Detection Probe (F1/F2 / Focus)
- Run `powershell -ExecutionPolicy Bypass -File .\scripts\run_hotkey_focus_probe.ps1`.
- Keep probe page focused, then:
- Click assistant overlay area and observe whether probe logs `window.blur` / `visibilitychange`.
- Press `F2` (open overlay) and `F1` (capture ask), observe if probe logs `keydown/keyup` for those keys.
- Success criteria:
- Overlay click should not trigger focus loss in normal path (`NoActivate` expected).
- If `F1/F2` appears in probe logs, browser event layer can see key events in current context.
- Detailed guide: `docs/testing/HOTKEY_FOCUS_PROBE.md`

## Overlay Recording Capture Check
- Run `powershell -ExecutionPolicy Bypass -File .\scripts\test_overlay_record_capture.ps1`.
- Keep assistant overlay visible before running.
- Ensure `ffmpeg` is installed and available in PATH.
- Check script exit/result:
- `PASS`: no obvious overlay capture in recording frames.
- `WARN`: manual review needed.
- `FAIL`: overlay likely captured in recording.

## Web Config Backend
- `/api/state` returns categories/data/hotkeys.
- `/api/save` preserves built-in categories and hotkeys.
