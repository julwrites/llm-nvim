## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- Text Generation (`prompt`): Execute a prompt and generate text.
- Chat (`chat`): Hold an ongoing chat with a model.
- Embeddings (`embed`, `collections`, `similar`, `embed-multi`): Embed text and manage embedding collections.
- System Prompt (`-s`, `--system`): System prompt to use.
- Model Selection (`-m`, `--model`): Model to use.
- Database Selection (`-d`, `--database`): Path to log database.
- Query Selection (`-q`, `--query`): Use first model matching these strings.
- Multi-modal attachments (`-a`, `--attachment`): Attachment path or URL.
- Explicit attachment type (`--at`, `--attachment-type`): Attachment with explicit mimetype.
- Tools / Function Calling (`-T`, `--tool`): Name of a tool to make available to the model.
- Extended Tool Options (`--functions`, `--td`, `--ta`, `--cl`): Detailed tool execution and chain limits.
- Model Options (`-o`, `--option`): Key/value options for the model.
- Schema Options (`--schema`, `--schema-multi`): Schema DSL, JSON schema, filepath or ID.
- Prompt Fragments (`-f`, `--fragment`): Fragment (alias, URL, hash or file path) to add to the prompt.
- System Fragments (`--sf`, `--system-fragment`): Fragment to add to system prompt.
- Template Options (`-t`, `--template`): Template to use.
- Template Parameters (`-p`, `--param`): Parameters for template.
- Stream Control (`--no-stream`): Do not stream output.
- Logging Control (`-n`, `--no-log`, `--log`): Log prompt and response to the database.
- Hide Reasoning (`-R`, `--hide-reasoning`): Hide reasoning output.
- Continue Conversation (`-c`, `--continue`, `--cid`, `--conversation`): Continue the most recent conversation.
- API Key override (`--key`): API key to use.
- Save as Template (`--save`): Save prompt with this template name.
- Async Execution (`--async`): Run prompt asynchronously.
- Usage tracking (`-u`, `--usage`): Show token usage.
- Extractions (`-x`, `--extract`, `--xl`, `--extract-last`): Extract first or last fenced code block.
- JSON Output (`--json`): Output the response as JSON.

## Gaps & Tech Debt
- [Feature Gap 1]: `llm-nvim` lacks exposed interactive UI flows for advanced arguments. Options for Extractions (`-x`, `--xl`), Schema Options (`--schema`, `--schema-multi`), Output Control (`--json`, `-R`), explicit attachment type (`--at`), token usage (`-u`), and Extended tool options (`--td`, `--ta`, `--cl`, `--functions`) are parsed in `lua/llm/commands.lua` but have no user-facing UI flows.
- [Tech Debt 1]: In `lua/llm/managers/embeddings_manager.lua`, `vim.fn.shellescape` is inappropriately used for appending simple subcommands and arguments, which wraps them in single quotes and breaks downstream CLI parsing.
- [Tech Debt 2]: In `lua/llm/commands.lua` and `lua/llm/chat.lua` within the `on_stdout` callbacks, they attempt to process partial output incorrectly by appending trailing newlines unconditionally when passing chunks to `ui.append_to_buffer`.
- [Tech Debt 3]: In Lua 5.2+ and Neovim environments, `table.unpack` should be used instead of `unpack`. In `lua/llm/chat/buffer.lua:22`, `table.unpack` is used correctly, but if `unpack` is used elsewhere it should be updated.
- [Tech Debt 4]: Widespread use of `io.open` for file I/O operations (e.g., in `lua/llm/commands.lua`, `lua/llm/managers/custom_openai.lua`, `lua/llm/managers/schemas_manager.lua`) blocks the Neovim event loop. These should be refactored to use asynchronous `vim.loop` (or `uv`) functions.

## Ranked Backlog
1. [Tech Debt 2] Fix improper `on_stdout` chunk processing in `lua/llm/commands.lua` and `lua/llm/chat.lua` - High Impact / Low Effort - Fix string buffering logic to avoid corrupting streaming output.
2. [Tech Debt 1] Fix `vim.fn.shellescape` usage in `lua/llm/managers/embeddings_manager.lua` - High Impact / Low Effort - Replace `vim.fn.shellescape` with string concatenation for simple CLI arguments.
3. [Tech Debt 4] Replace blocking `io.open` calls with async `vim.loop.fs_*` operations - Medium Impact / Medium Effort - Refactor file operations across managers to prevent blocking the editor.
4. [Feature Gap 1] Expose interactive UI for advanced options - Medium Impact / High Effort - Provide UI flows for advanced arguments parsed in `commands.lua` (Extractions, Schemas, Tools, Output Control, etc.).
