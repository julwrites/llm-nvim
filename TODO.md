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

