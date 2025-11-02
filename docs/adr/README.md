# Architectural Decision Records

This directory contains architectural decision records (ADRs) for llm-nvim. ADRs document significant architectural and design decisions made throughout the project's development.

## What is an ADR?

An Architectural Decision Record captures a single architectural decision along with its context and consequences. It serves as a historical record of why certain choices were made, helping current and future developers understand the reasoning behind the codebase's structure.

## Index

### Template
- [ADR-000](ADR-000-template.md) - Template for new ADRs

### Core Architecture
- [ADR-001](ADR-001-streaming-unification.md) - Unified Streaming Command Execution
- [ADR-002](ADR-002-chat-conversation.md) - LLM CLI Native Conversation Management
- [ADR-003](ADR-003-lazy-manager-facade.md) - Lazy-Loaded Manager Facade
- [ADR-004](ADR-004-temp-file-selection.md) - Temporary Files for Visual Selection

## Status Summary

| Status | Count | ADRs |
|--------|-------|------|
| Accepted | 4 | ADR-001, ADR-002, ADR-003, ADR-004 |
| Proposed | 0 | - |
| Deprecated | 0 | - |
| Superseded | 0 | - |

## When to Create an ADR

Create an ADR when you make a decision that:
- Affects the core architecture
- Introduces or changes a significant pattern
- Involves trade-offs between alternatives
- Will impact future development
- Needs to be explained to new contributors

## How to Create an ADR

1. Copy `ADR-000-template.md`
2. Name it `ADR-NNN-descriptive-title.md` (use next available number)
3. Fill in all sections:
   - **Status**: Start with "Proposed"
   - **Context**: Explain the problem and constraints
   - **Decision**: State what you decided
   - **Consequences**: List positive and negative outcomes
   - **Alternatives**: Document what else you considered
4. Get review from team/maintainers
5. Change status to "Accepted" when implemented
6. Add to this index

## ADR Lifecycle

```
Proposed → Accepted → [Deprecated | Superseded]
```

- **Proposed**: Decision is being considered
- **Accepted**: Decision is implemented and in use
- **Deprecated**: No longer recommended but not replaced
- **Superseded by ADR-XXX**: Replaced by newer decision

## Guidelines

### Do
- Write ADRs in simple, clear language
- Explain the "why" not just the "what"
- Document alternatives you considered
- Include code examples when helpful
- Link to relevant code and tasks
- Keep ADRs focused on one decision

### Don't
- Don't edit accepted ADRs (create new one instead)
- Don't document implementation details (use code comments)
- Don't make ADRs too long (2-3 pages max)
- Don't skip the "Alternatives Considered" section

## Reading Order for New Contributors

For understanding the architecture, read ADRs in this order:

1. **ADR-001**: Streaming unification - Core pattern for LLM communication
2. **ADR-003**: Manager facade - How features are organized and loaded
3. **ADR-004**: Selection handling - How user input is processed
4. **ADR-002**: Chat management - How conversations work

## Related Documentation

- [Architecture Overview](../architecture.md) - High-level architecture guide
- [Features](../features.md) - Feature list and requirements
- [Task History](../history.md) - Development history
- [AGENTS.md](../../AGENTS.md) - Development workflow guide

---

*Last updated: 2025-02-11*
*Total ADRs: 5 (including template)*
