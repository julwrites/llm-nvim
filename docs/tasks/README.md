# Task Documentation System

This directory contains all implementation tasks for llm-nvim, organized by category and tracked following a standardized format.

## Directory Structure

```
docs/tasks/
├── README.md                  # This file
├── critical/                  # Blocking issues affecting functionality
├── code-quality/             # Code cleanup and maintainability
├── testing/                  # Test infrastructure and quality
├── documentation/            # Documentation improvements
└── performance/              # Performance optimizations
```

## Task Categories

### Critical
Tasks that block core functionality or cause user-facing failures. These should be addressed immediately.

**Current tasks**:
- ⏳ CRITICAL-003: Redesign and Fix Chat Feature
- ⏳ CRITICAL-004: Add Embeddings Support
- ⏳ CRITICAL-005: Add Tools (Function Calling) Support
- ⏳ CRITICAL-006: Add Multi-modal Attachments Support

**✅ Completed tasks**:
- CRITICAL-001: Fix Lua 5.2+ compatibility (unpack → table.unpack)
- CRITICAL-002: Implement proper line buffering in job.lua

### Code Quality
Tasks that improve code maintainability, remove technical debt, and follow best practices.

**Current tasks**:
- ⏳ CODE-QUALITY-004: Add Model Alias Management

**✅ Completed tasks**:
- CODE-QUALITY-001: Remove excessive debug logging
- CODE-QUALITY-002: Remove duplicate LLMChat command registration
- CODE-QUALITY-003: Remove unused validate_view_name function

### Testing
Tasks related to test infrastructure, test coverage, and quality assurance.

**Current tasks**:
- ✅ TESTING-001: Audit codebase for Lua 5.1 vs 5.2+ compatibility
- ⏳ TESTING-002: Add CI/CD pipeline for automated testing

### Documentation
Tasks that improve user or developer documentation.

**Current tasks**:
- ✅ DOCUMENTATION-001: Document Lua version requirements
- ✅ DOCUMENTATION-002: Add architectural decision records (ADRs)

### Performance
Tasks that optimize performance without changing functionality.

**Current tasks**:
- ⏳ PERFORMANCE-001: Implement caching for manager LLM CLI calls

## Task Status

| Category      | Pending | In Progress | Completed | Blocked |
|---------------|---------|-------------|-----------|---------|
| Critical      | 4       | 0           | 2         | 0       |
| Code Quality  | 1       | 0           | 3         | 0       |
| Testing       | 2       | 0           | 0         | 0       |
| Documentation | 2       | 0           | 0         | 0       |
| Performance   | 1       | 0           | 0         | 0       |
| **Total**     | **10**  | **0**       | **5**     | **0**     |


## Quick Start

### Finding Tasks

**By priority**:
```bash
# Critical tasks
ls docs/tasks/critical/

# All pending tasks
grep -r "Status**: pending" docs/tasks/
```

**By dependency status**:
```bash
# Tasks with no dependencies (can start immediately)
grep -r "Dependencies**: None" docs/tasks/
```

### Working on a Task

1. **Read the task document** in the appropriate category directory
2. **Update status to in_progress** in the task file
3. **Follow acceptance criteria** and implementation notes
4. **Update the task document** as you work:
   - Mark completed acceptance criteria
   - Document decisions and blockers
   - Record git commits
5. **Mark completed** when all criteria are met

### Creating a New Task

1. **Choose category**: critical, code-quality, testing, documentation, or performance
2. **Generate task ID**: `[CATEGORY]-NNN` (use next available number)
3. **Create task file**: `docs/tasks/[category]/[TASK-ID]-[slug].md`
4. **Use template**: See task-documentation-guide.md for full template
5. **Update this README**: Add to category list and status table

## Priority Guidelines

### Critical (P0)
- Breaks existing functionality
- Causes test failures affecting core features
- Blocks other development work
- Security vulnerabilities

**Timeline**: Address immediately

### High (P1)
- Significant code quality issues
- Missing test coverage for critical paths
- Documentation gaps affecting usability
- Compatibility issues

**Timeline**: Address within current sprint/phase

### Medium (P2)
- Code cleanup and refactoring
- Nice-to-have features
- Process improvements (CI/CD)
- Documentation enhancements

**Timeline**: Address in next 1-2 phases

### Low (P3)
- Minor optimizations
- Future-looking improvements
- Non-urgent cleanup
- Enhancement ideas

**Timeline**: Address when convenient or defer

## Dependencies and Phases

### Phase 1: Critical Fixes
**Goal**: Get all tests passing and core functionality stable

Tasks:
- CRITICAL-001: Fix unpack compatibility
- CRITICAL-002: Implement line buffering

### Phase 2: Quality and Compatibility
**Goal**: Improve code quality and ensure broad compatibility

Tasks:
- CODE-QUALITY-001: Remove debug logging
- TESTING-001: Audit Lua compatibility
- DOCUMENTATION-001: Document Lua requirements

### Phase 3: Infrastructure and Process
**Goal**: Establish automated quality checks

Tasks:
- TESTING-002: Add CI/CD pipeline
- CODE-QUALITY-002: Remove duplicate command
- DOCUMENTATION-002: Add ADRs

### Phase 4: Optimizations
**Goal**: Performance and polish

Tasks:
- PERFORMANCE-001: Implement caching
- CODE-QUALITY-003: Remove unused code

### Phase 5: New Features (Roadmap)
**Goal**: Implement missing features and redesign the chat functionality.
- CRITICAL-003: Redesign and Fix Chat Feature
- CRITICAL-004: Add Embeddings Support
- CRITICAL-005: Add Tools (Function Calling) Support

### Phase 6: Polish and UX Improvements (Roadmap)
- CRITICAL-006: Add Multi-modal Attachments Support
- CODE-QUALITY-004: Add Model Alias Management

## Task Documentation Format

Each task document follows this structure:

```markdown
# Task: [Title]

## Task Information
- Task ID, Status, Priority, Phase
- Effort estimates
- Dependencies

## Task Details
- Description and problem statement
- Architecture components affected
- Acceptance criteria
- Implementation notes

## Implementation Status
- Completed work
- Current blockers
- Remaining work
- Git history

---
*Metadata footer*
```

See `task-documentation-guide.md` for complete documentation standards.

## Integration with Development

### For Developers

Before starting work:
1. Check `docs/tasks/` for existing tasks
2. Read task document for context
3. Update task status to `in_progress`
4. Follow implementation notes

During work:
1. Update task document with progress
2. Document decisions and blockers
3. Check off acceptance criteria
4. Record git commits

After completion:
1. Mark all criteria complete
2. Update status to `completed`
3. Record actual effort
4. Update this README status table

### For AI Assistants

The task system provides rich context for AI coding assistants:
- **Task documents** contain implementation guidance
- **Acceptance criteria** define success
- **Dependencies** prevent out-of-order work
- **Architecture notes** explain affected components
- **Implementation notes** provide specific direction

See AGENTS.md for AI-specific task documentation instructions.

## References

- **task-documentation-guide.md**: Complete guide to task documentation system
- **docs/architecture.md**: Architectural decisions and patterns
- **docs/features.md**: Feature list and requirements
- **AGENTS.md**: AI assistant integration guide

---

*Created: 2025-02-11*
*Last updated: 2025-11-14*
*Total tasks: 15 (6 critical, 4 code-quality, 2 testing, 2 documentation, 1 performance)*
