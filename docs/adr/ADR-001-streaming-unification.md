# ADR-001: Unified Streaming Command Execution

## Status
Accepted

## Context
Multiple command types in llm-nvim needed to execute llm CLI commands with streaming output:
- Basic prompts (`:LLM`)
- File-based prompts (`:LLM file`)
- Selection-based prompts (`:LLM selection`)
- Chat sessions (`:LLMChat`)

Each command type had different requirements:
- Different command arguments (model, system prompt, fragments, continue flag)
- Different output handling (filtering, formatting, buffer management)
- Different cleanup needs (temp files, state tracking)

Initially, there were multiple implementations with duplicated streaming logic, making the code harder to maintain and extend.

## Decision
Create a single unified streaming function `api.run_streaming_command()` that:
1. Accepts command parts as a table
2. Takes a prompt string to send via stdin
3. Receives callbacks for stdout, stderr, and exit events
4. Handles job creation and process management
5. Allows commands to define their own callback behavior

**Signature**:
```lua
api.run_streaming_command(cmd_parts, prompt, callbacks)
  -- cmd_parts: table like {'/usr/bin/llm', '-m', 'gpt-4', '-s', 'system prompt'}
  -- prompt: string to send to stdin
  -- callbacks: {on_stdout, on_stderr, on_exit}
```

## Consequences

### Positive
- **DRY (Don't Repeat Yourself)**: Streaming logic exists in one place
- **Flexibility**: Commands customize behavior via callbacks
- **Testability**: Easy to mock and test callbacks independently
- **Maintainability**: Bug fixes apply to all commands
- **Extensibility**: New commands just define their callbacks
- **Consistency**: All commands use the same streaming infrastructure

### Negative
- **Callback-based design**: Requires understanding callback pattern
- **Indirection**: Flow is less obvious than inline code
- **Debugging**: Stack traces go through callback layers

## Alternatives Considered

### Alternative 1: Separate streaming functions per command type
**Rejected because**: Led to code duplication, inconsistent behavior, and higher maintenance burden.

### Alternative 2: Class-based OOP approach
**Rejected because**: Lua's simple module system is more idiomatic; OOP adds unnecessary complexity for this use case.

### Alternative 3: Coroutine-based streaming
**Rejected because**: More complex to implement and test; callbacks are well-understood pattern in Neovim ecosystem.

## Implementation Details

**File**: `lua/llm/api.lua:53-69`

**Line buffering**: Implemented in `lua/llm/core/utils/job.lua` to ensure callbacks receive complete lines, not raw chunks (see CRITICAL-002).

**Callback contract**:
- `on_stdout(job_id, lines)`: Receives array of complete lines
- `on_stderr(job_id, lines)`: Receives array of error lines  
- `on_exit(job_id, exit_code)`: Called when process completes

## References
- Implementation: `lua/llm/api.lua`
- Job runner: `lua/llm/core/utils/job.lua`
- Task: `docs/history.md` - "Unify LLM Streaming Logic"
- Related: CRITICAL-002 (line buffering implementation)

---
*Date: 2025-02-11*
*Status: Accepted - Implemented and tested*
