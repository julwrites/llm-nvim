# Task: Redesign and Fix Chat Feature

## Task Information
- **Task ID**: CRITICAL-003
- **Status**: pending
- **Priority**: Critical (P0)
- **Phase**: 5
- **Effort Estimate**: 12-16 hours
- **Dependencies**: None

## Task Details
### Description
The current chat implementation is unstable, with multiple test failures and a user experience that does not match the capabilities of the `llm` CLI. This task is to completely redesign and rewrite the chat functionality to be robust, stable, and feature-rich, using the proposed architecture outlined in this document.

### Problem Analysis
The current implementation suffers from several critical issues:
1.  **Failing Tests**: The `tests/spec/chat_spec.lua` test suite has multiple failures related to command building, state management, and mocking.
2.  **Brittle State Management**: State is spread across multiple locations, making it difficult to track and prone to errors.
3.  **Mismatched Command Strategy**: The implementation attempts to use the interactive `llm chat` command in a non-interactive way, leading to unpredictable behavior.
4.  **Missing Advanced Features**: The `llm` CLI's chat mode supports multi-line input, editing prompts in an external editor, and adding fragments on the fly, none of which are implemented.

### Architecture Components Affected
- `lua/llm/chat.lua` - Complete rewrite needed.
- `lua/llm/chat/session.lua` - To be created or rewritten.
- `lua/llm/chat/buffer.lua` - To be created or rewritten.
- `tests/spec/chat_spec.lua` - Complete rewrite of tests for the new architecture.

### Acceptance Criteria
- [ ] All tests in `tests/spec/chat_spec.lua` must pass.
- [ ] Chat sessions successfully send prompts and display LLM responses in a streaming manner.
- [ ] Conversation history is maintained across multiple prompts in a session.
- [ ] A clear visual separation exists between the conversation history and the user input area.
- [ ] The "send" keymap is only active in the designated input area to prevent accidental submissions.
- [ ] The UI provides clear status indicators for "ready", "processing", and "error" states.
- [ ] **Advanced Feature**: Users can enter multi-line input in the chat prompt.
- [ ] **Advanced Feature**: Users can open the current prompt in an external editor (e.g., `!edit`).
- [ ] **Advanced Feature**: Users can add fragments to the conversation on the fly (e.g., `!fragment`).
- [ ] The implementation is well-documented and includes debug logging.

### Implementation Notes
The implementation should follow the "Proposed Architecture" below, which was previously defined but not fully realized.

#### Proposed Architecture
**Strategy: Use `llm prompt` with conversation IDs instead of `llm chat`**
- Use `llm prompt` for each message.
- Track the conversation ID for the session.
- Use the `-c/--continue` flag for follow-up messages.
- Build a custom chat UI that is native to Neovim.

**Key Components**:
1.  **Chat Session Manager** (`lua/llm/chat/session.lua`): Manages the state of a single chat session, including the conversation ID, model, and system prompt. It will be responsible for building and executing the `llm prompt` commands.
2.  **Chat Buffer Manager** (`lua/llm/chat/buffer.lua`): Manages the UI of the chat buffer, including the header, conversation history, and input area. It will also handle the keymaps for sending messages and other actions.
3.  **Chat Orchestrator** (`lua/llm/chat.lua`): The main entry point for the chat feature, responsible for creating and managing the session and buffer.

## Implementation Status
- **Completed Work**: None
- **Current Blockers**: The existing implementation is broken and needs to be replaced.
- **Remaining Work**:
  - Implement the `ChatSession` and `ChatBuffer` modules as described in the proposed architecture.
  - Rewrite `lua/llm/chat.lua` to orchestrate the new modules.
  - Rewrite `tests/spec/chat_spec.lua` to test the new implementation.
  - Implement the advanced chat features.

## Git History
- *No commits yet*

---
*Created: 2025-11-14*
*Last updated: 2025-11-14*
