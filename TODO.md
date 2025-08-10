### Overall Goal

The main objective is to refactor the streaming logic to be more modular and reusable, and to fix a bug in the `:LLMChat` command that causes issues with conversation history.

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

### Test Environment Setup and Mocking Fixes

These tasks address the errors and failures encountered during `make test`. They are crucial for enabling reliable testing of the plugin's functionality.

- [ ] **Investigate and Fix: `tests/spec/core/utils/ui_spec.lua` Failure - `create_chat_buffer()` arguments mismatch.**
    - [ ] **Problem:** `llm.core.utils.ui create_chat_buffer() should create and configure the chat buffer correctly` - `Function was never called with matching arguments.`
    - [ ] **Action:** Analyze `ui_spec.lua` and `lua/llm/core/utils/ui.lua` to understand why the mock for `create_chat_buffer` is not being called with the expected arguments. Adjust the mock or the test to match the actual function call.
    - [ ] **Test:** Rerun the specific test to confirm the fix.

- [ ] **Investigate and Fix: `tests/spec/plugin_spec.lua` Failure - `:LLM command handler not calling `chat.start_chat()`**
    - [ ] **Problem:** `plugin/llm.lua :LLM command handler should call chat.start_chat() when called with no arguments` - `Expected to be called >0 time(s), but was called 0 time(s)`
    - [ ] **Action:** Examine `plugin/llm.lua` and `lua/llm/chat.lua` to ensure the `:LLM` command correctly dispatches to `chat.start_chat()` when no arguments are provided. Verify mocks for `vim.api.nvim_create_user_command` or similar are correct.
    - [ ] **Test:** Rerun the specific test to confirm the fix.

- [ ] **Investigate and Fix: `tests/spec/plugin_spec.lua` Failure - `:LLM command handler not calling `commands.prompt()`**
    - [ ] **Problem:** `plugin/llm.lua :LLM command handler should call commands.prompt() when called with a prompt` - `Function was never called with matching arguments.`
    - [ ] **Action:** Similar to the above, check `plugin/llm.lua` and `lua/llm/commands.lua` to ensure the `:LLM` command correctly dispatches to `commands.prompt()` with the provided arguments.
    - [ ] **Test:** Rerun the specific test to confirm the fix.

- [ ] **Investigate and Fix: `chat_spec.lua` Error - `nvim_win_get_cursor` is nil.**
    - [ ] **Problem:** `./lua/llm/chat.lua:28: attempt to call a nil value (field 'nvim_win_get_cursor')`
    - [ ] **Action:** Add a mock for `vim.api.nvim_win_get_cursor` to `tests/spec/mock_vim.lua`.
    - [ ] **Test:** Rerun `chat_spec.lua` to confirm the fix.

- [ ] **Investigate and Fix: Recurring Error - `attempt to index a nil value (field 'env')` or `(global 'vim')` in `facade.lua`.**
    - [ ] **Problem:** This error appears in `commands_spec.lua`, `llm_cli_spec.lua`, `custom_openai_spec.lua`, `scratch_buffer_save_spec.lua`. It points to `lua/llm/facade.lua:35`.
    - [ ] **Action:** Analyze `lua/llm/facade.lua` and `tests/spec/mock_vim.lua`. Ensure that `vim.env` and the global `vim` object are correctly mocked and accessible within the test environment, especially in modules that `require 'llm.facade'`.
    - [ ] **Test:** Rerun affected specs to confirm the fix.

- [ ] **Investigate and Fix: `job_spec.lua` Error - `vim.inspect` is nil.**
    - [ ] **Problem:** `./lua/llm/core/utils/job.lua:9: attempt to call a nil value (field 'inspect')`
    - [ ] **Action:** Add a mock for `vim.inspect` to `tests/spec/mock_vim.lua`.
    - [ ] **Test:** Rerun `job_spec.lua` to confirm the fix.

- [ ] **Investigate and Fix: `shell_spec.lua` Error - `vim.split` is nil.**
    - [ ] **Problem:** `./lua/llm/core/utils/shell.lua:167: attempt to call a nil value (field 'split')`
    - [ ] **Action:** Verify that the `vim.split` mock added to `tests/spec/mock_vim.lua` is correctly loaded and accessible in `shell_spec.lua`. If not, ensure `spec_helper.lua` or the test setup correctly includes `mock_vim.lua`.
    - [ ] **Test:** Rerun `shell_spec.lua` to confirm the fix.

- [ ] **Investigate and Fix: `ui_spec.lua` Error - `nvim_buf_get_name` is nil.**
    - [ ] **Problem:** `./lua/llm/core/utils/ui.lua:108: attempt to call a nil value (field 'nvim_buf_get_name')`
    - [ ] **Action:** Add a mock for `vim.api.nvim_buf_get_name` to `tests/spec/mock_vim.lua`.
    - [ ] **Test:** Rerun `ui_spec.lua` to confirm the fix.

- [ ] **Investigate and Fix: `ui_spec.lua` Error - `nvim_get_current_buf` is nil.**
    - [ ] **Problem:** `./lua/llm/core/utils/ui.lua:318: attempt to call a nil value (field 'nvim_get_current_buf')`
    - [ ] **Action:** Add a mock for `vim.api.nvim_get_current_buf` to `tests/spec/mock_vim.lua`.
    - [ ] **Test:** Rerun `ui_spec.lua` to confirm the fix.

- [ ] **Investigate and Fix: Recurring Error - `llm_cli.lua` `vim.split` is nil.**
    - [ ] **Problem:** `./lua/llm/core/data/llm_cli.lua:10: attempt to call a nil value (field 'split')` - This is still present in `fragments_manager_spec.lua`, `keys_manager_spec.lua`, `models_io_spec.lua`, `templates_manager_spec.lua`.
    - [ ] **Action:** This indicates a deeper issue with the `vim.split` mock not being universally applied or a caching issue in the test runner. Re-verify `spec_helper.lua` and the test setup to ensure `mock_vim.lua` is loaded before any module that uses `vim.split`.
    - [ ] **Test:** Rerun affected specs to confirm the fix.

- [ ] **Investigate and Fix: `schemas_manager_spec.lua` Error - `get_llm_executable_path` is nil.**
    - [ ] **Problem:** `./lua/llm/managers/schemas_manager.lua:78: attempt to call a nil value (field 'get_llm_executable_path')`
    - [ ] **Action:** Add a mock for `llm_cli.get_llm_executable_path` in the relevant test setup or `mock_llm_cli.lua` if such a file exists. If `get_llm_executable_path` is a new function, ensure it's defined in `llm_cli.lua`.
    - [ ] **Test:** Rerun `schemas_manager_spec.lua` to confirm the fix.

- [ ] **Investigate and Fix: `templates_manager_spec.lua` Error - `get_llm_executable_path` is nil.**
    - [ ] **Problem:** `./lua/llm/managers/templates_manager.lua:79: attempt to call a nil value (field 'get_llm_executable_path')`
    - [ ] **Action:** Same as above, ensure `llm_cli.get_llm_executable_path` is properly mocked or defined.
    - [ ] **Test:** Rerun `templates_manager_spec.lua` to confirm the fix.

### Future Work

- [ ] **Improve error handling:** Add more robust error handling to the streaming function and the command call sites.
- [ ] **Add support for more LLM providers:** Extend the plugin to support other LLM providers besides `llm-cli`.