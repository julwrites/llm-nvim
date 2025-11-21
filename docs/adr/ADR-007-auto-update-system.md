# ADR-007: Auto-Update System for LLM CLI

## Status
Accepted

## Context
The llm CLI tool evolves rapidly with new features and improvements. Users need:
- Automatic updates to stay current
- Multiple installation method support (uv, pipx, pip, brew)
- Non-intrusive update checking
- Configurable update intervals
- Fallback mechanisms for different environments

## Decision
Implement an auto-update system with:
- Background update checks on plugin startup
- Configurable interval (default: 7 days)
- Support for multiple package managers
- Timestamp tracking to avoid excessive checks
- Graceful fallback through update methods
- Optional feature (disabled by default)

## Consequences

### Positive
- **Current Dependencies**: Users stay on latest llm CLI
- **Flexible Installation**: Supports diverse installation methods
- **Non-Intrusive**: Background checks don't block startup
- **Configurable**: Users can disable or adjust interval
- **Robust**: Multiple fallback methods

### Negative
- **Complexity**: Multiple update methods to maintain
- **Network Dependencies**: Requires internet access
- **Startup Overhead**: Small delay for update checks
- **Permission Issues**: May fail in restricted environments

## Alternatives Considered

### 1. Manual Updates Only
- **Approach**: Rely on users to update manually
- **Rejected**: Users fall behind on features and fixes

### 2. Prompt-Based Updates
- **Approach**: Ask users if they want to update
- **Rejected**: Intrusive, interrupts workflow

### 3. External Update Manager
- **Approach**: Use system package manager
- **Rejected**: Platform-dependent, less control

## Implementation Details

### Update Sequence
System tries update methods in this order:
1. **uv**: Modern Python package manager
2. **pipx**: Isolated Python applications
3. **pip**: Standard Python package manager
4. **brew**: macOS package manager

### Configuration Options
```lua
auto_update_cli = {
  default = false,
  type = "boolean",
  desc = "Enable/disable auto-updates"
},
auto_update_interval_days = {
  default = 7,
  type = "number",
  desc = "Update check interval in days"
}
```

### Timestamp Tracking
- Last update timestamp stored in plugin state
- Prevents checking too frequently
- Respects user's configured interval

## References
- `lua/llm/core/utils/shell.lua`: Update implementation
- `lua/llm/init.lua`: Auto-update trigger
- `plugin/llm.lua`: Manual update command
- `docs/features.md#auto-update-feature`: Feature documentation

---
*Date: 2025-02-11*
*Implemented: 2025-02-11*