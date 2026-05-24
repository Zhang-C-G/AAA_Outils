# Skill Orchestration

Last updated: `2026-05-24`

## 1. Purpose

This document defines how architecture work in this repo must use skills as a closed loop instead of ad hoc analysis.

The goal is to make every architecture round explicit about:

1. which skill drives detection
2. which skill or local process drives design
3. how implementation is verified
4. how the result is archived back into project docs

## 2. Current Skill Map

### 2.1 Architecture detection

- Primary skill: `improve-codebase-architecture`
- Role:
  - find shallow modules
  - find leakage across seams
  - rank deepening candidates by leverage and locality
  - generate an architecture review report before major refactors

### 2.2 Web/runtime implementation

- Primary skill: `web-coder`
- Role:
  - turn architecture decisions into concrete JS / PowerShell / web-runtime code changes
  - keep browser-side and backend-side contracts aligned

### 2.3 UI/interaction implementation

- Primary skill: `frontend-design`
- Role:
  - only used when the architecture decision changes visible workspace structure or high-frequency interaction layout
  - not used for architecture detection itself

### 2.4 Skill discovery / installation

- Primary skills:
  - `find-skills`
  - `skill-installer`
- Role:
  - discover missing external capabilities
  - install skills before a new workflow is adopted

## 3. Closed Loop

Every architecture task follows this order.

### Step 1. Detection

- Read:
  - `docs/USER_DOC_SYSTEM_GUIDE.md`
  - `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`
  - relevant `docs/modules/*.md`
  - relevant `docs/modules/changelog/*.md`
  - `docs/architecture/DEPENDENCY_MAP.md`
  - `docs/adr/*.md`
  - `CONTEXT.md`
- Run architecture detection with `improve-codebase-architecture`
- Produce a temporary HTML report in OS temp

### Step 2. Candidate selection

- Pick one candidate only
- Name the target module, seam, and expected deepening
- If interface alternatives matter, use the interface-design path from the architecture skill before implementation

### Step 3. Generation

- Use `web-coder` for code generation and refactor execution
- If the change alters visible workflow structure, optionally use `frontend-design` for UI-side shaping
- Prefer introducing one deep module or shared block instead of scattering helper functions

### Step 4. Verification

- Minimum verification:
  - syntax / static checks
  - contract search with `rg`
  - workflow-specific regression checks
- Verification must answer:
  - did the interface shrink?
  - did locality improve?
  - did behavior stay intact?

### Step 5. Archive

- Update:
  - relevant `docs/modules/*.md`
  - relevant `docs/modules/changelog/*.md`
  - `docs/AI_HANDOFF.md` if project priorities or risk changed
  - `docs/DOC_CHANGELOG.md`
  - `docs/ACTION_LOG.md`
  - `docs/architecture/DEPENDENCY_MAP.md` if seam/dependency structure changed
- If terminology changed, update `CONTEXT.md`
- If a lasting architectural decision is made, add or update an ADR

## 4. Repo-specific Rules

### 4.1 Notes workspace

- Before adding features to `app-notes.js`, first ask whether the change belongs in:
  - note session
  - rendered editing surface
  - extract workflow
  - export workflow
  - outline/search workflow
- Default rule:
  - state-machine behavior goes into a deep module
  - DOM orchestration stays in the workspace module

### 4.2 Assistant runtime

- Before adding provider or benchmark logic, first ask whether it belongs in:
  - settings normalization
  - runtime execution
  - overlay presentation
  - benchmark/reporting

### 4.3 Web config server

- New routes should prefer route/module registration patterns over growing the top-level listener ladder

## 5. Done Criteria

An architecture round is only complete when all of these are true:

1. a chosen candidate has been deepened in code
2. verification was executed
3. docs were archived
4. the change can be explained in terms of module, interface, seam, leverage, and locality
