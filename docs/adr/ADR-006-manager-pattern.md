# ADR-006: Domain-Specific Manager Pattern

## Status
Accepted

## Context
As llm-nvim grew to support multiple domains (models, fragments, templates, schemas, etc.), we needed:
- Clear separation of concerns
- Independent testing of domain logic
- Consistent API patterns
- Lazy loading to reduce startup time
- Centralized access to domain functionality

## Decision
Implement a domain-specific manager pattern where each major domain has its own manager module:
- `models_manager.lua`: Model listing, selection, defaults
- `fragments_manager.lua`: Fragment management (files, URLs, GitHub)
- `templates_manager.lua`: Template creation and execution
- `schemas_manager.lua`: Schema management and execution
- `keys_manager.lua`: API key management
- `plugins_manager.lua`: LLM plugin management

Managers are accessed through a facade (`facade.lua`) that provides lazy loading.

## Consequences

### Positive
- **Separation of Concerns**: Each manager handles one domain
- **Testability**: Independent testing of each domain
- **Maintainability**: Clear ownership and responsibility
- **Performance**: Lazy loading reduces startup overhead
- **Extensibility**: Easy to add new domains

### Negative
- **Complexity**: More modules to understand
- **Overhead**: Facade layer adds indirection
- **Consistency**: Need to maintain consistent API patterns

## Alternatives Considered

### 1. Monolithic Module
- **Approach**: Single large module with all functionality
- **Rejected**: Hard to test, maintain, and understand

### 2. Functional Approach
- **Approach**: Collection of independent functions
- **Rejected**: No clear organization, hard to manage state

### 3. Object-Oriented Classes
- **Approach**: Use Lua classes with inheritance
- **Rejected**: Overkill for this use case, adds complexity

## Implementation Details

### Manager Structure
Each manager follows this pattern:
```lua
local M = {}

function M.list()
  -- Domain-specific logic
end

function M.select()
  -- User interaction
end

-- ... other domain functions

return M
```

### Facade Access
```lua
-- In facade.lua
function M.get_manager(name)
  if not managers[name] and manager_files[name] then
    managers[name] = require(manager_files[name])
  end
  return managers[name]
end
```

### View Integration
Each manager has corresponding view components in `lua/llm/ui/views/` for UI presentation.

## References
- `lua/llm/facade.lua`: Manager facade
- `lua/llm/managers/`: Manager implementations
- `lua/llm/ui/views/`: Manager UI views
- `docs/architecture.md#manager-pattern`: Architecture overview

---
*Date: 2025-02-11*
*Implemented: 2025-02-11*