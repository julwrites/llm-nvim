# Task: Implement Caching for Manager LLM CLI Calls

## Task Information
- **Task ID**: PERFORMANCE-001
- **Status**: completed

### Investigation Summary (2025-11-16)
This task was verified as **Implemented (without explicit TTL configuration)**.
- The `cache.lua` module is used in manager files to store and retrieve results of `llm_cli.run_llm_command`.
- `lua/llm/managers/models_manager.lua` demonstrates the use of `cache.get()`, `cache.set()`, and `cache.invalidate()`.
- There is no explicit cache TTL configuration in `lua/llm/config.lua`.

- **Priority**: low
- **Phase**: 4
- **Estimated Effort**: 1 day
- **Dependencies**: None

## Task Details

### Description
Implement TTL-based caching for frequently-called llm CLI commands in manager modules to improve responsiveness of the unified manager UI.

### Problem Statement
Manager modules make repeated calls to commands like:
- `llm models list` - Every time models view is opened
- `llm plugins list` - Every time plugins view is opened  
- `llm keys` - Every time keys view is opened

These calls can be slow (100-500ms each) and the data rarely changes within a session. A caching layer would significantly improve UI responsiveness.

### Architecture Components
- **Core Data**: `lua/llm/core/data/cache.lua` - Existing but underutilized
- **Managers**: `lua/llm/managers/*_manager.lua` - Cache consumers
- **Shell Utilities**: `lua/llm/core/utils/shell.lua` - Could benefit from caching

### Acceptance Criteria
- [x] Audit existing cache.lua implementation
- [x] Identify frequently-called CLI commands in managers
- [ ] Implement TTL-based cache wrapper for shell.run_command
- [x] Add cache invalidation on write operations (install, set, etc.)
- [ ] Add config option for cache TTL (default: 60 seconds)
- [ ] Test cache hit/miss behavior
- [ ] Measure performance improvement
- [ ] Document caching strategy in architecture.md

### Implementation Status
A basic, persistent caching mechanism has been implemented in `lua/llm/core/data/cache.lua` and is used by managers like `models_manager.lua`. This implementation covers cache getting, setting, and invalidation.

However, the more advanced **Time-to-Live (TTL)** functionality is missing. The current cache is persistent and does not expire. The acceptance criteria for a `cache_ttl` configuration option and the TTL logic itself are not yet met. The task is therefore considered partially complete.

### Implementation Notes

**Current Cache Module**: `lua/llm/core/data/cache.lua` exists but may need enhancement for this use case.

**Commands to Cache**:
```lua
-- High-frequency, read-only operations
"llm models list"           -- Cache for 60s
"llm plugins list"          -- Cache for 60s  
"llm keys"                  -- Cache for 30s (more sensitive)

-- Cache invalidation on:
"llm models set"            -- Invalidate models cache
"llm plugins install"       -- Invalidate plugins cache
"llm keys set"              -- Invalidate keys cache
```

**Cache Wrapper Pattern**:
```lua
-- In shell.lua or new cached_shell.lua
local cache = require('llm.core.data.cache')
local config = require('llm.config')

function M.run_command_cached(cmd, ttl)
  ttl = ttl or config.get('cache_ttl') or 60
  local cache_key = table.concat(cmd, ' ')
  
  local cached = cache.get(cache_key)
  if cached and (os.time() - cached.timestamp) < ttl then
    return cached.result
  end
  
  local result = shell.run_command(cmd)
  cache.set(cache_key, {
    result = result,
    timestamp = os.time()
  })
  
  return result
end
```

**Cache Invalidation**:
```lua
-- In managers after write operations
function models_manager.set_default_model(model)
  -- ... set model ...
  cache.invalidate_pattern("llm models")
end
```

**Configuration**:
```lua
-- In config.lua defaults
cache_enabled = {
  default = true,
  type = "boolean",
  desc = "Enable caching of llm CLI responses"
},
cache_ttl = {
  default = 60,
  type = "number",
  desc = "Cache time-to-live in seconds"
}
```

**Performance Measurement**:
```bash
# Before caching
time llm models list  # ~200ms

# After caching (hit)
time llm models list  # ~5ms (from cache)
```

**Trade-offs**:
- **Pro**: Much faster UI, better UX
- **Pro**: Reduces llm CLI load
- **Con**: Stale data if models change externally
- **Con**: Additional memory usage (minimal)
- **Con**: Cache invalidation complexity

---

*Created: 2025-02-11*
*Status: pending - Nice-to-have performance optimization*
