## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- Text Generation (prompt command): Core completion functionality
- Chat (chat command): Ongoing multi-turn conversation
- Tools / Function Calling: Passing functions to models via JSON schema or files
- Extended Tool Options: Detailed tool execution and chain limits
- Multi-modal attachments: Passing images and documents
- Extractions: Parsing codeblocks out of markdown responses
- Extract Last: Extracting the last fenced code block
- Model Options: Setting specific parameters like temperature
- Template Options: Using templates with specific variables
- Template Parameters: Parameters for template
- System Fragments: Adding fragments to system prompts
- Embeddings: 'embed', 'collections', 'similar', and 'embed-multi' commands
- Database Selection: Specifying the path to the log database
- API Key override: Ad-hoc API key usage
- Usage tracking: Showing token usage
- Continue Conversation: Continuing from a specific conversation ID
- Schema Options: Constraining output to JSON Schema
- Save as Template: Saving prompts as templates
- Logging Overrides: Disabling or enabling logging to database
- Query Selection: Using first model matching a query string
- Stream Control: Disabling streaming output
- Async Execution: Running prompts asynchronously

## Gaps & Tech Debt
- [Tech Debt 1]: Streaming chunk callback in `lua/llm/core/utils/job.lua` (`on_stdout`) doesn't efficiently use `table.concat(data, "\n")` for accumulation and improperly mutates lines or incorrectly appends trailing newlines, which breaks stream buffering.
- [Tech Debt 2]: Output formatting in `lua/llm/core/utils/ui.lua` splits text via `gmatch("[^\r\n]+")` (`content_to_lines`), which strips consecutive/empty blank lines and breaks markdown structures.
- [Feature Gap 1]: `llm-nvim` lacks exposed interactive UI flows for Extractions (`-x`, `--xl`), Schema Options (`--schema`, `--schema-multi`), Output Control (`--json`, `-R`), explicit attachment type (`--at`), token usage (`-u`), and tool options (`--td`, `--ta`, `--cl`, `--functions`). These are parsed in `commands.lua` but have no UI.

## Ranked Backlog
1. Fix stream buffer accumulation in `on_stdout` (Tech Debt 1) - High Impact / Low Effort - Fix string buffering by accumulating chunks with `table.concat(data, "\n")` without mutating arrays and without artificial newlines.
2. Fix stripping of blank lines in UI (Tech Debt 2) - High Impact / Low Effort - Update `content_to_lines` to use standard line splitting rather than `gmatch("[^\r\n]+")` to preserve empty lines in streaming output.
3. Expose interactive UI for advanced options (Feature Gap 1) - Medium Impact / High Effort - Provide UI flows for advanced arguments parsed in `commands.lua` (Extractions, Schemas, Tools, etc.).