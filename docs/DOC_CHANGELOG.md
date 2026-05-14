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

## 2026-04-26
- Added resolved incident archive for assistant microphone chain recovery: `docs/incidents/RESOLVED_2026-04-26_assistant_microphone_chain.md`.
- Synced `docs/ACTION_LOG.md` with microphone chain restoration, service restart diagnosis, and final interface verification.
- Added document-creation governance set: `docs/extension/DOC_CREATION_GUIDE.md` plus `docs/templates/STAGE1_DOC_TEMPLATE.md`, `docs/templates/STAGE2_CAPABILITY_TEMPLATE.md`, and `docs/templates/INCIDENT_TEMPLATE.md`.
- Updated `docs/extension/README.md` to expose the new document-creation guide entry.

## 2026-05-13
- Synced assistant voice docs to the completed F3 xunfei baseline: module 06 now reflects prewarm, live transcript, final text-only return, restart interruption, and scripted latency/stability regression.
- Updated `docs/modules/changelog/E_截图问答_修改过程.md` to mark the voice feature as stage-complete and archived the final documentation closeout.
- Updated `docs/AI_HANDOFF.md` so future recovery work treats F3 voice as an already-closed mainline, with rollback anchored to the stable xunfei + regression-tested version.
- Synced module 06 and the E-module changelog with the latest Assistant configuration UX: left/right profile-prompt layout, advanced settings split into General / Screenshot / Voice, and screenshot directory moved into the screenshot section.
- Documented the new F3 post-ASR auto-analysis flow, voice-only context-memory settings, and the personal-profile instruction path.
- Hardened documentation execution rules in `docs/AI_HANDOFF.md` and `docs/UPDATE_CHECKLIST.md` so module work must read and update both the module doc and the module changelog.
- Added a unified development startup route to `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`, linking stage judgment, module docs, module changelogs, overlay guides, shared contracts, private preferences, and the final checklist into one ordered path.
- Updated `docs/extension/全局私人偏好文档.md` and `docs/extension/README.md` so private preferences are explicitly downstream of stage judgment and module-document reading, rather than a separate parallel rule set.
- Added explicit response-format governance to `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`, `docs/AI_HANDOFF.md`, and `docs/UPDATE_CHECKLIST.md` so replies must state completed work, remaining work, doc status, test status, and git/checkpoint status.
- Added a monochrome site icon for the Web config frontend via `webui/config/favicon.svg`, and documented the favicon entry in `docs/modules/07_web_config_frontend.md`.
- Refined the Web config favicon to a lighter minimalist white-first geometric mark, replacing the heavier black-block version.
- Documented the current-user E-module profile fill: `config.ini` now carries a populated `[Assistant] personal_profile` based on the provided resume screenshot, explicitly as local configuration rather than a default value change.
- Added multiline-preservation rules for long-form text editing to `docs/extension/global_preferences/02_编辑态与光标偏好.md`, and documented the Assistant-side persistence fix so E-module `personal_profile` and `prompt` no longer collapse into a single paragraph on save.
- Documented the F-module profile-table rewrite: the base resume editor now uses a paired four-column `field + value + field + value` layout, locks field labels, removes add/delete row controls, and keeps value textareas fixed-height with internal vertical scrolling.
- Added the resume-autofill research workspace under `docs/resume_autofill/`, including strategy notes, a company-analysis folder, a Bilibili seed analysis file, and an issue log for failed autofill cases.
- Synced module-11 and the F-module changelog with the new execution direction: right-corner autosave notifications in the Web UI plus a browser-extension site-strategy layer on top of the generic fill fallback.
- Expanded the Bilibili company-analysis doc from placeholder to first-pass action analysis based on the supplied screenshot, and folded the resulting patterns into the shared strategy notes and issue log.
- Refined the Bilibili autofill analysis with the second screenshot batch: confirmed visible-text dropdown selection for gender, split birth-date and experience-time controls into separate date strategies, and promoted project-history handling into the first-wave site strategy plan.
- Documented the first executable Bilibili browser-extension strategy: the placeholder site-strategy layer now parses local grouped resume entries and attempts targeted fills for base info, education, internship/work, and project sections.
- Synced module-11 and the F-module changelog with the new F-module page split: resume editing and company-link maintenance now live behind a top-level `简历信息 / 公司信息` switch, with the company page using a full-width main area.
- Synced module-11 and the F-module changelog with the new Chrome-extension install guide: the resume page now exposes a popup guide, and the local backend returns the detected unpacked-extension directory for copy/paste installation.
- Extended the install-guide documentation again so the popup now covers direct actions too: opening `chrome://extensions/` and opening the detected unpacked-extension folder from the local backend.
- Added an Ant Group company-analysis doc under `docs/resume_autofill/company_analysis/`, and extended the shared autofill strategy notes with country/region dropdowns, composite phone inputs, finer-grained education fields, and tag-style tech-skill entry patterns.
- Revised response-format governance across `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`, `docs/AI_HANDOFF.md`, and `docs/UPDATE_CHECKLIST.md`: replies no longer have to explicitly state a numbered current round, but they must still report git/checkpoint status in terms of whether it was executed in the current work update.
- Tightened git-status governance across `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`, `docs/AI_HANDOFF.md`, `docs/UPDATE_CHECKLIST.md`, and `docs/CHANGE_CHECKPOINT_RULE.md`: git status must now also explicitly state the current position within the active `3`-change checkpoint cycle.
- Added `Ctrip / 携程` resume-page analysis under `docs/resume_autofill/company_analysis/ctrip.md`, and synced related strategy/module docs with observations about full-date pickers, denser education fields, award-list mapping, and minimal project-role mapping.
- Optimized the education structure in `resume_profile.json` for denser resume forms such as Ctrip by adding finer-grained education fields (`education_gpa`, `education_rank`, `second_major`, `research_direction`, `advisor`) and aligning education dates/degree wording with the visible form.
- Extended the resume editor and site strategy for multi-entry education maintenance: the F-module editor can now add/remove `education_entry_*` rows, and the site strategy now prefers `入学日期 / 毕业日期` when parsing structured education entries.
- Added `docs/USER_DOC_SYSTEM_GUIDE.md` as a user-facing explanation of the documentation system, covering document layers, common reading paths, user input vs. AI output, and the standard collaboration flow; linked it from `docs/COMPONENTS.md` and `docs/DOC_SYSTEM.md`.
- Reworked `docs/USER_DOC_SYSTEM_GUIDE.md` into a more visual decision-oriented guide with tree branches, trigger conditions, and concrete cases so users can map their current situation to the correct documentation path.
- Refined `docs/USER_DOC_SYSTEM_GUIDE.md` again by adding a short-name legend for key documents and a command-entry decision tree, so the guide can reference concise doc labels instead of repeating long full names.
- Localized the `docs/USER_DOC_SYSTEM_GUIDE.md` decision-tree labels from English short names to concise Chinese labels, making the command tree easier to scan for Chinese readers.
- Simplified `docs/USER_DOC_SYSTEM_GUIDE.md` into a pure flow guide: kept only the top-level decision tree and branch-level decision trees, and removed extra narrative sections and examples.
- Consolidated the previously separated decision trees in `docs/USER_DOC_SYSTEM_GUIDE.md` into one single master tree, so the user can follow the whole flow in one place.
- Corrected the master tree flow in `docs/USER_DOC_SYSTEM_GUIDE.md`: `总指挥` is now a single upfront entry step instead of being repeated inside later module/non-module branches.
- Refined the `docs/USER_DOC_SYSTEM_GUIDE.md` flow again so `总指挥` is only entered for actual execution tasks, clarifying that it governs explicit response rules, status reporting, documentation sync, and checkpoint behavior.
- Refined the `命中具体模块` branch in `docs/USER_DOC_SYSTEM_GUIDE.md` so task type is evaluated before deciding whether the work belongs to phase one or phase two, instead of presenting those as parallel axes.
- Expanded and reorganized the `命中具体模块` branch in `docs/USER_DOC_SYSTEM_GUIDE.md` to better match the playbook: added config-entry tasks, structure-vs-runtime bug routing, phase-entry logic, preference-doc triggers, and stage-two risk KB triggers.
- Further refined the `老模块新增能力` branch in `docs/USER_DOC_SYSTEM_GUIDE.md` by splitting it into structure-only additions versus real closed-loop additions, with clearer examples for each.
- Refined the `bug 修复` branch in `docs/USER_DOC_SYSTEM_GUIDE.md` to incorporate the incident workflow: check existing incident docs first, create `TEMP_*.md` when the threshold is met, and convert to `RESOLVED_*.md` once the fix is confirmed.
- Simplified the top-level module-task classification in `docs/USER_DOC_SYSTEM_GUIDE.md` by merging `回归修复` into `bug 修复` and folding `新配置项接入` into the `老模块新增能力 -> 补真实闭环` path.
- Restored `新配置项接入` as its own task type in `docs/USER_DOC_SYSTEM_GUIDE.md`, clarifying that it covers configuration-oriented capabilities outside visible business modules while still following phase-one/phase-two routing and four-layer sync checks.
- Refined the wording for `新配置项接入` in `docs/USER_DOC_SYSTEM_GUIDE.md`: even when the feature is not named as a module, it should still be built with the same modular, phase-based workflow.
- Expanded the `新模块` branch in `docs/USER_DOC_SYSTEM_GUIDE.md` to include the stage-one checklist, the criteria for entering stage two, the blockers for stage transition, and the stage-two completion requirements.
- Reformatted the `新模块` branch in `docs/USER_DOC_SYSTEM_GUIDE.md` from long descriptive lines into shorter grouped checklist branches for stage one and stage two.
- Added the missing preference-doc requirement back into the stage-one branch of `新模块` in `docs/USER_DOC_SYSTEM_GUIDE.md`, including UI-structure, control-style, and interaction-skeleton checks.
- Reformatted the `bug 修复` branch in `docs/USER_DOC_SYSTEM_GUIDE.md` into shorter checklist-like branches while preserving the incident workflow and archive rules.
- Shortened the `新配置项接入` branch in `docs/USER_DOC_SYSTEM_GUIDE.md` and renamed the generic phase gateway to `一旦已判断出阶段` to clarify that it is a shared stage-rule hub rather than a duplicate classifier.
- Added a short five-step usage guide to `docs/USER_DOC_SYSTEM_GUIDE.md`, clarified the `只补文档` path, and restructured `老模块新增能力` to mirror the phased, checklist-like style used elsewhere.
- Realigned `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`, `docs/extension/DOC_CREATION_GUIDE.md`, and `docs/AI_HANDOFF.md` with the newer user-guide structure: `docs/USER_DOC_SYSTEM_GUIDE.md` is now treated as a co-equal top-level entry, old task-type wording was corrected, and the stage-routing flow was updated.
- Extended the same realignment to `docs/UPDATE_CHECKLIST.md`, `docs/extension/README.md`, `docs/extension/文档体系总图.md`, and `docs/DOC_SYSTEM.md`, updating entry order, terminology, and finish-path wording to match the current user-guide structure.
- Continued the cleanup of older wording in `docs/COMPONENTS.md`, `docs/extension/NEW_MODE_CHECKLIST.md`, `docs/extension/全局私人偏好文档.md`, `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`, and `docs/USER_DOC_SYSTEM_GUIDE.md`, especially around entry order and the shift from `共享契约` to clearer cross-module-rule wording.
- Continued the same alignment for template and split-rule docs: `docs/extension/文档低耦合与拆分规则.md`, `docs/extension/模块库总索引.md`, `docs/templates/STAGE2_CAPABILITY_TEMPLATE.md`, and `docs/templates/MODULE_CHANGELOG_TEMPLATE.md` now also point back to `docs/USER_DOC_SYSTEM_GUIDE.md` as the front-door routing guide.
- Tightened the explicit-reply rules in `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md` so status updates should stay short, judgment-friendly, and sufficient for quickly verifying whether the required steps were actually completed.
- Fixed remaining outdated wording in `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`: restored the `docs/USER_DOC_SYSTEM_GUIDE.md` front-door role, removed `回归修复` as a separate task type, renamed shared-contract wording, and de-duplicated the `git` vs `checkpoint` reply rules.
- Simplified the explicit status rules further across `docs/extension/AI_DEVELOPMENT_PLAYBOOK.md`, `docs/AI_HANDOFF.md`, `docs/UPDATE_CHECKLIST.md`, and `docs/USER_DOC_SYSTEM_GUIDE.md`: the standalone `checkpoint 状态` field was removed, and its information is now folded into `git 状态`.
- Corrected the git-target wording in the governance docs so the default target is again stated as `origin/main`, matching the intended direct-to-main workflow.
- Documented the install-guide reliability fix for module 11: extension-path detection now probes multiple repo anchors, folder opening goes through `explorer.exe`, and the Chrome extensions page is opened from the backend instead of relying on frontend `window.open`.
