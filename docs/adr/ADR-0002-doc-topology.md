# ADR-0002: Documentation Topology

Status: Accepted
Date: 2026-04-21

## Context
The software is a large suite with multiple sub-features, and must be easy for future AI/developers to extend safely.

## Decision
Adopt three-layer docs:
1. Domain docs (architecture/global)
2. Module docs (feature-level)
3. Shared docs (cross-cutting contracts)

## Consequences
- Better onboarding and lower regression risk.
- Documentation updates become part of delivery checklist.
- Requires lightweight governance (`UPDATE_CHECKLIST.md`).
