## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- Text generation (`prompt`): Sending prompts and receiving text completions.
- Piped input: Sending text from the buffer or selection to the model via standard input.
- Chat sessions (`chat`): Holding ongoing interactive conversations with history.
- Model aliases (`aliases`): Managing shortcuts for longer model names.
- Multi-modal attachments (`-a`, `--at`): Attaching images or other files to prompts.
- Tools and function calling (`-T`, `--functions`): Allowing the model to execute tools.
- Extractions (`-x`, `--xl`): Extracting code blocks from the model's response.
- Structured output options (`--schema`, `--schema-multi`): Forcing output to follow a JSON schema.
- Output Control (`--json`, `-R`): Output formatting control such as JSON output and hiding reasoning.
- Token usage tracking (`-u`): Viewing tokens consumed by a prompt.
- System prompt and fragments (`-s`, `--sf`, `-f`): Appending predefined text.
- Template options (`-t`, `-p`): Reusable prompt templates and parameters.
- Embedding commands (`embed`, `embed-multi`, `collections`, `similar`): Creating and managing embeddings.
- API Key override (`--key`): API key to use for the prompt.
- Database Selection (`-d`): Path to log database.
- Save as Template (`--save`): Save prompt with a template name.
- Logging Overrides (`--log`, `--no-log`): Control logging to the database.
- Query Selection (`-q`): Use first model matching strings.
- Stream Control (`--no-stream`): Do not stream output.
- Async Execution (`--async`): Run prompt asynchronously.
- Continue Conversation (`-c`, `--cid`): Continue a previous conversation.
- Model Options (`-o`): Pass dynamic key/value options to the model.

## Gaps & Tech Debt
- Feature Gap: No exposed interactive UI flows for Extractions (`-x`, `--xl`).
- Feature Gap: No exposed interactive UI flows for Schema Options (`--schema`, `--schema-multi`).
- Feature Gap: No exposed interactive UI flows for explicit attachment type (`--at`).
- Feature Gap: No exposed interactive UI flows for Extended Tool Options (`--td`, `--ta`, `--cl`).
- Feature Gap: No exposed interactive UI flows for Output Control (`--json`, `-R`).
- Feature Gap: No exposed interactive UI flows for token usage tracking (`-u`).
- Tech Debt: Widespread use of synchronous blocking file I/O operations (e.g., `io.open`) in `lua/llm/managers/custom_openai.lua`, `lua/llm/commands.lua`, `lua/llm/managers/keys_manager.lua`, and `lua/llm/managers/schemas_manager.lua` which block the Neovim event loop.

## Ranked Backlog
1. Refactor write_context_to_temp_file to be asynchronous
2. Refactor callers in commands.lua and facade.lua
3. Update unit tests for async write_context_to_temp_file
4. Refactor synchronous file I/O operations at line 619 in `lua/llm/commands.lua` to be asynchronous - High Impact / Medium Effort - Convert blocking `io.open` calls to async using callbacks to prevent UI freezing.
5. Refactor synchronous file I/O in `lua/llm/managers/custom_openai.lua` - High Impact / Medium Effort - Convert blocking `io.open` calls to asynchronous alternatives to prevent UI freezing.
6. Refactor synchronous file I/O in `lua/llm/managers/keys_manager.lua` - High Impact / Medium Effort - Convert blocking `io.open` calls to asynchronous alternatives to prevent UI freezing.
7. Refactor synchronous file I/O in `lua/llm/managers/schemas_manager.lua` - High Impact / Medium Effort - Convert blocking `io.open` calls to asynchronous alternatives to prevent UI freezing.
8. Implement UI flows for Schema Options (`--schema`, `--schema-multi`) - High Impact / Medium Effort - Create interactive commands/UI to easily apply JSON schemas to outputs directly from Neovim.
9. Implement UI flows for Extractions (`-x`, `--xl`) - Medium Impact / Low Effort - Add simple toggles or commands to extract code blocks from model responses directly into the buffer.
10. Implement UI flows for explicit attachment type (`--at`) - Medium Impact / High Effort - Create a file picker or visual selection mechanism to easily attach images or context to prompts.
11. Implement UI flows for Output Control (`--json`, `-R`) - Low Impact / Low Effort - Expose toggles for JSON output and hiding reasoning.
12. Expose token usage tracking (`-u`) - Low Impact / Low Effort - Add an option to display token usage statistics after a prompt completes.
13. Implement UI flows for Extended Tool Options (`--td`, `--ta`, `--cl`) - Low Impact / High Effort - Provide a mechanism to register and configure local tool execution settings.
