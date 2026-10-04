## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- Text Generation (prompt command): Core completion functionality
- Chat (chat command): Ongoing multi-turn conversation
- Tools / Function Calling: Passing functions to models via JSON schema or files
- Extended Tool Options: Detailed tool execution and chain limits (`--td`, `--ta`, `--cl`, `--functions`)
- Multi-modal attachments: Passing images and documents (`-a`)
- Explicit attachment type: Attachment with explicit mimetype (`--at`)
- Extractions: Parsing codeblocks out of markdown responses (`-x`)
- Extract Last: Extracting the last fenced code block (`--xl`)
- Model Options: Setting specific parameters like temperature (`-o`)
- Template Options: Using templates with specific variables (`-t`)
- Template Parameters: Parameters for template (`-p`)
- System Fragments: Adding fragments to system prompts (`--sf`)
- Embeddings: 'embed', 'collections', 'similar', and 'embed-multi' commands
- Database Selection: Specifying the path to the log database (`-d`)
- API Key override: Ad-hoc API key usage (`--key`)
- Usage tracking: Showing token usage (`-u`)
- Continue Conversation: Continuing from a specific conversation ID
- Schema Options: Constraining output to JSON Schema (`--schema`, `--schema-multi`)
- Save as Template: Saving prompts as templates
- Logging Overrides: Disabling or enabling logging to database
- Query Selection: Using first model matching a query string
- Stream Control: Disabling streaming output (`--no-stream`)
- Async Execution: Running prompts asynchronously (`--async`)
- Output Control: Formatting responses (`--json`, `-R`)

## Gaps & Tech Debt
- [Feature Gap 1]: `llm-nvim` lacks exposed interactive UI flows for advanced arguments. Options for Extractions (`-x`, `--xl`), Schema Options (`--schema`, `--schema-multi`), Output Control (`--json`, `-R`), explicit attachment type (`--at`), token usage (`-u`), and Extended tool options (`--td`, `--ta`, `--cl`, `--functions`) are parsed in `lua/llm/commands.lua` but have no user-facing UI flows.
- [Tech Debt 1]: In `lua/llm/managers/embeddings_manager.lua`, `vim.fn.shellescape` is inappropriately used for appending simple subcommands and arguments, which wraps them in single quotes and breaks downstream CLI parsing.
- [Tech Debt 2]: In `lua/llm/commands.lua` within the `on_stdout` callback inside `prepare_response_buffer_and_callbacks`, it attempts to process partial output incorrectly by appending trailing newlines unconditionally when passing chunks to `ui.append_to_buffer`.

## Ranked Backlog
1. Fix improper `on_stdout` chunk processing in `lua/llm/commands.lua` (Tech Debt 2) - High Impact / Low Effort - Fix string buffering logic to avoid corrupting streaming output.
2. Fix `vim.fn.shellescape` usage in `lua/llm/managers/embeddings_manager.lua` (Tech Debt 1) - High Impact / Low Effort - Replace `vim.fn.shellescape` with string concatenation for simple CLI arguments.
3. Expose interactive UI for advanced options (Feature Gap 1) - Medium Impact / High Effort - Provide UI flows for advanced arguments parsed in `commands.lua` (Extractions, Schemas, Tools, Output Control, etc.).
