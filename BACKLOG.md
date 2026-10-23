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

## Gaps & Tech Debt
- Feature Gap: No exposed interactive UI flows for Extractions (`-x`, `--xl`).
- Feature Gap: No exposed interactive UI flows for Schema Options (`--schema`, `--schema-multi`).
- Feature Gap: No exposed interactive UI flows for explicit attachment types (`--at`) or multi-modal attachments (`-a`).
- Feature Gap: No exposed interactive UI flows for Extended Tool Options (`--functions`, `--td`, `--ta`, `--cl`).
- Feature Gap: No exposed interactive UI flows for Output Control (`--json`, `-R`).
- Feature Gap: No exposed interactive UI flows for Model Options (`-o`) during inference.
- Feature Gap: No exposed interactive UI flows for token usage tracking (`-u`).
- Tech Debt: Widespread use of synchronous blocking file I/O operations (e.g., `io.open`) in `lua/llm/managers/custom_openai.lua`, `lua/llm/commands.lua`, `lua/llm/managers/keys_manager.lua`, and `lua/llm/managers/schemas_manager.lua` which block the Neovim event loop.
- Tech Debt: `table.concat(lines, "\n")` is improperly used in `lua/llm/api.lua` on chunks emitted from `on_stdout` callbacks, which breaks stream buffering for partial lines before passing to `ui.append_to_buffer`.

## Ranked Backlog
1. Refactor synchronous file I/O in `lua/llm/commands.lua` - High Impact / Medium Effort - Convert blocking `io.open` calls to asynchronous alternatives to prevent UI freezing.
2. Refactor synchronous file I/O in `lua/llm/managers/custom_openai.lua` - High Impact / Medium Effort - Convert blocking `io.open` calls to asynchronous alternatives to prevent UI freezing.
3. Refactor synchronous file I/O in `lua/llm/managers/keys_manager.lua` - High Impact / Medium Effort - Convert blocking `io.open` calls to asynchronous alternatives to prevent UI freezing.
4. Refactor synchronous file I/O in `lua/llm/managers/schemas_manager.lua` - High Impact / Medium Effort - Convert blocking `io.open` calls to asynchronous alternatives to prevent UI freezing.
5. Implement UI flows for Schema Options (`--schema`, `--schema-multi`) - High Impact / Medium Effort - Create interactive commands/UI to easily apply JSON schemas to outputs directly from Neovim.
6. Implement UI flows for Extractions (`-x`, `--xl`) - Medium Impact / Low Effort - Add simple toggles or commands to extract code blocks from model responses directly into the buffer.
7. Implement UI flows for Multi-modal Attachments (`-a`, `--at`) - Medium Impact / High Effort - Create a file picker or visual selection mechanism to easily attach images or context to prompts.
8. Implement UI flows for Tool Options (`--functions`, `--td`, `--ta`, `--cl`) - Low Impact / High Effort - Provide a mechanism to register and configure local tool functions for the model to use within the editor.
9. Implement UI flows for Output Control (`--json`, `-R`) - Low Impact / Low Effort - Expose toggles for JSON output and hiding reasoning.
10. Expose token usage tracking (`-u`) - Low Impact / Low Effort - Add an option to display token usage statistics after a prompt completes.
11. Implement UI flows for Model Options (`-o`) - Low Impact / Medium Effort - Allow passing dynamic key/value options for the model during inference.