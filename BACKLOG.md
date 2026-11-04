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
- Database explicit path (`-d`): Using a different log database.
- Continuation (`-c`, `--cid`): Continue the conversation.
- Asynchronous running (`--async`): Run prompt asynchronously.
- Tools extended options (`--td`, `--ta`, `--cl`): Debugging, approving and limiting tools.

## Gaps & Tech Debt
- Feature Gap: No exposed interactive UI flows for Extractions (`-x`, `--xl`).
- Feature Gap: No exposed interactive UI flows for Schema Options (`--schema`, `--schema-multi`).
- Feature Gap: No exposed interactive UI flows for explicit attachment type (`--at`).
- Feature Gap: No exposed interactive UI flows for Output Control (`--json`, `-R`).
- Feature Gap: No exposed interactive UI flows for token usage tracking (`-u`).
- Feature Gap: No exposed interactive UI flows for Extended Tool Options (`--td`, `--ta`, `--cl`).
- Feature Gap: No exposed interactive UI flows for Database explicit path (`-d`).
- Feature Gap: No exposed interactive UI flows for Asynchronous running (`--async`).
- Tech Debt: Widespread use of synchronous blocking file I/O operations (`io.open`) which block the Neovim event loop. Verified in `lua/llm/core/utils/text.lua`, `lua/llm/core/utils/file_utils.lua`, `lua/llm/core/utils/shell.lua`, `lua/llm/core/data/cache.lua`, `lua/llm/managers/keys_manager.lua`, `lua/llm/managers/custom_openai.lua`, and `lua/llm/managers/schemas_manager.lua`.

## Ranked Backlog
1. Implement UI flows for Schema Options (`--schema`, `--schema-multi`) - High Impact / Medium Effort - Create interactive commands or UI to apply JSON schemas to outputs.
2. Refactor synchronous `io.open` calls in `lua/llm/managers/custom_openai.lua` - High Impact / Medium Effort - Convert blocking I/O calls to asynchronous alternatives.
3. Refactor synchronous `io.open` calls in `lua/llm/managers/keys_manager.lua` - High Impact / Medium Effort - Convert blocking I/O calls to asynchronous alternatives.
4. Refactor synchronous `io.open` calls in `lua/llm/core/data/cache.lua` - High Impact / Medium Effort - Convert blocking I/O calls to asynchronous alternatives.
5. Refactor synchronous `io.open` calls in `lua/llm/managers/schemas_manager.lua` - High Impact / Medium Effort - Convert blocking I/O calls to asynchronous alternatives.
6. Refactor synchronous `io.open` calls in `lua/llm/core/utils/text.lua`, `lua/llm/core/utils/file_utils.lua`, and `lua/llm/core/utils/shell.lua` - High Impact / Medium Effort - Convert blocking I/O calls to asynchronous alternatives.
7. Implement UI flows for Extractions (`-x`, `--xl`) - Medium Impact / Low Effort - Add toggles or commands to extract code blocks directly into the buffer.
8. Implement UI flows for explicit attachment type (`--at`) - Medium Impact / High Effort - Create a mechanism to easily attach images or context to prompts.
9. Implement UI flows for Database explicit path (`-d`) - Medium Impact / Medium Effort - Allow explicit passing of log database location.
10. Implement UI flows for Output Control (`--json`, `-R`) - Low Impact / Low Effort - Expose toggles for JSON output and hiding reasoning.
11. Expose token usage tracking (`-u`) - Low Impact / Low Effort - Add an option to display token usage statistics after a prompt completes.
12. Implement UI flows for Extended Tool Options (`--td`, `--ta`, `--cl`) - Low Impact / High Effort - Provide a mechanism to register and configure local tool execution settings.
13. Implement UI flows for Asynchronous running (`--async`) - Low Impact / High Effort - Add asynchronous prompt execution options.