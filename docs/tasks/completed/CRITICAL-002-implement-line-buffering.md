# Task: Implement Proper Line Buffering in job.lua

## Task Information
- **Task ID**: CRITICAL-002
- **Status**: completed
- **Priority**: critical
- **Phase**: 1
- **Estimated Effort**: 1 day
- **Actual Effort**: 0.5 days
- **Completed**: 2025-02-11
- **Dependencies**: None

## Task Details

### Description
The `job.lua` module currently passes raw stdout chunks to callbacks without proper line buffering and splitting. This causes inconsistent streaming behavior and test failures.

### Problem Statement
When streaming LLM responses, data arrives in arbitrary chunks that may contain:
- Multiple complete lines: `"line1\nline2\n"`
- Partial lines: `"part"` followed by `"ial\n"`
- Mixed content: `"end of previous\nstart of next"`

The current implementation passes these chunks as-is, but consumers expect properly split, complete lines.

### Architecture Components
- **Core Utilities**: `lua/llm/core/utils/job.lua` - Async job execution
- **API Layer**: `lua/llm/api.lua` - Depends on job.lua for streaming
- **Commands Layer**: `lua/llm/commands.lua` - Uses streaming for all LLM interactions
- **Chat Module**: `lua/llm/chat.lua` - Relies on line-based filtering

### Feature Enablement
- **Streaming Output**: Ensures reliable line-by-line output processing
- **Chat Filtering**: Enables proper filtering of startup messages
- **Progress Indicators**: Allows line-based progress tracking

### Acceptance Criteria
- [x] Implement line buffering that accumulates partial lines
- [x] Split multi-line chunks on newline boundaries
- [x] Handle empty lines correctly
- [x] Pass complete lines to on_stdout callback
- [x] Flush remaining buffer content on job exit
- [x] All job_spec.lua tests pass: `make test file=core/utils/job_spec.lua`
- [x] No regressions in streaming functionality

### Implementation Notes

**Current Behavior** (lua/llm/core/utils/job.lua:16-20):
```lua
for _, chunk in ipairs(data) do
    vim.notify("job.lua: processing chunk for " .. event .. ", chunk length: " .. tostring(#chunk), vim.log.levels.DEBUG)
    handler(nil, {chunk})  -- Passes raw chunk
end
```

**Expected Behavior**:
```lua
-- Accumulate into buffer
stdout_buffer = stdout_buffer .. chunk

-- Split on newlines
local lines = {}
while true do
    local newline_pos = stdout_buffer:find('\n')
    if not newline_pos then break end
    
    table.insert(lines, stdout_buffer:sub(1, newline_pos - 1))
    stdout_buffer = stdout_buffer:sub(newline_pos + 1)
end

-- Pass complete lines to callback
if #lines > 0 then
    handler(nil, lines)
end
```

**Test Cases to Fix**:
1. Multiple lines in one chunk: `"line1\nline2\n"` → `{"line1", "line2"}`
2. Partial lines: `"part"` + `"ial\n"` → buffer → `{"partial"}`
3. Empty lines: `"\n"` → `{""}`

**Architecture Decision**:
Buffering at the job.lua level (not in individual callbacks) because:
1. Centralizes line handling logic
2. Prevents duplicate buffering in multiple consumers
3. Provides consistent line-based interface
4. Simplifies callback implementations

## Implementation Status

### Completed Work
- ✅ Added stdout_buffer and stderr_buffer variables (lua/llm/core/utils/job.lua:6-7)
- ✅ Implemented line splitting logic in process_output function (lines 16-49)
  - Accumulates chunks into buffer
  - Splits on newline boundaries
  - Extracts complete lines
  - Maintains buffer for partial lines
- ✅ Added buffer flushing in on_exit handler (lines 55-69)
  - Processes remaining stdout buffer
  - Processes remaining stderr buffer
  - Ensures no data loss
- ✅ All 3 job_spec.lua test failures resolved
- ✅ Full test suite: 178 successes / 2 failures / 0 errors (up from 173/3/4)

### Implementation Details

**Line Buffering Algorithm**:
```lua
local buffer = buffer .. chunk  -- Accumulate

while true do
  local newline_pos = buffer:find('\n')
  if not newline_pos then break end
  
  local line = buffer:sub(1, newline_pos - 1)  -- Extract line
  table.insert(lines, line)
  buffer = buffer:sub(newline_pos + 1)  -- Remove from buffer
end

if #lines > 0 then
  handler(nil, lines)  -- Pass complete lines
end
```

### Test Results

**Before**: 
- Test 1: Expected `{'line1', 'line2'}`, got `{'line1\nline2\n'}`
- Test 2: Expected 1 call, got 2 calls (partial lines not buffered)
- Test 3: Expected `{''}`, got `{'\n'}` (newline not stripped)

**After**: All tests pass ✅

### Git History
- Commit: Implement proper line buffering in job.lua

### Notes
- Completed faster than estimated (half day vs full day)
- Both stdout and stderr buffering implemented
- Handles edge cases (empty lines, partial lines, multi-line chunks)
- No performance impact - buffering is minimal overhead

---

*Created: 2025-02-11*
*Completed: 2025-02-11*
*Status: completed - Streaming output now reliable across all LLM commands*
