### Unify LLM Streaming Logic

- [ ] **Create a Unified Streaming Function:**
    - [ ] **Analysis of `:LLMChat`:** The streaming is handled by `api.run_llm_command_streamed` in `lua/llm/api.lua`, which is called from `lua/llm/chat.lua`. It uses `vim.fn.jobsend` to send the prompt to the `llm` process and has chat-specific logic in its `on_stdout` and `on_exit` callbacks.
    - [ ] **Generalization Plan:** To make this reusable, the chat-specific logic should be moved out of `api.run_llm_command_streamed`. A new, more generic function should be created that accepts callbacks as arguments, allowing each command to define its own behavior for handling the streamed output and the command's completion.
    - [ ] Create a new function, likely in `lua/llm/api.lua`, that encapsulates the logic for running a streaming command.
    - [ ] This function will take the command parts, the prompt, and the target buffer as arguments.
    - [ ] It will handle creating the job and sending the prompt to the command's stdin using `vim.fn.jobsend`.

- [ ] **Refactor LLM Command Callsites:**
    - [ ] **`prompt` command (`lua/llm/commands.lua`):**
        - **Analysis:** This is the basic prompt command. It streams the response to a new buffer.
        - **Refactoring:** Modify the function to call the new unified streaming function. The `prompt` string will be passed to be sent via `jobsend`. The `on_stdout` callback will append data to the buffer, and the `on_exit` callback will be empty.
        - **Testing:** Write a test to verify that the unified streaming function is called with the correct arguments. Simulate the callbacks and assert that the buffer is updated correctly.

    - [ ] **`prompt_with_current_file` command (`lua/llm/commands.lua`):**
        - **Analysis:** This command adds the current file as a fragment before calling the LLM.
        - **Refactoring:** Similar to the `prompt` command, this will be modified to call the new unified streaming function, passing the prompt via `jobsend`.
        - **Testing:** Write a test to verify that the unified streaming function is called with the correct arguments, including the fragment for the current file. Simulate the callbacks and assert that the buffer is updated correctly.

    - [ ] **`prompt_with_selection` command (`lua/llm/commands.lua`):**
        - **Analysis:** This command uses a temporary file for the selection and has an `on_exit` callback to clean it up.
        - **Refactoring:** Modify the function to call the new unified streaming function. The `on_exit` callback, which removes the temporary file, will be passed to the new function.
        - **Testing:** Write a test to verify that the unified streaming function is called correctly. The test should also verify that the temporary file is created and that the `on_exit` callback removes it.

    - [ ] **`send_prompt` command (`lua/llm/chat.lua`):**
        - **Analysis:** This is the chat command. It has custom logic in its callbacks to filter startup messages and to re-prompt the user on exit.
        - **Refactoring:** Modify the function to call the new unified streaming function. The custom `on_stdout` and `on_exit` callbacks will be passed to the new function.
        - **Testing:** Write a test to verify that the unified streaming function is called correctly. The test should simulate the `on_stdout` callback and assert that startup messages are filtered. It should also simulate the `on_exit` callback and assert that the UI is updated to re-prompt the user.

- [ ] **Test the Unified Streaming Function:**
    - [ ] **Testing Strategy:** The unified streaming function will be tested using the existing `busted` and `luassert` test suite. The tests will rely on mocking the `job.run` and `vim.fn` APIs to simulate the behavior of the streaming job. While this approach won't test the actual asynchronous nature of the stream, it will provide a high degree of confidence in the correctness of the implementation.
    - [ ] **Test Correct Job Creation:** Write a test to assert that `job.run` is called with the correct command and arguments.
    - [ ] **Test Correct Prompt Handling:** Write a test to assert that `vim.fn.jobsend` is called with the correct job ID and prompt text.
    - [ ] **Test Callback Behavior:** Write tests to capture the `on_stdout`, `on_stderr`, and `on_exit` callbacks and invoke them directly to verify that they:
        - Correctly append data to the buffer.
        - Correctly report errors.
        - Perform any necessary cleanup or finalization.