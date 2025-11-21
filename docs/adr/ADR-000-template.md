# ADR-000: Template for Architectural Decision Records

## Status
Template

## Context
When making significant architectural decisions, we need a consistent format to document:
- What problem we're solving
- What decision we made
- Why we made it
- What alternatives we considered
- What consequences we accept

This template provides a standard structure for all ADRs in this project.

## Decision
Use this template for all architectural decision records in llm-nvim.

## Template Structure

### Required Sections
1. **Status**: Current state of the decision (Proposed, Accepted, Deprecated, Superseded)
2. **Context**: The problem, constraints, and forces at play
3. **Decision**: What we decided to do
4. **Consequences**: What becomes easier or harder
5. **Alternatives Considered**: What else we looked at and why we rejected it

### Optional Sections
- **References**: Related code, tasks, or external resources
- **Implementation Notes**: Specific technical details
- **Migration Path**: If superseding or deprecating

## Consequences

### Positive
- Consistent documentation across all decisions
- Easy to understand past reasoning
- Clear template for future decisions
- Helps onboard new contributors

### Negative
- Requires discipline to maintain
- Takes time to write properly

## Usage Guidelines

1. **When to Create an ADR**: For any decision that affects:
   - Core architecture patterns
   - Major dependencies
   - Data flow or state management
   - Public APIs
   - Testing strategy

2. **Numbering**: Sequential (ADR-001, ADR-002, etc.)

3. **Lifecycle**: 
   - Start as "Proposed"
   - Move to "Accepted" when implemented
   - Mark "Deprecated" if no longer recommended
   - Mark "Superseded by ADR-XXX" if replaced

4. **Update vs New**: 
   - Don't edit accepted ADRs (they're historical record)
   - Create new ADR that supersedes the old one

---
*Date: 2025-02-11*
*Template Version: 1.0*
