# llm-nvim Documentation

This directory contains comprehensive documentation for the llm-nvim plugin.

## Documentation Structure

### Core Documentation

- **[Features](features/README.md)**: Complete feature list, requirements, and configuration options
- **[Architecture](architecture/README.md)**: Architectural decisions, data flows, and technical rationale
- **[History](history.md)**: Historical record of completed development work

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
- **Features**: [Features Documentation](features/README.md)
- **Configuration**: [Configuration Options](features/README.md#configuration-options)

### For Contributors
- **Architecture**: [Architecture Documentation](architecture/README.md)
- **Current Tasks**: [tasks/README.md](tasks/README.md)
- **Development Workflow**: [../AGENTS.md](../AGENTS.md)
- **Testing**: [../README.md#testing](../README.md#testing)

### For Maintainers
- **Task Management**: [tasks/README.md](tasks/README.md)
- **History**: [history.md](history.md)
- **Architecture Decisions**: [Architecture Decisions](architecture/README.md#key-architectural-decisions)

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

See [tasks/README.md](tasks/README.md) for task documentation standards and current status.
