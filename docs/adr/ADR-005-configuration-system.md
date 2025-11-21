# ADR-005: Centralized Configuration System

## Status
Accepted

## Context
We needed a robust configuration system for llm-nvim that:
- Provides type-safe configuration access
- Supports validation and defaults
- Enables reactive updates via change listeners
- Centralizes all plugin settings in one place
- Handles complex configuration structures

## Decision
Implement a centralized configuration system in `lua/llm/config.lua` with:
- Type metadata for all configuration options
- Validation and type conversion utilities
- Change listener registration
- Deep merging of user config with defaults
- Clean API for accessing config values

## Consequences

### Positive
- Single source of truth for all configuration
- Type safety prevents runtime errors
- Reactive updates enable dynamic behavior
- Clean separation between config and business logic
- Easy to add new configuration options

### Negative
- Additional complexity for simple configuration needs
- Requires discipline to use consistently across codebase
- Slight performance overhead for config access

## Alternatives Considered

### 1. Global Variables
- **Approach**: Use `vim.g.llm_*` variables directly
- **Rejected**: No validation, no type safety, no change listeners

### 2. Simple Table
- **Approach**: Store config as simple Lua table
- **Rejected**: No validation, no defaults, no reactive updates

### 3. External Config Library
- **Approach**: Use existing Lua config library
- **Rejected**: Unnecessary dependency, less control over validation

## Implementation Details

### Configuration Structure
```lua
M.defaults = {
  model = {
    default = nil,
    type = "string",
    desc = "Default model to use"
  },
  system_prompt = {
    default = "You are a helpful assistant.",
    type = "string",
    desc = "Default system prompt"
  }
  -- ... more options
}
```

### Key Features
- **Type Validation**: Automatic type checking and conversion
- **Change Listeners**: Register callbacks for config changes
- **Deep Merging**: Proper handling of nested configuration
- **Error Handling**: Graceful handling of invalid config

## References
- `lua/llm/config.lua`: Implementation
- `lua/llm/core/utils/validate.lua`: Validation utilities
- `docs/architecture.md#configuration-system`: Architecture overview

---
*Date: 2025-02-11*
*Implemented: 2025-02-11*