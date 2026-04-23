# ADR-0003: Hotkey Persistence Guardrails

Status: Accepted
Date: 2026-04-21

## Context
User reported hotkeys/default fields disappearing after save/refresh.

## Decision
Backend save/read must always enforce built-in categories and default hotkey fallback.

## Consequences
- Prevents config corruption from partial payloads.
- Preserves MVP promise: data remains unless user manually deletes.
