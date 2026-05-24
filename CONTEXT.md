# Project Context

## Domain language

- `Domain`: the top-level business area of this desktop productivity suite.
- `Module`: a feature-level unit with independent ownership and documentation.
- `Shared block`: a cross-cutting reusable capability shared by more than one module.
- `Quick Fields`: the dedicated category for short reusable inserts.
- `Hotkeys`: global bindings that trigger actions.
- `Bridge`: the phone link service for capture sharing.
- `Template`: an assistant prompt profile.

## Runtime concepts

- `AHK runtime`: the AutoHotkey v2 desktop runtime responsible for hotkeys, overlays, window protection, and local persistence orchestration.
- `Web config`: the local HTML/JS/CSS + PowerShell configuration workspace.
- `Notes workspace`: the B module editing workspace for single-note authoring, rendered editing, export, extract view, and outline navigation.
- `Notes display overlay`: the C/F4 overlay workspace for reading and navigating a selected note set.
- `Assistant runtime`: the screenshot/voice assistant execution path spanning overlay UI, provider settings, stream execution, and benchmark flows.

## Architecture constraints

- The accepted stack baseline is `AHK runtime + local Web config`; architecture work must deepen seams inside that baseline rather than replace it.
- Entry files should remain thin.
- Feature modules should depend on shared blocks, not vice versa.
- Persistent config and hotkey guardrails are contract-critical; partial payloads must not erase built-in defaults.

## Module expectations

- Every real feature change must map back to a documented module or shared block.
- A module is healthy when its interface hides runtime and persistence complexity from callers.
- A shared block is healthy when it centralizes a rule that would otherwise leak into multiple modules.
