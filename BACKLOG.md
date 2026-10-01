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
- [Tech Debt 1]: Output formatting in `lua/llm/core/utils/ui.lua` (`content_to_lines`) previously split text via `gmatch("[^\r\n]+")`, completely stripping consecutive/empty blank lines and breaking markdown structures.
- [Tech Debt 2]: In `lua/llm/chat.lua`, the `on_stdout` callback processes `data` chunks using blind manual iteration rather than efficiently handling chunk accumulation using `table.concat(data, "\n")` which can handle internal newlines efficiently.
- [Tech Debt 3]: In `lua/llm/commands.lua`, the `on_stdout` callback processes `data` chunks using blind manual iteration rather than efficiently handling chunk accumulation using `table.concat(data, "\n")` which can handle internal newlines efficiently.
- [Tech Debt 4]: The `mock_vim.lua` test environment contains a flawed implementation of `vim.split` that incorrectly drops empty strings using `gmatch("([^" .. sep .. "]+)")`, which masks issues with markdown structure preservation in the unit tests.

## Ranked Backlog
1. Refactor chunk accumulation in Chat callback (Tech Debt 2) - Medium Impact / Low Effort - Update `lua/llm/chat.lua`'s `on_stdout` to efficiently handle chunk accumulation using `table.concat(data, "\n")` to avoid manual string concatenation loops.
2. Refactor chunk accumulation in Commands callback (Tech Debt 3) - Medium Impact / Low Effort - Update `lua/llm/commands.lua`'s `on_stdout` to efficiently handle chunk accumulation using `table.concat(data, "\n")` to avoid manual string concatenation loops.
3. Fix vim.split mock implementation (Tech Debt 4) - High Impact / Low Effort - Update `M.split` in `tests/spec/mock_vim.lua` to properly preserve empty lines.
4. Expose interactive UI for advanced options (Feature Gap 1) - Medium Impact / High Effort - Provide UI flows for advanced arguments parsed in `commands.lua` (Extractions, Schemas, Tools, Output Control, etc.).
5. Fix markdown parsing in UI formatter (Tech Debt 1) - High Impact / Low Effort - Update `content_to_lines` in `lua/llm/core/utils/ui.lua` to properly preserve empty lines when formatting content.
