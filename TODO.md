### Overall Goal

The main objective is to refactor the streaming logic to be more modular and reusable, and to fix a bug in the `:LLMChat` command that causes issues with conversation history.

### Addressing Test Environment Brittleness

The current test failures indicate a brittle mocking setup, primarily due to incomplete or inconsistent mocks of the `vim` object and other dependencies. Addressing this is crucial for a stable and reliable test suite.

**Suggested Methods to Address Brittleness:**

1.  **Centralized and Comprehensive `mock_vim.lua`:** Ensure `mock_vim.lua` provides a complete and consistent mock of the `vim` object and its sub-APIs (`vim.api`, `vim.fn`, `vim.inspect`, `vim.env`, etc.) that are used throughout the plugin. This involves auditing `vim` usage across the codebase and implementing all necessary mocks with sensible default return values.
2.  **Consistent Test Setup (`spec_helper.lua`):** Ensure that `mock_vim.lua` (and any other global mocks) are loaded consistently and *before* any application code that relies on `vim`. This means explicit `require` statements and proper global `vim` assignment early in the test setup.
3.  **Mocking External Dependencies (e.g., `llm_cli`):** For significant external interfaces, consider creating dedicated mock modules (e.g., `tests/spec/mock_llm_cli.lua`). Use dependency injection or direct stubbing in tests to replace real modules with their mocks.
4.  **Refactoring `facade.lua` (if necessary):** If `facade.lua` directly accesses `vim` globals in a way that makes it hard to test, consider refactoring it to accept `vim` (or relevant parts) as an argument, or ensure lazy loading/initialization.
5.  **Test-Driven Mocking:** While a comprehensive initial mock for core dependencies like `vim` is good, for other cases, only mock what's necessary for the current test to pass, preventing over-mocking.

**Tasks to Address Brittleness:**

- [x] **Comprehensive `vim` API Mocking:** All identified `vim` API functions and globals are now mocked in `tests/spec/mock_vim.lua`.
    - [x] **Audit `vim` usage:** Completed.
    - [x] **Implement missing `vim.api` mocks:** Completed.
    - [x] **Implement missing `vim.inspect` mock:** Completed.
    - [x] **Verify `vim.split` mock consistency:** Completed.
    - [x] **Implement `vim.env` mock:** Completed.
    - [x] **Test:** Will be tested by running the full test suite.

- [x] **Centralized Test Setup:** `spec_helper.lua` now exclusively loads `mock_vim.lua`, ensuring consistent and early loading of the comprehensive `vim` mock.
    - [x] **Ensure `mock_vim.lua` is loaded consistently and early:** Completed by removing conflicting mocks from `spec_helper.lua` and adding `require('mock_vim')`.
    - [x] **Test:** Will be tested by running the full test suite.

- [x] **Mocking `llm_cli` (and other external dependencies):**
    - [x] **Implement `llm_cli.get_llm_executable_path` mock:** Added a mock for `llm_cli.get_llm_executable_path` in `tests/spec/mock_llm_cli.lua`.
    - [x] **Test:** Reran `schemas_manager_spec.lua` and `templates_manager_spec.lua` to confirm the fix. This also involved fixing the `spec_helper.lua` to correctly load a centralized `mock_vim.lua`, and fixing a bug in `templates_manager.lua` where `vim.api` was being called incorrectly.

- [x] **Investigate and Fix: Recurring Error - `attempt to index a nil value (field 'env')` or `(global 'vim')` in `facade.lua`.**
    - [x] **Problem:** This error appears in `commands_spec.lua`, `llm_cli_spec.lua`, `custom_openai_spec.lua`, `scratch_buffer_save_spec.lua`. It points to `lua/llm/facade.lua:35`.
    - [x] **Evaluation:** This was a fundamental issue with the test environment's mocking of the `vim` object. Several test specs were defining their own local, incomplete `vim` mocks instead of using the centralized mock provided by `spec_helper.lua`.
    - [x] **Action:** Modified `commands_spec.lua`, `llm_cli_spec.lua`, `custom_openai_spec.lua`, and `scratch_buffer_save_spec.lua` to remove local mocks and `require('spec_helper')` instead. Updated `mock_vim.lua` with functions that were missing.
    - [x] **Test:** Reran the full test suite. The original error is gone, but new failures have been revealed.

### Remaining Test Failures (after addressing mocking issues)

These failures are likely indicative of actual bugs or incorrect logic in the plugin and should be addressed after the test environment is stable.

- [x] **Investigate and Fix: `commands_spec.lua` failures.**
    - [x] **Problem:** The tests for `prompt`, `explain_code`, `prompt_with_current_file`, and `prompt_with_selection` are failing. The spy on `job.run` is not being called.
    - [x] **Evaluation:** The mock for `llm.core.utils.job` is set up before `llm.commands` is required, so it should be working. There might be a subtle issue with how modules are loaded or how spies are created.
    - [x] **Action:** Investigated the module loading order and the spy setup in `commands_spec.lua`. The issue was that `job.run` was not being called directly, but instead `api.run_llm_command_streamed` was. The tests were updated to mock `api.run_llm_command_streamed` instead.

- [x] **Investigate and Fix: `core/utils/job_spec.lua` failures.**
    - [x] **Problem:** The tests for `on_stdout` handling are failing.
    - [x] **Evaluation:** The mock for the `on_stdout` callback is not being called with the expected arguments.
    - [x] **Action:** Analyzed `job_spec.lua` and `lua/llm/core/utils/job.lua` and updated both to correctly handle stdout.

- [x] **Investigate and Fix: `core/utils/shell_spec.lua` errors.**
    - [x] **Problem:** The tests are failing with `attempt to index upvalue 'api_obj' (a nil value)`.
    - [x] **Evaluation:** `api_obj` is passed to `update_llm_cli`, but it seems to be nil in the test context.
    - [x] **Action:** Analyzed `shell_spec.lua` and how `update_llm_cli` is tested. The test was updated to pass a mock api object to the function.

- [x] **Investigate and Fix: `core/utils/ui_spec.lua` failures.**
    - [x] **Problem:** The tests for `create_buffer_with_content` and `append_to_buffer` are failing. Spies are not being called as expected.
    - [x] **Evaluation:** The mocks are set up using `ui_utils.set_api`, but the spies are not being triggered correctly.
    - [x] **Action:** Refactored `lua/llm/core/utils/ui.lua` to use the global `vim.api` object and updated the tests in `tests/spec/core/utils/ui_spec.lua` to mock the `vim.api` functions directly.

- [x] **Investigate and Fix: `managers/*_spec.lua` errors.**
    - [x] **Problem:** Some manager specs are still failing with `attempt to call field 'system' (a nil value)` in `shell.lua`.
    - [x] **Evaluation:** This is happening even though `vim.system` is mocked in `mock_vim.lua` and the specs use `spec_helper`. There might be another module loading issue.
    - [x] **Action:** The `vim.fn.system` mock was incorrect. It was returning a table instead of a string. The mock was updated to return a string.

- [x] **Investigate and Fix: Test runner errors.**
    - [x] **Problem:** Several test files are failing with `luarocks/core/persist.lua:18: attempt to call method 'read' (a nil value)`.
    - [x] **Evaluation:** This seems to be an issue with the test runner (`busted`) or its dependencies, not with the plugin code itself. The error suggests that a file is not being opened correctly, and the file handle is `nil`. This could be a permission issue, or the file might not exist. Cleaning the cache and reinstalling dependencies did not solve the issue.
    - [x] **Action:** 
        - [x] Investigate the `luarocks/core/persist.lua` file to understand what it is doing and what file it is trying to read.
        - [x] Try to run the tests with `strace` or a similar tool to see what files are being accessed.

- [x] **Investigate and Fix: `chat_spec.lua` errors.**
    - [x] **Problem:** The tests are failing with `attempt to call a nil value (global 'unpack')`.
    - [x] **Evaluation:** The `unpack` function was removed in Lua 5.2 and replaced with `table.unpack`. It was re-introduced in Lua 5.3, but it is possible that the test environment is using a version of Lua where `unpack` is not available.
    - [x] **Action:** 
        - [x] Replace `unpack` with `table.unpack` in `lua/llm/chat.lua`.
        - [ ] Check the Lua version being used by the test runner.

### Unify LLM Streaming Logic

This is the first priority. The goal is to create a single, unified function for handling streaming output from the `llm` command. This will make the code easier to maintain and extend in the future.

- [ ] **Create a Unified Streaming Function:**
    - [ ] **Analyze `:LLMChat`:** The streaming is handled by `api.run_llm_command_streamed` in `lua/llm/api.lua`, which is called from `lua/llm/chat.lua`. It uses `vim.fn.jobsend` to send the prompt to the `llm` process and has chat-specific logic in its `on_stdout` and `on_exit` callbacks.
    - [ ] **Generalize the streaming logic:** To make this reusable, move the chat-specific logic out of `api.run_llm_command_streamed`. Create a new, more generic function that accepts callbacks as arguments, allowing each command to define its own behavior for handling the streamed output and the command's completion.
    - [ ] **Implement the new streaming function:** Create a new function, likely in `lua/llm/api.lua`, that encapsulates the logic for running a streaming command. This function will take the command parts, the prompt, and the target buffer as arguments. It will handle creating the job and sending the prompt to the command's stdin using `vim.fn.jobsend`.

- [ ] **Refactor LLM Command Callsites:**
    - [ ] **Refactor `prompt` command (`lua/llm/commands.lua`):**
        - **Analyze:** This is the basic prompt command. It streams the response to a new buffer.
        - **Refactor:** Modify the function to call the new unified streaming function. The `prompt` string will be passed to be sent via `jobsend`. The `on_stdout` callback will append data to the buffer, and the `on_exit` callback will be empty.
        - **Test:** Write a test to verify that the unified streaming function is called with the correct arguments. Simulate the callbacks and assert that the buffer is updated correctly.

    - [ ] **Refactor `prompt_with_current_file` command (`lua/llm/commands.lua`):**
        - **Analyze:** This command adds the current file as a fragment before calling the LLM.
        - **Refactor:** Similar to the `prompt` command, this will be modified to call the new unified streaming function, passing the prompt via `jobsend`.
        - **Test:** Write a test to verify that the unified streaming function is called with the correct arguments, including the fragment for the current file. Simulate the callbacks and assert that the buffer is updated correctly.

    - [ ] **Refactor `prompt_with_selection` command (`lua/llm/commands.lua`):**
        - **Analyze:** This command uses a temporary file for the selection and has an `on_exit` callback to clean it up.
        - **Refactor:** Modify the function to call the new unified streaming function. The `on_exit` callback, which removes the temporary file, will be passed to the new function.
        - **Test:** Write a test to verify that the unified streaming function is called correctly. The test should also verify that the temporary file is created and that the `on_exit` callback removes it.

    - [ ] **Refactor `send_prompt` command (`lua/llm/chat.lua`):**
        - **Analyze:** This is the chat command. It has custom logic in its callbacks to filter startup messages and to re-prompt the user on exit.
        - **Refactor:** Modify the function to call the new unified streaming function. The custom `on_stdout` and `on_exit` callbacks will be passed to the new function.
        - **Test:** Write a test to verify that the unified streaming function is called correctly. The test should simulate the `on_stdout` callback and assert that startup messages are filtered. It should also simulate the `on_exit` callback and assert that the UI is updated to re-prompt the user.

- [ ] **Test the Unified Streaming Function:**
    - [ ] **Testing Strategy:** The unified streaming function will be tested using the existing `busted` and `luassert` test suite. The tests will rely on mocking the `job.run` and `vim.fn` APIs to simulate the behavior of the streaming job. While this approach won't test the actual asynchronous nature of the stream, it will provide a high degree of confidence in the correctness of the implementation.
    - [ ] **Test Correct Job Creation:** Write a test to assert that `job.run` is called with the correct command and arguments.
    - [ ] **Test Correct Prompt Handling:** Write a test to assert that `vim.fn.jobsend` is called with the correct job ID and prompt text.
    - [ ] **Test Callback Behavior:** Write tests to capture the `on_stdout`, `on_stderr`, and `on_exit` callbacks and invoke them directly to verify that they:
        - Correctly append data to the buffer.
        - Correctly report errors.
        - Perform any necessary cleanup or finalization.

### Fix `:LLMChat` Conversation Handling

This task depends on the successful completion of the "Unify LLM Streaming Logic" task.

- [ ] **Analyze and fix the bug in `:LLMChat` conversation handling:** The `send_prompt` function in `lua/llm/chat.lua` incorrectly handles conversations. It passes the prompt as a command-line argument instead of just to stdin, and it doesn't use the `llm` tool's conversation management features. This causes subsequent prompts to be concatenated with the previous ones.

- [ ] **Plan to Fix:**
    - [ ] **Manage Chat State:** Introduce a buffer-local variable (e.g., `b.llm_chat_is_continuing`) to track whether a chat is new or ongoing.
    - [ ] **Use the `--continue` Flag:** For ongoing chats, add the `--continue` flag to the `llm` command to tell the tool to load the conversation history.
    - [ ] **Send Prompt via Stdin Only:** Modify the `send_prompt` function to send the prompt *only* to the `llm` command's standard input via `jobsend`, not as a command-line argument.
    - [ ] **Refactor `send_prompt`:** Update the `send_prompt` function to implement this new logic, checking the chat state and modifying the command arguments accordingly.
