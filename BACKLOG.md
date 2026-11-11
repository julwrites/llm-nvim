## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- Text generation (`prompt`): Execute a prompt.
- Chat sessions (`chat`): Hold an ongoing chat with a model.
- Piped input: Sending text to the model via standard input or from a file.
- Model aliases (`aliases`): Manage model aliases.
- Embeddings and Vector Search (`embed`, `embed-multi`, `embed-models`, `similar`, `collections`): Embed text and store or return the result, view and manage collections.
- Logs (`logs`): Tools for exploring logged prompts and responses.
- Extract code blocks (`-x`, `--extract`, `--xl`, `--extract-last`): Extract first or last fenced code block.
- JSON output (`--json`): Output the response as JSON.
- Hide reasoning (`-R`, `--hide-reasoning`): Hide reasoning output.
- Token usage (`-u`, `--usage`): Show token usage.
- Attachments (`-a`, `--attachment`, `--at`, `--attachment-type`): Attachment path or URL or -, Attachment with explicit mimetype.
- Asynchronous execution (`--async`): Run prompt asynchronously.
- Continue conversation (`-c`, `--continue`, `--cid`, `--conversation`): Continue the most recent conversation.
- Database (`-d`, `--database`): Path to log database.
- Logging (`--log`, `--no-log`): Log prompt and response to the database, Don't log to database.

## Gaps & Tech Debt
- Feature Gap: No interface exposed for tools exploring logged prompts and responses (`logs`).
- Feature Gap: No interactive UI flows or Neovim commands exposed to utilize the Extract code blocks options (`-x`, `--xl`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for Output Control options (`--json`, `-R`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for Token usage tracking (`-u`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for explicit attachment type (`--at`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for Database explicit path (`-d`).
- Feature Gap: No interactive UI flows or Neovim commands exposed for Asynchronous execution (`--async`).
- Tech Debt: Widespread use of synchronous, blocking file I/O operations (`io.open`) which block the Neovim event loop. Explicitly verified in `lua/llm/managers/custom_openai.lua` (lines 41, 203, 391, 492), `lua/llm/managers/keys_manager.lua` (lines 63, 87), and `lua/llm/managers/schemas_manager.lua` (lines 38, 57, 252).

## Ranked Backlog
1. Refactor synchronous `io.open` calls in manager modules (`lua/llm/managers/custom_openai.lua`, `lua/llm/managers/keys_manager.lua`, `lua/llm/managers/schemas_manager.lua`) - High Impact / Medium Effort - Convert blocking I/O calls to asynchronous alternatives.
2. Implement UI flows for Extract code blocks (`-x`, `--xl`) - Medium Impact / Low Effort - Add Neovim commands or keymaps to extract code blocks directly from model responses.
3. Implement interface for exploring logged prompts (`logs`) - Medium Impact / High Effort - Add a unified manager view to browse past interactions.
4. Implement UI flows for explicit attachment type (`--at`) - Medium Impact / High Effort - Create a UI mechanism to pass explicit mimetypes for attachments.
5. Implement UI flows for Database explicit path (`-d`) - Medium Impact / Medium Effort - Allow explicit passing of log database location via plugin configuration or UI.
6. Implement UI flows for Output Control (`--json`, `-R`) - Low Impact / Low Effort - Expose toggles or configuration for JSON output and hiding reasoning.
7. Expose Token usage tracking (`-u`) - Low Impact / Low Effort - Add an option to display token usage statistics in the Neovim UI after a prompt completes.
8. Implement UI flows for Asynchronous execution (`--async`) - Low Impact / High Effort - Add asynchronous prompt execution options to the Neovim interface.
