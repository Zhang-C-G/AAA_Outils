# ADR-0001: Stack and Runtime Baseline

Status: Accepted
Date: 2026-04-21

## Context
The project must deliver fast MVP iteration on Windows with global hotkeys, desktop overlay, and a local config UI.

## Decision
Use AutoHotkey v2 for runtime/hotkeys and a local Web UI (PowerShell HttpListener + HTML/JS/CSS) for configuration.

## Consequences
- Fast iteration for OS-level input automation.
- Web UI gives higher UI flexibility than native AHK controls.
- Requires strict config contract to keep AHK/Web state in sync.
