## Streaming LLM Responses

- **Refactor `lua/llm/core/utils/job.lua`**:
    - Modify `M.run`'s `process_output` function to allow for more granular streaming of `stdout` data, potentially by passing unbuffered chunks directly to the `on_stdout` callback. This will enable real-time display of LLM output.
- **Integrate streaming in `lua/llm/chat.lua`**:
    - Identify call sites within `chat.lua` that invoke the `llm` tool.
    - Adapt these call sites to utilize the enhanced streaming capabilities provided by `job.lua`.
    - Update the UI handling in `chat.lua` to display the streamed content as it arrives, providing an interactive, real-time user experience for LLM responses.

## LLM Call Sites
    - **General**: Create a shared helper function (e.g., `llm.api.run_llm_command_streamed`) that encapsulates the logic for running LLM commands with streaming `stdout` and `stderr` handling, and integrates with the UI for real-time output. This function should accept the command parts, a buffer number for output, and optional callbacks.
    - [x] `lua/llm/chat.lua:send_prompt`: Adapted to use the shared streaming helper function for LLM command execution, ensuring real-time output to the chat buffer.
    - [x] `lua/llm/commands.lua:prompt`: Adapted to use the shared streaming helper function for LLM command execution, directing output to an appropriate buffer (e.g., a new scratch buffer or the current buffer).
    - [x] `lua/llm/commands.lua:prompt_with_current_file`: Adapted to use the shared streaming helper function, passing the file content as input and directing output to an appropriate buffer.
    - [x] `lua/llm/commands.lua:prompt_with_selection`: Adapted to use the shared streaming helper function, passing the visual selection as input and directing output to an appropriate buffer.
    - [x] `lua/llm/commands.lua:explain_code`: Adapted to use the shared streaming helper function, directing the explanation output to an appropriate buffer.
    - [x] `lua/llm/managers/templates_manager.lua:select_template`: Adapted to use the shared streaming helper function for template generation/processing.
    - [x] `lua/llm/commands.lua:interactive_prompt_with_fragments`: Adapted to use the shared streaming helper function for LLM command execution, handling interactive input and streaming output. 
