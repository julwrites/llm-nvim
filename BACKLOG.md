## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- Text generation (`prompt`): Execute a prompt and receive text completion.
- Chat sessions (`chat`): Hold an ongoing chat with a model.
- Piped input: Sending text to the model via standard input or from a file.
- Model aliases (`aliases`): Manage shortcuts for longer model names.
- Extract code blocks (`-x`, `--extract`, `--xl`, `--extract-last`): Extract fenced code blocks from the response.
- JSON output (`--json`): Output the response as JSON.
- Hide reasoning (`-R`, `--hide-reasoning`): Hide reasoning output from the model.
- Token usage (`-u`, `--usage`): Show token usage for the prompt.
- Attachments (`-a`, `--attachment`, `--at`, `--attachment-type`): Attach files or images to prompts.
- Tools and functions (`-T`, `--tool`, `--functions`, `--td`, `--ta`, `--cl`): Make tools available to the model.
- System prompts and fragments (`-s`, `--system`, `-f`, `--fragment`, `--sf`): Append predefined text or files.
- Templates (`-t`, `--template`, `-p`, `--param`, `--save`): Use and manage prompt templates.
- Asynchronous execution (`--async`): Run prompt asynchronously.
- Continue conversation (`-c`, `--continue`, `--cid`, `--conversation`): Continue previous conversations.
- Database (`-d`, `--database`): Specify path to log database.
- Logging (`--log`, `--no-log`): Control logging to the database.
- Structured output schemas (`--schema`, `--schema-multi`): Define a JSON schema for the output.

## Gaps & Tech Debt
- Feature Gap: No interactive UI flows or Neovim commands exposed to utilize the Extract code blocks options (`-x`, `--xl`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for Output Control options (`--json`, `-R`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for Token usage tracking (`-u`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for explicit attachment type (`--at`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for Extended Tool Options (`--td`, `--ta`, `--cl`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for Database explicit path (`-d`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for Asynchronous execution (`--async`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for Structured output schemas (`--schema`, `--schema-multi`).
- Tech Debt: Widespread use of synchronous, blocking file I/O operations (`io.open`) which block the Neovim event loop. Explicitly verified in `lua/llm/managers/custom_openai.lua`, `lua/llm/managers/keys_manager.lua`, `lua/llm/core/utils/text.lua`, `lua/llm/core/utils/file_utils.lua`, `lua/llm/core/utils/shell.lua`, `lua/llm/core/data/cache.lua`, `lua/llm/managers/schemas_manager.lua`.

## Ranked Backlog
1. Refactor synchronous `io.open` calls across codebase (`lua/llm/managers/custom_openai.lua`, `lua/llm/managers/keys_manager.lua`, `lua/llm/core/utils/text.lua`, `lua/llm/core/utils/file_utils.lua`, `lua/llm/core/utils/shell.lua`, `lua/llm/core/data/cache.lua`, `lua/llm/managers/schemas_manager.lua`) - High Impact / High Effort - Convert blocking I/O calls to asynchronous alternatives (`vim.uv`) to prevent freezing the editor.
2. Implement UI flows for Structured output schemas (`--schema`, `--schema-multi`) - High Impact / Medium Effort - Add Neovim UI or commands to define and send schemas for structured outputs.
3. Implement UI flows for Extract code blocks (`-x`, `--xl`) - Medium Impact / Low Effort - Add Neovim commands or keymaps to extract code blocks directly from model responses.
4. Implement UI flows for explicit attachment type (`--at`) - Medium Impact / High Effort - Create a UI mechanism to pass explicit mimetypes for attachments.
5. Implement UI flows for Database explicit path (`-d`) - Medium Impact / Medium Effort - Allow explicit passing of log database location via plugin configuration or UI.
6. Implement UI flows for Output Control (`--json`, `-R`) - Low Impact / Low Effort - Expose toggles or configuration for JSON output and hiding reasoning.
7. Expose Token usage tracking (`-u`) - Low Impact / Low Effort - Add an option to display token usage statistics in the Neovim UI after a prompt completes.
8. Implement UI flows for Extended Tool Options (`--td`, `--ta`, `--cl`) - Low Impact / High Effort - Provide UI to configure tool debugging, approval, and chain limits.
9. Implement UI flows for Asynchronous execution (`--async`) - Low Impact / High Effort - Add asynchronous prompt execution options to the Neovim interface.