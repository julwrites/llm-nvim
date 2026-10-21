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
- [Tech Debt 2]: Trailing newlines are artificially appended to partial string chunks in `on_stdout` callbacks. In files like `lua/llm/core/data/llm_cli.lua` and `lua/llm/core/utils/job.lua`, chunks are reconstructed via `table.concat(lines, "\n")` and passed downstream, which forces newlines onto partial chunks and breaks stream buffering logic.
- [Bug 1]: Missing feature coverage. The `llm` CLI natively supports piped input, yet Neovim plugin integration for piped input via buffer commands or direct API is undocumented or completely unexposed in CLI.

## Ranked Backlog
1. [Tech Debt 1a-3] Replace synchronous io.open in commands.lua - High Impact / Medium Effort - Replace synchronous `io.open` calls with async implementations in `lua/llm/commands.lua`.
2. [Tech Debt 1b] Replace synchronous `io.open` - High Impact / Medium Effort - Replace synchronous `io.open` calls with asynchronous conceptual methods in `lua/llm/core/utils/text.lua` and `lua/llm/core/utils/file_utils.lua`.
3. [Tech Debt 1c] Replace synchronous `io.open` - High Impact / Medium Effort - Replace synchronous `io.open` calls with asynchronous conceptual methods in `lua/llm/core/utils/shell.lua` and `lua/llm/core/data/cache.lua`.
4. [Tech Debt 1d] Replace synchronous `io.open` - High Impact / Medium Effort - Replace synchronous `io.open` calls with asynchronous conceptual methods in `lua/llm/managers/custom_openai.lua` and `lua/llm/managers/schemas_manager.lua`.
5. [Tech Debt 2] Fix string chunking in on_stdout callbacks - High Impact / Low Effort - Modify `on_stdout` callbacks in `lua/llm/core/data/llm_cli.lua` and `lua/llm/core/utils/job.lua` to pass filtered elements iteratively to UI functions instead of concatenating them with newlines.
6. [Bug 1] Support piped input integration - Medium Impact / Low Effort - Investigate missing piped input integration or update codebase to cleanly accept visually selected lines as standard input for CLI operations.
7. [Feature Gap 1] Expose interactive UI for advanced options - Medium Impact / High Effort - Provide UI flows for advanced arguments parsed in `commands.lua` (Extractions, Schemas, Tools, Output Control, etc.).