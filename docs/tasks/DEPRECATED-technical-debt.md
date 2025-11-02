# Technical Debt

This document tracks known technical debt items that should be addressed to improve code quality, maintainability, and reliability.

## Critical Issues

### Fix Lua 5.2+ compatibility: Replace `unpack` with `table.unpack` in chat.lua

**File**: `lua/llm/chat.lua:77`

**Issue**: Code uses global `unpack` which was removed in Lua 5.2 and replaced with `table.unpack`. This breaks all chat functionality.

**Current code**:
```lua
local current_cursor_line, _ = unpack(vim.api.nvim_win_get_cursor(0))
```

**Fix**:
```lua
local current_cursor_line, _ = table.unpack(vim.api.nvim_win_get_cursor(0))
```

**Impact**: High - All chat commands fail with "attempt to call a nil value (global 'unpack')"

**Testing**: Run `make test file=chat_spec.lua` to verify fix

---

### Implement proper line buffering and splitting in job.lua

**File**: `lua/llm/core/utils/job.lua`

**Issue**: Current implementation passes raw stdout chunks to callbacks instead of properly buffering and splitting into complete lines. This causes inconsistent behavior when streaming output.

**Expected behavior**:
- Multi-line chunks like `"line1\nline2\n"` should be split into `{"line1", "line2"}`
- Partial lines should be buffered until a newline is received
- Empty lines should be handled correctly

**Current behavior**: Passes chunks as-is: `{chunk}` without any line splitting

**Impact**: Medium - Tests fail, streaming output may be unreliable

**Testing**: Run `make test file=core/utils/job_spec.lua` to verify fix

---

## Code Quality Issues

### Remove excessive debug logging statements

**Files**: Throughout codebase (109 occurrences)

**Issue**: Many `vim.notify` statements with DEBUG and INFO levels that should be controlled by the `debug` config option or removed entirely.

**Examples**:
- `lua/llm/chat.lua:75`: `vim.notify("DEBUG: send_prompt function called.", vim.log.levels.INFO)`
- `lua/llm/commands.lua:246`: `vim.notify("commands.lua: Current file path: " .. filepath, vim.log.levels.INFO)`
- `lua/llm/commands.lua:267`: `vim.notify("commands.lua: cmd_parts for file command: " .. vim.inspect(cmd_parts), vim.log.levels.INFO)`

**Fix**: 
1. Wrap debug statements in `if config.get('debug')` checks
2. Remove development-only logging statements
3. Keep only user-facing notifications at WARN/ERROR levels

**Impact**: Low - Clutters notification area for users

---

### Consolidate duplicate :LLMChat command registration

**File**: `plugin/llm.lua`

**Issue**: The `:LLMChat` command is registered twice (lines 109-122 and 160-172) with identical implementations.

**Fix**: Remove one of the duplicate registrations

**Impact**: Low - Currently harmless but confusing for maintenance

---

### Remove unused validate_view_name function

**File**: `plugin/llm.lua:126-145`

**Issue**: Function `validate_view_name` is defined but never used anywhere in the codebase.

**Fix**: Either use it for view validation or remove it

**Impact**: Low - Dead code

---

### Deprecate or remove unused run_llm_command function

**File**: `lua/llm/api.lua:37-51`

**Issue**: Function `M.run_llm_command` exists alongside `M.run_streaming_command` but uses different callback structure and isn't called anywhere.

**Fix**: 
1. Search for any usage
2. If unused, mark as deprecated or remove
3. If used, document the difference from `run_streaming_command`

**Impact**: Low - Potential maintenance burden

---

## Testing Issues

### Audit entire codebase for Lua 5.1 vs 5.2+ compatibility

**Files**: All Lua files

**Issue**: The `unpack` issue was found in chat.lua. There may be other Lua version compatibility issues lurking.

**Known differences to check**:
- `unpack` vs `table.unpack`
- `loadstring` vs `load`
- `module()` function (removed)
- `setfenv`/`getfenv` (removed)
- `table.maxn` (removed)

**Fix**: Systematic grep/audit for deprecated Lua 5.1 functions

**Impact**: Medium - Prevents future compatibility issues

---

### Add CI/CD pipeline for automated testing

**Files**: New `.github/workflows/` directory

**Issue**: No automated testing on commits/PRs. Issues like the `unpack` bug could be caught automatically.

**Fix**: Add GitHub Actions workflow to:
1. Run test suite on push/PR
2. Test on multiple Lua versions (5.1, 5.2, 5.3, 5.4, LuaJIT)
3. Lint code with luacheck
4. Report coverage

**Impact**: Medium - Improves code quality and prevents regressions

---

## Documentation Issues

### Document minimum Lua version requirement

**Files**: `README.md`, `docs/features.md`, `AGENTS.md`

**Issue**: No explicit documentation of which Lua version is required. Based on code using `table.unpack`, requires Lua 5.2+.

**Fix**: Add to Requirements section:
- Lua 5.2 or later (or LuaJIT 2.1+)
- Note: Neovim bundles LuaJIT which is compatible

**Impact**: Low - Helps users troubleshoot compatibility issues

---

### Add architectural decision record (ADR) for streaming implementation

**Files**: `docs/architecture.md` or new `docs/adr/` directory

**Issue**: The streaming implementation went through a refactoring (per tasks.md) but the reasoning and trade-offs aren't fully documented.

**Fix**: Document:
- Why unified streaming was chosen
- Alternative approaches considered
- Trade-offs made
- Future considerations

**Impact**: Low - Helps future maintainers understand design decisions

---

## Performance Issues

### Implement caching for repeated llm CLI calls

**Files**: `lua/llm/managers/*.lua`

**Issue**: Manager modules make repeated calls to `llm models list`, `llm plugins list`, etc. which could be cached.

**Current**: `lua/llm/core/data/cache.lua` exists but may not be fully utilized

**Fix**: 
1. Audit which CLI calls are repeated frequently
2. Implement TTL-based caching
3. Add cache invalidation on relevant operations

**Impact**: Low - Improves responsiveness of manager UI

---

## Priority Summary

**Critical** (blocking functionality):
1. Fix `unpack` → `table.unpack` in chat.lua
2. Implement line buffering in job.lua

**High** (quality/maintainability):
3. Remove excessive debug logging
4. Audit Lua version compatibility

**Medium** (nice to have):
5. Add CI/CD pipeline
6. Remove duplicate command registration
7. Document Lua version requirement

**Low** (cleanup):
8. Remove unused validate_view_name function
9. Review run_llm_command usage
10. Add ADR documentation
11. Implement caching optimization
