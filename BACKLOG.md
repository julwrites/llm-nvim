## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- Text Generation (`prompt`): Execute a prompt and generate text.
- Piped Input (`cat image | llm`): Pass piped content.
- Chat (`chat`): Hold an ongoing chat with a model.
- Model Aliases (`aliases`): Manage model aliases.
- Embeddings (`embed`, `collections`, `similar`): Embed text and manage embedding collections.
- System Prompt (`-s`, `--system`): System prompt to use
- Model Selection (`-m`, `--model`): Model to use
- Database Selection (`-d`, `--database`): Path to log database
- Query Selection (`-q`, `--query`): Use first model matching these strings
- Multi-modal attachments (`-a`, `--attachment`): Attachment path or URL or -
- Explicit attachment type (`--at`, `--attachment-type`): Attachment with explicit mimetype
- Tools / Function Calling (`-T`, `--tool`): Name of a tool to make available to the model
- Extended Tool Options (`--functions`, `--td`, `--ta`, `--cl`): Python code block or file path defining functions to register as tools, Show full details of tool executions, Manually approve every tool execution, How many chained tool responses to allow
- Model Options (`-o`, `--option`): key/value options for the model
- Schema Options (`--schema`, `--schema-multi`): Schema DSL, JSON schema, filepath or ID, Schema for multiple results
- Stream Control (`--no-stream`): Do not stream output
- Hide Reasoning (`-R`, `--hide-reasoning`): Hide reasoning output
- Continue Conversation (`-c`, `--continue`, `--cid`, `--conversation`): Continue the most recent conversation, Continue the conversation with the given ID
- Async Execution (`--async`): Run prompt asynchronously
- Usage tracking (`-u`, `--usage`): Show token usage
- Extractions (`-x`, `--extract`, `--xl`, `--extract-last`): Extract first fenced code block, Extract last fenced code block
- JSON Output (`--json`): Output the response as JSON, same format as llm logs --json

## Gaps & Tech Debt
- [Feature Gap 1]: `llm-nvim` lacks exposed interactive UI flows for advanced arguments. Options for Extractions (`-x`, `--xl`), Schema Options (`--schema`, `--schema-multi`), Output Control (`--json`, `-R`), explicit attachment type (`--at`), token usage (`-u`), and Extended tool options (`--td`, `--ta`, `--cl`, `--functions`) are parsed in `lua/llm/commands.lua` but have no user-facing UI flows.
- [Tech Debt 1]: Widespread use of synchronous `io.open` for file I/O operations (e.g., in `lua/llm/commands.lua`, `lua/llm/managers/keys_manager.lua`) blocks the Neovim event loop. These should be refactored to use asynchronous methods conceptually.
- [Tech Debt 2]: Appending trailing newlines in `on_stdout` callbacks. In `lua/llm/commands.lua`, chunks are passed to `ui.append_to_buffer` after `table.concat(lines, "\n")`. Similarly, in `lua/llm/chat.lua`, lines are concatenated before calling `buffer:append_llm_message`. Both instances incorrectly append trailing newlines and force partial chunks onto newlines in stream buffering.

## Ranked Backlog
1. [Tech Debt 2] Fix trailing newline appending in `on_stdout` callbacks - High Impact / Low Effort - Fix streaming buffering logic in `commands.lua` and `chat.lua` to prevent malformed streaming chunks.
2. [Tech Debt 1] Replace synchronous `io.open` calls with asynchronous conceptual methods - Medium Impact / Medium Effort - Refactor file operations across managers to prevent blocking the editor.
3. [Feature Gap 1] Expose interactive UI for advanced options - Medium Impact / High Effort - Provide UI flows for advanced arguments parsed in `commands.lua` (Extractions, Schemas, Tools, Output Control, etc.).
