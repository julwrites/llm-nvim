# ADR-004: Temporary Files for Visual Selection

## Status
Accepted

## Context
The `:LLM selection` command needs to pass visually selected text to the llm CLI tool. The llm CLI accepts input via:
1. Standard input (piped content)
2. File fragments (`-f` flag)
3. Command-line arguments (for short prompts)

Visual selections can contain:
- Multi-line text
- Special characters requiring escaping
- Large amounts of code
- Mixed quotes and shell metacharacters

We needed a reliable way to pass arbitrary selection content to llm CLI without:
- Shell escaping issues
- Command-line length limits
- Character encoding problems

## Decision
Write visual selection to a temporary file and pass it as a fragment argument.

**Implementation**:
```lua
-- In commands.lua
function M.prompt_with_selection(prompt, fragment_paths, from_visual_mode, bufnr)
  local selection = text.get_visual_selection()
  local temp_file = os.tmpname()  -- Create temp file
  
  local file = io.open(temp_file, "w")
  file:write(selection)
  file:close()
  
  -- Add temp file as fragment
  table.insert(cmd_parts, "-f")
  table.insert(cmd_parts, vim.fn.shellescape(temp_file))
  
  -- Clean up on exit
  callbacks.on_exit = function()
    os.remove(temp_file)
  end
end
```

## Consequences

### Positive
- **Consistent with fragment system**: Uses same `-f` mechanism as other fragments
- **No escaping issues**: File content is never shell-parsed
- **No length limits**: Can handle selections of any size
- **Character safety**: All Unicode and special chars handled correctly
- **Simple implementation**: Straightforward file I/O
- **Debuggable**: Temp file can be inspected if issues occur

### Negative
- **File I/O overhead**: Writing to disk adds slight latency
- **Cleanup required**: Must ensure temp file deletion
- **Disk space**: Uses temporary disk space
- **File system dependency**: Requires working temp directory
- **Race conditions**: Theoretically possible with concurrent selections

## Alternatives Considered

### Alternative 1: Send via stdin
Pipe selection directly to llm process.

**Rejected because**:
- llm CLI expects stdin for the main prompt, not context
- Cannot combine stdin prompt with stdin selection
- Would conflict with fragment system
- More complex process management

### Alternative 2: Shell escaping
Escape selection and pass as command argument.

**Rejected because**:
- Shell escaping is error-prone for arbitrary text
- Command-line length limits (typically 128KB-2MB)
- Complex escaping rules for quotes, newlines, etc.
- Different escaping rules for different shells
- Risk of command injection if escaping fails

### Alternative 3: Named pipe (FIFO)
Use a named pipe to stream content.

**Rejected because**:
- More complex to implement correctly
- Platform-specific behavior (Windows vs Unix)
- No significant benefit over temp file
- Harder to debug

### Alternative 4: In-memory file descriptor
Use `/dev/stdin` or process substitution.

**Rejected because**:
- Not portable across platforms
- Requires shell features not available everywhere
- More complex cleanup logic

## Implementation Details

**Temp file creation**:
- `os.tmpname()`: Uses OS temp directory
- Platform-specific paths (e.g., `/tmp/lua_XXXXXX`)
- Unique filename guaranteed by OS

**Cleanup strategy**:
```lua
on_exit = function()
  vim.notify("LLM command finished.")
  os.remove(temp_file)  -- Synchronous deletion
end
```

**Error handling**:
- If file write fails: Error notification, no command sent
- If deletion fails: Logged but not fatal (OS will clean temp dir)
- If temp dir unavailable: Falls back to current directory

**Edge cases**:
- Empty selection: Creates empty temp file (valid)
- Large selection: Limited only by available disk space
- Concurrent selections: Each gets unique temp file
- Plugin crash: OS eventually cleans temp directory

## Performance Impact

**Benchmark** (informal testing):
- Selection < 1KB: <1ms overhead
- Selection 1-100KB: 1-5ms overhead  
- Selection > 100KB: 5-20ms overhead

This is negligible compared to LLM API response time (100ms-10s).

## References
- Implementation: `lua/llm/commands.lua:295-344`
- Text extraction: `lua/llm/core/utils/text.lua:get_visual_selection()`
- Architecture doc: `docs/architecture.md` - "Visual Selection Handling"
- Related: Fragment management system

---
*Date: 2025-02-11*
*Status: Accepted - Production-ready and battle-tested*
