---
id: FOUNDATION-20251212-062731-SAR
status: completed
title: Update Documentation against Code
priority: medium
created: 2025-12-12 06:27:31
category: foundation
dependencies:
type: task
---

# Update Documentation against Code

## Description
Update the project documentation to reflect the current code structure and feature set, ensuring consistency across `README.md`, `docs/`, and `AGENTS.md`.

## Plan
1.  **Analyze Documentation Structure**: Compare `docs/` structure with `lua/llm/` code structure.
2.  **Update Architecture Docs**: Update `docs/architecture/README.md` to include new modules (`errors.lua`, `chat/session.lua`, etc.) and remove dead code references.
3.  **Consolidate Feature Docs**: Move `docs/features.md` to `docs/features/README.md` to align with the directory-based documentation pattern.
4.  **Update Main Documentation Index**: Update `docs/README.md` to point to the correct locations (`features/README.md`, `architecture/README.md`).
5.  **Update Root README**: Add a link to the `docs/` directory and ensure feature lists are accurate.
6.  **Verify Links**: Ensure cross-references in `AGENTS.md` and other docs are valid.

## Progress
- [x] Analyze Documentation Structure
- [x] Update Architecture Docs
- [x] Consolidate Feature Docs
- [x] Update Main Documentation Index
- [x] Update Root README
- [x] Verify Links
