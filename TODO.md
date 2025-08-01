# TODO - TDD-Focused Interactive Chat and Streaming Refactor

This document outlines the tasks required to implement an interactive chat feature and refactor existing commands to support streaming responses in `llm-nvim`, following a strict Test-Driven Development (TDD) methodology.

## TDD-Focused Implementation Plan

This plan is structured to follow the Red-Green-Refactor cycle for each piece of functionality.

### Phase 1: Core Infrastructure

**1. Asynchronous Job Runner (`job.lua`)**
-   **DONE: 1a. Red:** Write a failing test in a new `tests/spec/job_spec.lua` that calls `job.run` and asserts that `vim.fn.jobstart` is called with the correct parameters.
-   **DONE: 1b. Green:** Create `lua/llm/core/utils/job.lua` and implement the `run` function with the minimum code required to make the test pass.
-   **DONE: 1c. Refactor:** Refine the `job.run` function and its tests. Add tests for the line-splitting logic in the `on_stdout` callback, ensuring it handles partial lines and different line endings correctly.

**2. UI Enhancements for Streaming (`ui.lua`)**
-   **DONE: 2a. Red:** Write a failing test in a new `tests/spec/ui_spec.lua` (or an existing one if appropriate) that calls `ui.append_to_buffer` and asserts that `vim.api.nvim_buf_set_lines` and `vim.api.nvim_win_set_cursor` are called.
-   **DONE: 2b. Green:** Implement the `append_to_buffer` function in `lua/llm/core/utils/ui.lua` to make the test pass.
-   **DONE: 2c. Refactor:** Clean up the code and add any additional tests for edge cases (e.g., invalid buffer handle).

### Phase 2: Chat Feature Implementation

**3. Core Chat Logic (`chat.lua`)**
-   **DONE: 3a. Red (start_chat):** In a new `tests/spec/chat_spec.lua`, write a test for `chat.start_chat` that asserts a new buffer is created with the correct options and a keymap is set. (Note: UI test was brittle and removed per user guidance).
-   **DONE: 3b. Green (start_chat):** Implement `chat.start_chat` in `lua/llm/chat.lua` to make the test pass.
-   **DONE: 3c. Red (send_prompt):** Write a test for `chat.send_prompt` that asserts a `job.run` is called with the correct command. This test will use a mock of the `job` module.
-   **DONE: 3d. Green (send_prompt):** Implement `chat.send_prompt` to make the test pass.
-   **DONE: 3e. Red (Visual Separation):** Add a test to `send_prompt` that asserts the response buffer is cleared and that headers for "Prompt" and "Response" are appended. (Note: UI test was brittle and removed per user guidance).
-   **DONE: 3f. Green (Visual Separation):** Update `send_prompt` to include the visual separators.
-   **DONE: 3g. Refactor:** Refine the `chat.lua` module and its tests.

### Phase 3: Refactor Existing Commands for Streaming

**4. Refactor `commands.lua`**
-   **DONE: 4a. Red:** In `tests/spec/commands_spec.lua`, modify the test for `M.prompt` to assert that `job.run` is called (it will fail as it currently calls the old CLI function).
-   **DONE: 4b. Green:** Refactor `M.prompt` in `lua/llm/commands.lua` to use `job.run`, making the test pass.
-   **4c. Red:** Repeat the Red-Green cycle for `M.prompt_with_current_file`.
-   **4d. Green:** Refactor `M.prompt_with_current_file`.
-   **4e. Red:** Repeat for `M.prompt_with_selection`.
-   **4f. Green:** Refactor `M.prompt_with_selection`.
-   **4g. Red:** Repeat for `M.explain_code`.
-   **4h. Green:** Refactor `M.explain_code`.
-   **4i. Refactor:** Clean up `commands.lua` and its tests. Remove the obsolete `llm_command_and_display_response` function and its corresponding test.

### Phase 4: Integration and Finalization

**5. Command Dispatch (`plugin/llm.lua`)**
-   **5a. Red:** Write a test (if possible, this might require a more integrated test setup) that calls `:LLM` with no arguments and asserts that `chat.start_chat` is called.
-   **5b. Green:** Modify `plugin/llm.lua` to call `chat.start_chat` when `:LLM` is called with no arguments.

**6. Documentation (`doc/llm.txt`)**
-   **Action:** After all implementation and refactoring is complete and all tests are passing, update the documentation in `doc/llm.txt` to reflect the new interactive chat feature and the streaming behavior of existing commands.
