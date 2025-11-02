# ADR-002: LLM CLI Native Conversation Management

## Status
Accepted

## Context
The `:LLMChat` command needed to maintain conversation history across multiple prompts. Without proper conversation management:
- Each prompt would be treated as a new conversation
- Previous context would be lost
- Users couldn't have multi-turn conversations
- The plugin would need to reimplement conversation storage

The llm CLI tool (by Simon Willison) provides built-in conversation management via:
- Automatic conversation storage
- `--continue` flag to resume previous conversation
- Conversation history tracking
- Conversation listing and management

We needed to decide: implement our own conversation management, or leverage llm CLI's native capabilities?

## Decision
Use llm CLI's built-in conversation management with the `--continue` flag.

**Implementation**:
1. Track chat state with buffer-local variable `vim.b.llm_chat_is_continuing`
2. On first prompt in a chat: Send without `--continue` (starts new conversation)
3. On subsequent prompts: Add `--continue` flag to command
4. Send prompts via stdin only (not as command-line arguments)
5. Let llm CLI handle all conversation storage and retrieval

**Code** (`lua/llm/chat.lua`):
```lua
local cmd_parts = { llm_path }
-- Add model and system args
if vim.b.llm_chat_is_continuing then
  table.insert(cmd_parts, '--continue')
end
vim.b.llm_chat_is_continuing = true
```

## Consequences

### Positive
- **No reimplementation**: Leverage existing, tested llm CLI feature
- **Consistency**: Same conversation storage as standalone llm CLI
- **Features for free**: Get conversation listing, deletion, etc. from llm
- **Simplicity**: No conversation database management in plugin
- **Reliability**: llm CLI handles edge cases (concurrent access, corruption, etc.)
- **Interoperability**: Conversations can be continued from command line

### Negative
- **Dependency**: Relies on llm CLI's conversation management
- **API coupling**: If llm CLI changes conversation handling, we must adapt
- **Limited control**: Can't customize conversation storage format
- **External state**: Conversation data stored outside plugin control

## Alternatives Considered

### Alternative 1: Plugin-managed conversation storage
Store conversations in Neovim data directory with custom format.

**Rejected because**:
- Would duplicate llm CLI's functionality
- More code to maintain and test
- Risk of inconsistency with standalone llm usage
- Need to handle storage edge cases ourselves

### Alternative 2: Pass full history as context
On each prompt, send entire conversation history.

**Rejected because**:
- Inefficient for long conversations
- Loses llm CLI's conversation features
- Would hit token limits faster
- Reimplements what `--continue` already does

### Alternative 3: Hybrid approach
Store conversation IDs, fetch history on demand.

**Rejected because**:
- Added complexity with minimal benefit
- Still coupled to llm CLI's conversation system
- More failure modes to handle

## Implementation Details

**State tracking**:
- `vim.b.llm_chat_is_continuing`: Per-buffer boolean
- `nil` = new conversation, `true` = continuing

**Prompt flow**:
1. User types in chat buffer
2. `send_prompt()` extracts text from buffer
3. Builds command with `--continue` if appropriate
4. Sends prompt to stdin via `jobsend()`
5. Sets `llm_chat_is_continuing = true`

**Edge cases handled**:
- Buffer deletion clears state automatically (buffer-local variable)
- New chat buffer starts fresh (nil state)
- Multiple concurrent chats work independently (per-buffer state)

## References
- Implementation: `lua/llm/chat.lua`
- llm CLI docs: https://llm.datasette.io/en/stable/logging.html
- Task: `docs/history.md` - "Fix :LLMChat Conversation Handling"
- Related: ADR-001 (uses streaming command execution)

---
*Date: 2025-02-11*
*Status: Accepted - Implemented and tested*
