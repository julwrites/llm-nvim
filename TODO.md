# TODO - Implement interactive chat feature

This document outlines the tasks required to implement an interactive chat feature in `llm-nvim`.

## Feature Overview

The goal is to add a new command `:LLM` (with no arguments) that opens a scratch buffer for interactive chat with the default LLM model.

## Task Breakdown

### 1. Update Command Handling

*   **File:** `plugin/llm.lua`
*   **Task:** Modify the `:LLM` command to handle the case where no arguments are provided.
*   **Sub-tasks:**
    *   In the `LLM` command's function, check if `opts.args` is empty.
    *   If it's empty, call a new function, e.g., `require('llm.chat').start_chat()`.
    *   Update the command's `complete` function to not suggest subcommands when the command is empty.

### 2. Create a New Chat Module

*   **File:** `lua/llm/chat.lua` (new file)
*   **Task:** Create a new module to manage the chat functionality.
*   **Sub-tasks:**
    *   Create a `start_chat` function that:
        *   Opens a new scratch buffer with a unique name (e.g., `llm-chat-<timestamp>`).
        *   Sets the buffer's filetype to `markdown` for syntax highlighting.
        *   Sets up key mappings for the chat buffer (e.g., `<CR>` to send the current line as a prompt).
        *   Displays an initial welcome message.
    *   Create a `send_prompt` function that:
        *   Takes the user's input from the chat buffer.
        *   Calls the `llm` CLI with the input.
        *   Appends the user's prompt and the LLM's response to the chat buffer.
        *   Handles errors gracefully.

### 3. Implement Chat Buffer Logic

*   **File:** `lua/llm/chat.lua`
*   **Task:** Implement the core logic for the chat buffer.
*   **Sub-tasks:**
    *   **Buffer creation:**
        *   Use `vim.api.nvim_create_buf(true, true)` to create a scratch buffer.
        *   Set buffer options: `bufhidden=hide`, `swapfile=false`, `buftype=nofile`.
    *   **Key mappings:**
        *   Map `<CR>` in insert mode to a function that sends the current line to the LLM.
        *   Consider adding other mappings, e.g., for clearing the buffer or closing the chat.
    *   **Prompt handling:**
        *   When the user presses `<CR>`, get the current line.
        *   Append the user's prompt to the buffer, formatted as a markdown blockquote.
        *   Call the `llm` CLI asynchronously.
        *   Append the LLM's response to the buffer.
        *   Ensure the buffer scrolls to the end after each message.

### 4. Update Documentation

*   **File:** `README.md`
*   **Task:** Document the new interactive chat feature.
*   **Sub-tasks:**
    *   Add a section describing the `:LLM` command with no arguments.
    *   Explain how to use the chat feature.
    *   Update the command reference.
*   **File:** `doc/llm.txt`
*   **Task:** Update the Vim help file.
*   **Sub-tasks:**
    *   Add documentation for the new chat feature.

### 5. Add Tests

*   **File:** `test/spec/llm_spec.lua`
*   **Task:** Add tests for the new chat feature.
*   **Sub-tasks:**
    *   Write a test to verify that `:LLM` with no arguments opens a chat buffer.
        *   This test should check that a new buffer is created with a name that starts with `llm-chat-`.
    *   Write a test to verify that sending a prompt in the chat buffer works as expected.
        *   This test should mock the `llm` CLI to avoid making actual API calls.
        *   It should check that the user's prompt and the mocked response are correctly appended to the chat buffer.
    *   Write a test to verify that the key mappings in the chat buffer work as expected.
        *   This test should simulate the user pressing `<CR>` in insert mode and verify that the `send_prompt` function is called.

## Testing Strategy

*   **Unit tests:** Use `plenary.nvim` and `busted` to write unit tests for the new `chat.lua` module.
    *   The tests will be located in the `test/spec` directory.
    *   The tests will be run using the `make test` command.
*   **Integration tests:** Write integration tests to ensure the `:LLM` command works correctly and interacts with the chat module as expected.
*   **Manual testing:**
    *   Open Neovim and run `:LLM`.
    *   Verify that a new chat buffer opens with a unique name.
    *   Enter a prompt and press Enter.
    *   Verify that the prompt and the LLM's response appear in the buffer.
    *   Test edge cases, such as empty prompts or errors from the `llm` CLI.
    *   Verify that the key mappings for closing the chat window work as expected.
