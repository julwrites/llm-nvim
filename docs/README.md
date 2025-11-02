# llm-nvim Documentation

This directory contains comprehensive documentation for the llm-nvim plugin.

## Documentation Structure

### Core Documentation

- **[features.md](features.md)**: Complete feature list, requirements, and configuration options
- **[architecture.md](architecture.md)**: Architectural decisions, data flows, and technical rationale
- **[history.md](history.md)**: Historical record of completed development work

### Task System

- **[tasks/](tasks/)**: Implementation task documentation
  - **[tasks/README.md](tasks/README.md)**: Task system overview and current status
  - **tasks/critical/**: Blocking issues (P0)
  - **tasks/code-quality/**: Code cleanup (P1)
  - **tasks/testing/**: Test infrastructure (P1-P2)
  - **tasks/documentation/**: Documentation improvements (P2)
  - **tasks/performance/**: Performance optimizations (P3)

## Quick Navigation

### For Users
- **Getting Started**: See main [README.md](../README.md)
- **Features**: [features.md](features.md)
- **Configuration**: [features.md](features.md#configuration-options)

### For Contributors
- **Architecture**: [architecture.md](architecture.md)
- **Current Tasks**: [tasks/README.md](tasks/README.md)
- **Development Workflow**: [../AGENTS.md](../AGENTS.md)
- **Testing**: [../README.md#testing](../README.md#testing)

### For Maintainers
- **Task Management**: [tasks/README.md](tasks/README.md)
- **History**: [history.md](history.md)
- **Architecture Decisions**: [architecture.md](architecture.md#key-architectural-decisions)

## Documentation Principles

1. **Keep it Current**: Update docs when code changes
2. **Be Specific**: Include file paths and line numbers
3. **Explain Why**: Document decisions and trade-offs
4. **Link Liberally**: Cross-reference related docs
5. **Maintain History**: Preserve context for future reference

## Contributing to Documentation

When updating documentation:

1. **Features**: Update when adding/changing user-facing functionality
2. **Architecture**: Update when making structural or design decisions
3. **Tasks**: Create task documents before implementation, update during work
4. **History**: Append completed work, never delete

See [task-documentation-guide.md](../task-documentation-guide.md) for detailed task documentation standards.
