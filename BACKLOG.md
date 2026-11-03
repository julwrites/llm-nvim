## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- Text generation (`prompt`): Sending prompts and receiving text completions.
- Chat sessions (`chat`): Holding ongoing interactive conversations with history.
- Piped input: Sending text from the buffer or selection to the model via standard input.
- Extractions (`-x`, `--xl`): Extracting code blocks from the model's response.
- Structured output options (`--schema`, `--schema-multi`): Forcing output to follow a JSON schema.
- Output Control (`--json`, `-R`): Output formatting control such as JSON output and hiding reasoning.
- Token usage tracking (`-u`): Viewing tokens consumed by a prompt.
- Multi-modal attachments (`-a`, `--at`): Attaching images or other files to prompts.
- Tools and function calling (`-T`, `--functions`): Allowing the model to execute tools.
- System prompt and fragments (`-s`, `--sf`, `-f`): Appending predefined text.
- Template options (`-t`, `-p`): Reusable prompt templates and parameters.
- Embedding commands (`embed`, `collections`, `similar`): Creating and managing embeddings.
- Model aliases (`aliases`): Managing shortcuts for longer model names.

## Gaps & Tech Debt
- Feature Gap: No exposed interactive UI flows for Extractions (`-x`, `--xl`).
- Feature Gap: No exposed interactive UI flows for Schema Options (`--schema`, `--schema-multi`).
- Feature Gap: No exposed interactive UI flows for explicit attachment type (`--at`).
- Feature Gap: No exposed interactive UI flows for Output Control (`--json`, `-R`).
- Feature Gap: No exposed interactive UI flows for token usage tracking (`-u`).
- Feature Gap: No exposed interactive UI flows for Extended Tool Options (`--td`, `--ta`, `--cl`).
- Tech Debt: Widespread use of synchronous blocking file I/O operations (`io.open`) which block the Neovim event loop. Verified in `lua/llm/core/utils/text.lua` (line 58), `lua/llm/core/utils/file_utils.lua` (line 87), `lua/llm/core/utils/shell.lua` (lines 96, 109), `lua/llm/core/data/cache.lua` (lines 11, 30), `lua/llm/managers/keys_manager.lua` (lines 63, 87), `lua/llm/managers/custom_openai.lua` (lines 41, 203, 295, 375, 437, 463, 504), and `lua/llm/managers/schemas_manager.lua` (lines 38, 57, 252).

## Ranked Backlog
1. Refactor `load_custom_openai_models` in `custom_openai.lua` to accept a callback for async libuv I/O.
2. Update `models_manager.lua` to handle the asynchronous API for custom models.
3. Update test suites and `debug_custom_openai_models` for the async API.
4. Refactor `create_sample_yaml_file` (line 295) to async in `custom_openai.lua` - High Impact / Medium Effort - Convert blocking I/O calls to asynchronous alternatives.
5. Refactor `add_custom_openai_model` and `delete_custom_openai_model` (lines 375, 437, 463, 504) to async in `custom_openai.lua` - High Impact / Medium Effort - Convert blocking I/O calls to asynchronous alternatives.
6. Refactor synchronous `io.open` calls in `lua/llm/managers/keys_manager.lua` (lines 63, 87) - High Impact / Medium Effort - Convert blocking I/O calls to asynchronous alternatives.
7. Refactor synchronous `io.open` calls in `lua/llm/core/data/cache.lua` (lines 11, 30) - High Impact / Medium Effort - Convert blocking I/O calls to asynchronous alternatives.
8. Refactor synchronous `io.open` calls in `lua/llm/managers/schemas_manager.lua` (lines 38, 57, 252) - High Impact / Medium Effort - Convert blocking I/O calls to asynchronous alternatives.
9. Refactor synchronous `io.open` calls in `lua/llm/core/utils/text.lua` (line 58), `lua/llm/core/utils/file_utils.lua` (line 87), and `lua/llm/core/utils/shell.lua` (lines 96, 109) - High Impact / Medium Effort - Convert blocking I/O calls to asynchronous alternatives.
10. Implement UI flows for Schema Options (`--schema`, `--schema-multi`) - High Impact / Medium Effort - Create interactive commands or UI to apply JSON schemas to outputs.
11. Implement UI flows for Extractions (`-x`, `--xl`) - Medium Impact / Low Effort - Add toggles or commands to extract code blocks directly into the buffer.
12. Implement UI flows for explicit attachment type (`--at`) - Medium Impact / High Effort - Create a mechanism to easily attach images or context to prompts.
13. Implement UI flows for Output Control (`--json`, `-R`) - Low Impact / Low Effort - Expose toggles for JSON output and hiding reasoning.
14. Expose token usage tracking (`-u`) - Low Impact / Low Effort - Add an option to display token usage statistics after a prompt completes.
15. Implement UI flows for Extended Tool Options (`--td`, `--ta`, `--cl`) - Low Impact / High Effort - Provide a mechanism to register and configure local tool execution settings.
