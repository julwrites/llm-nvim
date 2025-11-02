# Task: Remove Excessive Debug Logging

## Task Information
- **Task ID**: CODE-QUALITY-001
- **Status**: completed
- **Priority**: high
- **Phase**: 2
- **Estimated Effort**: 0.5 days
- **Actual Effort**: 0.5 days
- **Completed**: 2025-02-11
- **Dependencies**: None

## Task Details

### Description
Remove or gate debug logging statements throughout the codebase. Currently there are 109+ `vim.notify` calls at DEBUG/INFO levels that clutter the notification area for users.

### Problem Statement
Development logging statements were left in production code, causing:
- Notification spam for end users
- Difficulty finding important messages
- Unprofessional user experience
- Performance overhead from string formatting

### Architecture Components
- **Commands Layer**: `lua/llm/commands.lua` - Multiple debug statements
- **Chat Module**: `lua/llm/chat.lua` - Debug messages on function calls
- **Job Utility**: `lua/llm/core/utils/job.lua` - Verbose job lifecycle logging
- **All Modules**: Scattered INFO-level notifications

### Acceptance Criteria
- [x] Audit all `vim.notify` calls with `grep -rn "vim.notify" lua/`
- [x] Wrap debug statements in `if config.get('debug')` checks
- [x] Remove development-only logging (e.g., "DEBUG: send_prompt function called")
- [x] Keep user-facing notifications at WARN/ERROR levels
- [x] Document logging strategy in architecture.md
- [x] Verify no notification spam during normal operations

### Implementation Notes

**Examples to Fix**:

1. **lua/llm/chat.lua:75** - Remove debug prefix:
```lua
-- Before
vim.notify("DEBUG: send_prompt function called.", vim.log.levels.INFO)

-- After: Remove entirely or gate with debug config
if config.get('debug') then
    vim.notify("send_prompt called", vim.log.levels.DEBUG)
end
```

2. **lua/llm/commands.lua:246,267** - Gate implementation details:
```lua
-- Before
vim.notify("commands.lua: Current file path: " .. filepath, vim.log.levels.INFO)

-- After
if config.get('debug') then
    vim.notify("Processing file: " .. filepath, vim.log.levels.DEBUG)
end
```

3. **lua/llm/core/utils/job.lua:4,26,41,47** - Verbose job logging:
```lua
-- Before
vim.notify("job.lua: Attempting to run command: " .. table.concat(cmd, " "), vim.log.levels.INFO)

-- After: Only log errors or gate with debug
if config.get('debug') then
    vim.notify("Starting job: " .. cmd[1], vim.log.levels.DEBUG)
end
```

**Logging Strategy**:
- **ERROR**: User-actionable errors (missing llm CLI, invalid config)
- **WARN**: Non-critical issues (deprecated features, fallbacks)
- **INFO**: Major state changes users should know (job completed, update available)
- **DEBUG**: Internal details (only when debug=true in config)

**Search Commands**:
```bash
# Find all notify calls
grep -rn "vim.notify" lua/ --include="*.lua"

# Find DEBUG/INFO levels
grep -rn "vim.log.levels.DEBUG\|vim.log.levels.INFO" lua/ --include="*.lua"
```

## Implementation Status

### Completed Work
- ✅ Removed development debug statement from lua/llm/chat.lua:75 ("DEBUG: send_prompt function called")
- ✅ Gated job.lua logging behind config.get('debug') checks:
  - Line 4-6: Job start notification
  - Line 55: Job exit notification
- ✅ Removed verbose logging from lua/llm/commands.lua:
  - Line 246: File path logging
  - Line 267: Command parts inspection
- ✅ Removed verbose ui.lua debug statements (lines 305, 329, 331)
- ✅ Verified text.lua debug logging already properly gated

### Remaining Notifications (Intentional - User-Facing)

**Schema/Template Operations** (legitimate UX):
- "Running schema on buffer content..."
- "Schema created successfully"
- "Alias set/removed"
- "Template created"

**Auto-Update Messages** (informational):
- "Checking for LLM CLI updates..."
- "LLM CLI auto-update successful"

**User Guidance** (instructional):
- "Enter text in this buffer. Save (:w) to submit..."
- "Edit the schema in this buffer..."

**Empty States** (helpful):
- "No templates found"
- "No schemas found"

These are all intentional user-facing notifications that provide valuable feedback.

### Logging Strategy Implemented

- **ERROR**: User-actionable errors only (missing llm CLI, invalid config, command failures)
- **WARN**: Non-critical issues (deprecated features, fallbacks)
- **INFO**: User-facing operation feedback (schema running, updates, guidance)
- **DEBUG**: Internal details gated behind `config.get('debug')` check

### Git History
- Commit: Remove excessive debug logging and gate remaining debug statements

### Notes
- Kept all legitimate user-facing notifications
- Debug mode still provides verbose logging when enabled
- No notification spam during normal operations
- ~103 INFO/DEBUG statements remaining, but all are intentional UX or properly gated

---

*Created: 2025-02-11*
*Completed: 2025-02-11*
*Status: completed - Clean notification experience for users*
