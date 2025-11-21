# ADR-008: Command System Architecture

## Status
Accepted

## Context
The plugin needed a flexible command system that:
- Supports multiple command types (prompt, chat, config, etc.)
- Handles different input sources (direct prompt, selection, file)
- Provides subcommand completion
- Maintains consistent error handling
- Integrates with Neovim's user command system

## Decision
Implement a multi-layered command system:
1. **Plugin Entry Point** (`plugin/llm.lua`): User command registration
2. **Command Dispatcher** (`commands.lua`): Route to appropriate handlers
3. **Domain Handlers**: Specific logic for each command type
4. **API Layer** (`api.lua`): LLM CLI interaction

## Consequences

### Positive
- **Flexible**: Easy to add new command types
- **Consistent**: Uniform error handling and user experience
- **Discoverable**: Command completion helps users
- **Testable**: Each layer can be tested independently
- **Extensible**: New subcommands easy to add

### Negative
- **Complexity**: Multiple layers of indirection
- **Overhead**: Additional function calls
- **Learning Curve**: More files to understand

## Alternatives Considered

### 1. Monolithic Command Handler
- **Approach**: Single large function handling all commands
- **Rejected**: Hard to maintain and test

### 2. Per-Command Modules
- **Approach**: Separate file for each command type
- **Rejected**: Too many small files, harder to navigate

### 3. Event-Driven System
- **Approach**: Publish/subscribe pattern for commands
- **Rejected**: Over-engineered for current needs

## Implementation Details

### Command Registration
```lua
-- In plugin/llm.lua
vim.api.nvim_create_user_command("LLM", function(opts)
  -- Dispatch to commands.lua
end, {
  nargs = "*",
  range = true,
  complete = function()
    -- Subcommand completion
  end
})
```

### Command Dispatching
```lua
-- In commands.lua
function M.dispatch_command(subcmd, ...)
  if subcmd == "selection" then
    return M.prompt_with_selection(...)
  elseif subcmd == "file" then
    return M.prompt_with_current_file(...)
  -- ... other subcommands
  else
    -- Default: treat as direct prompt
    return M.prompt(subcmd, ...)
  end
end
```

### Command Types
- **Direct Prompt**: `:LLM "explain this code"`
- **Selection**: `:'<,'>LLM selection "improve this"`
- **File**: `:LLM file "explain this file"`
- **Chat**: `:LLMChat "hello"`
- **Config**: `:LLMConfig models`

## References
- `plugin/llm.lua`: Command registration
- `lua/llm/commands.lua`: Command dispatching
- `lua/llm/api.lua`: LLM CLI interaction
- `docs/features.md#core-features`: Feature documentation

---
*Date: 2025-02-11*
*Implemented: 2025-02-11*