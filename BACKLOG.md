## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- Text Generation (`prompt`): Execute a prompt and generate text.
- Piped Input (`cat image | llm`): Pass piped content.
- Chat (`chat`): Hold an ongoing chat with a model.
- Model Aliases (`aliases`): Manage model aliases.
- Embeddings (`embed`, `collections`, `similar`): Embed text and manage embedding collections.
- Extractions (`-x`, `--extract`, `--xl`, `--extract-last`): Extract first or last fenced code block.
- Schema Options (`--schema`, `--schema-multi`): Structure output using a schema DSL or JSON schema.
- Output Control (`--json`, `-R`, `--hide-reasoning`): Format output as JSON and control reasoning output.
- Token Usage (`-u`, `--usage`): Show token usage statistics.
- Attachments (`-a`, `--attachment`, `--at`, `--attachment-type`): Support for multi-modal file attachments.
- Advanced Tool Options (`--td`, `--ta`, `--cl`, `--functions`): Fine-grained control over tool execution and definitions.
- Model Selection & Options (`-m`, `--model`, `-o`, `--option`): Select and configure specific models.
- System Prompts & Fragments (`-s`, `--system`, `-f`, `--fragment`, `--sf`, `--system-fragment`): Inject system instructions and reusable fragments.
- Conversation Management (`-c`, `--continue`, `--cid`, `--conversation`): Resume previous chat sessions.
- Streaming & Async (`--no-stream`, `--async`): Control response streaming and asynchronous execution.

## Gaps & Tech Debt
- [Feature Gap 1]: Missing interactive UI flows for advanced CLI arguments. While options for Extractions (`-x`, `--xl`), Schema Options (`--schema`, `--schema-multi`), Output Control (`--json`, `-R`), explicit attachment type (`--at`), token usage (`-u`), and Extended tool options (`--td`, `--ta`, `--cl`, `--functions`) are parsed in `lua/llm/commands.lua`, they lack exposed user-facing interactive UI configuration flows.
- [Tech Debt 1]: Widespread use of synchronous `io.open` for file I/O operations. Code in `lua/llm/commands.lua`, `lua/llm/managers/keys_manager.lua`, `lua/llm/core/utils/text.lua`, `lua/llm/core/utils/file_utils.lua`, `lua/llm/core/utils/shell.lua`, `lua/llm/core/data/cache.lua`, `lua/llm/managers/custom_openai.lua`, and `lua/llm/managers/schemas_manager.lua` uses blocking `io.open` calls which can block the Neovim event loop. These should be refactored to use asynchronous conceptual methods.
- [Tech Debt 2]: Trailing newlines are artificially appended to partial string chunks in `on_stdout` callbacks. In `lua/llm/commands.lua` and `lua/llm/chat.lua`, chunks are reconstructed via `table.concat(lines, "\n")` and passed downstream, which forces newlines onto partial chunks and breaks stream buffering logic.

## Ranked Backlog
1. [Tech Debt 1] Replace synchronous `io.open` calls with asynchronous conceptual methods - Medium Impact / Medium Effort - Refactor file operations across managers and utils to prevent blocking the Neovim event loop.
2. [Feature Gap 1] Expose interactive UI for advanced options - Medium Impact / High Effort - Provide UI flows for advanced arguments parsed in `commands.lua` (Extractions, Schemas, Tools, Output Control, etc.).