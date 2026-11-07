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

## Gaps & Tech Debt
- Feature Gap: No interactive UI flows or Neovim commands exposed to utilize the Extract code blocks options (`-x`, `--xl`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for Output Control options (`--json`, `-R`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for Token usage tracking (`-u`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for explicit attachment type (`--at`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for Extended Tool Options (`--td`, `--ta`, `--cl`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for Database explicit path (`-d`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for Asynchronous execution (`--async`).
- Tech Debt: Widespread use of synchronous, blocking file I/O operations (`io.open`) which block the Neovim event loop. Explicitly verified in `lua/llm/managers/custom_openai.lua` and `lua/llm/managers/keys_manager.lua`.

## Ranked Backlog
1. Refactor `load_custom_openai_models` in `lua/llm/managers/custom_openai.lua` to async - High Impact / High Effort - Refactor load and its dependents to use `vim.uv` async APIs.\
2. Refactor `debug_custom_openai_models` in `lua/llm/managers/custom_openai.lua` to async - Low Impact / Medium Effort - Refactor debug and its dependents to use `vim.uv` async APIs.\
3. Refactor `create_sample_yaml_file` in `lua/llm/managers/custom_openai.lua` to async - Low Impact / Medium Effort - Refactor create_sample and its dependents to use `vim.uv` async APIs.\
4. Refactor `add_custom_openai_model` in `lua/llm/managers/custom_openai.lua` to async - Medium Impact / High Effort - Refactor add and its dependents to use `vim.uv` async APIs.\
5. Refactor `delete_custom_openai_model` in `lua/llm/managers/custom_openai.lua` to async - Medium Impact / High Effort - Refactor delete and its dependents to use `vim.uv` async APIs.
6. Refactor synchronous `io.open` calls in `lua/llm/managers/keys_manager.lua` - High Impact / Medium Effort - Convert blocking I/O calls to asynchronous `vim.uv` alternatives to prevent freezing the editor.
7. Implement UI flows for Extract code blocks (`-x`, `--xl`) - Medium Impact / Low Effort - Add Neovim commands or keymaps to extract code blocks directly from model responses.
8. Implement UI flows for explicit attachment type (`--at`) - Medium Impact / High Effort - Create a UI mechanism to pass explicit mimetypes for attachments.
9. Implement UI flows for Database explicit path (`-d`) - Medium Impact / Medium Effort - Allow explicit passing of log database location via plugin configuration or UI.
10. Implement UI flows for Output Control (`--json`, `-R`) - Low Impact / Low Effort - Expose toggles or configuration for JSON output and hiding reasoning.
11. Expose Token usage tracking (`-u`) - Low Impact / Low Effort - Add an option to display token usage statistics in the Neovim UI after a prompt completes.
12. Implement UI flows for Extended Tool Options (`--td`, `--ta`, `--cl`) - Low Impact / High Effort - Provide UI to configure tool debugging, approval, and chain limits.
13. Implement UI flows for Asynchronous execution (`--async`) - Low Impact / High Effort - Add asynchronous prompt execution options to the Neovim interface.
