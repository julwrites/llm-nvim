# TODO - Interactive Chat and Streaming Refactor

This document outlines the tasks required to implement an interactive chat feature and refactor existing commands to support streaming responses in `llm-nvim`.

## Feature Overview

When a user issues the `:LLM` command with no arguments, the plugin will open a special "chat" buffer for interactive conversation with the LLM. All responses from the LLM, both in chat and from other commands, will be streamed into a response buffer.

## Task Breakdown

### Phase 1: Core Infrastructure

#### 1. Asynchronous Job Runner (`lua/llm/core/utils/job.lua`)

-   **Goal:** Create a reusable utility for running external commands asynchronously and streaming their output.
-   **File:** `lua/llm/core/utils/job.lua`
-   **Function:** `run(cmd, on_line, on_exit)`
-   **Implementation:** Use `vim.fn.jobstart()` with `pty = true` and `stdout_buffered = false`. Implement a robust line-splitting mechanism.

#### 2. UI Enhancements for Streaming (`lua/llm/core/utils/ui.lua`)

-   **Goal:** Add a function to append content to a buffer and ensure it auto-scrolls.
-   **File:** `lua/llm/core/utils/ui.lua`
-   **Function:** `append_to_buffer(bufnr, lines)`
-   **Implementation:** Use `vim.api.nvim_buf_set_lines()` and `vim.api.nvim_win_set_cursor()` to append and scroll.

### Phase 2: Chat Feature Implementation

#### 3. Core Chat Logic (`lua/llm/chat.lua`)

-   **Goal:** Create the main module for the interactive chat feature.
-   **File:** `lua/llm/chat.lua`
-   **`start_chat()` function**: Create a scratch buffer `[LLM Chat]` with a `<leader>s` keymap to send the prompt.
-   **`send_prompt()` function**:
    -   Get prompt from the input buffer.
    -   Create a response buffer `LLM Chat Response` if it doesn't exist.
    -   Clear the response buffer.
    -   **Visual Separation:** Add "--- Prompt ---" and "--- Response ---" headers.
    -   Construct the `llm` command *without* `--stream`.
    -   Call `job.run()` with callbacks to append the response to the buffer.

### Phase 3: Refactor Existing Commands for Streaming

#### 4. Detailed Migration Plan for `lua/llm/commands.lua`

-   **Goal:** Update existing commands to use the new asynchronous job runner and stream responses.
-   **Primary Change:** Replace all calls to `llm_cli.run_llm_command` with the new `job.run` utility.

-   **Function `M.prompt(prompt, fragment_paths)`**:
    -   **Current:** Calls `llm_cli.run_llm_command` and displays the full result in a new buffer.
    -   **New:**
        1.  Create a response buffer using `ui.create_buffer_with_content("Waiting for response...", "LLM Response", "markdown")`.
        2.  Construct the command as a table of strings.
        3.  Call `job.run` with this command.
        4.  The `on_line` callback will call `ui.append_to_buffer` to stream the response into the created buffer. The first line received should replace the "Waiting for response..." message.
        5.  The `on_exit` callback can add a footer to the buffer.

-   **Function `M.llm_command_and_display_response(buf, cmd)`**:
    -   **Action:** This function will be **deleted**. Its logic will be integrated into the functions that call it.

-   **Function `M.execute_prompt_with_file(buffer, prompt, filepath, fragment_paths)`**:
    -   **Current:** Calls `M.llm_command_and_display_response`.
    -   **New:**
        1.  This function will now directly use `job.run`.
        2.  It will receive the response buffer handle `buffer` as an argument.
        3.  It will construct the `llm` command table, including the file path.
        4.  It will call `job.run` with callbacks.
        5.  The `on_line` callback will append the streamed response directly to the `buffer` passed into the function.

-   **Function `M.execute_prompt_async(...)`**:
    -   **Current:** Calls `M.execute_prompt_with_file` after getting user input.
    -   **New:** No significant changes needed. It will continue to call `M.execute_prompt_with_file`, which will now be streaming internally.

#### 5. Test Updates for `tests/spec/commands_spec.lua`

-   **Mocking:** Replace the mock for `llm_cli.run_llm_command` with a mock for `job.run`.
-   **Test `prompt`**:
    -   Assert that `job.run` is called with the correct command table.
    -   Simulate `job.run` callbacks.
    -   Assert that `ui.create_buffer_with_content` and `ui.append_to_buffer` are called.
-   **Test `execute_prompt_with_file`**:
    -   Assert that `job.run` is called.
    -   Simulate callbacks and assert that `ui.append_to_buffer` is called on the correct buffer.
-   **Remove Test**: Delete the test for the obsolete `llm_command_and_display_response` function.

### Phase 4: Integration and Finalization

#### 6. Command Dispatch (`plugin/llm.lua`)

-   **Goal:** Hook the chat feature into the `:LLM` command.
-   **File:** `plugin/llm.lua`
-   **Modification:** If `opts.args` is empty, call `require('llm.chat').start_chat()`.

#### 7. Documentation (`doc/llm.txt`)

-   **Goal:** Document the new features.
-   **File:** `doc/llm.txt`
-   **Content:** Document the interactive chat feature and the new streaming behavior of existing commands.

#### 8. Testing

-   **Goal:** Ensure all new and refactored functionality is working correctly.
-   **File:** `tests/spec/chat_spec.lua` (new) and `tests/spec/commands_spec.lua` (updated).
-   **Action:** Write tests for `chat.lua` and update tests for `commands.lua` as detailed in the migration plan.
