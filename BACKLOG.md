## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- Prompting (`llm prompt`): Execute a prompt.
- Ongoing Chat (`llm chat`): Hold an ongoing chat with a model.
- Model Aliases (`llm aliases`): Manage model aliases.
- Collections (`llm collections`): View and manage collections of embeddings.
- Embeddings (`llm embed`): Embed text and store or return the result.
- Embedding Models (`llm embed-models`): Manage available embedding models.
- Fragments (`llm fragments`): Manage fragments that are stored in the database.
- Key Management (`llm keys`): Manage stored API keys for different models.
- Logs (`llm logs`): Tools for exploring logged prompts and responses.
- Models (`llm models`): Manage available models.
- Plugins (`llm plugins`): List installed plugins.
- Templates (`llm templates`): Manage stored prompt templates.
- Multi-modal attachments (`-a` / `--attachment`): Call models with attachments like images.
- Tools / Function Calling (`-T`, `--tool`, `--functions`): Make tools available to the model.
- Extractions (`-x` / `--extract`): Extract just the content of the first fenced code block.

## Gaps & Tech Debt
- [Feature Gap 1]: Missing support for Multi-modal attachments (`-a`, `--attachment`).
- [Feature Gap 2]: Missing support for Tools / Function Calling (`-T`, `--tool`, `--functions`).
- [Feature Gap 3]: Missing support for Embeddings (`embed`, `embed-models`, `embed-multi`, `collections`, `similar`).
- [Feature Gap 4]: Missing support for Model Aliases management (`aliases`).
- [Feature Gap 5]: Missing integration with Logs (`logs`) for exploring past prompts and responses.
- [Feature Gap 6]: Missing support for Extractions (`-x`, `--extract`) in prompt command execution (only implemented in template creation/saving, but not in general `llm prompt` calls).
- [Tech Debt 1]: Increase code coverage to 80% (currently below target, tracked in CODE-QUALITY-005).
- [Tech Debt 2]: Improve async job handling robustness and line buffering edge cases in `lua/llm/core/utils/job.lua`.
- [Tech Debt 3]: Improve Lua/Python interoperability performance and reliability when interacting with Python `llm` CLI.

## Ranked Backlog
1.1 [Feature Gap 2] - [High Impact/High Effort] - Implement Tools / Function Calling support to allow models to execute tools within Neovim - Create `tools_manager.lua` and `tools_view.lua` to list and manage tools.
1.2 [Feature Gap 2] - [High Impact/High Effort] - Implement Tools / Function Calling support to allow models to execute tools within Neovim - Integrate tools view into `unified_manager.lua` and `facade.lua`.
1.3 [Feature Gap 2] - [High Impact/High Effort] - Implement Tools / Function Calling support to allow models to execute tools within Neovim - Update `:LLM` command in `commands.lua` and `api.lua` to support passing tool arguments.
1.4 [Feature Gap 2] - [High Impact/High Effort] - Implement Tools / Function Calling support to allow models to execute tools within Neovim - Write tests in `tests/spec/tools_spec.lua` and update docs (`CRITICAL-005-add-tools-support.md`).
2. [Feature Gap 3] - [Medium Impact/High Effort] - Implement Embeddings support to allow searching similar code and semantic search.
3. [Tech Debt 1] - [High Impact/Medium Effort] - Increase Code Coverage to 80% to ensure core logic and features do not regress.
4. [Tech Debt 2] - [High Impact/Low Effort] - Improve async job handling robustness in `job.lua` (e.g. process exiting mid-buffer).
5. [Tech Debt 3] - [Medium Impact/Medium Effort] - Optimize Lua/Python interoperability for smoother command line execution.
6. [Feature Gap 1] - [Medium Impact/Medium Effort] - Implement Multi-modal attachments support (e.g., attaching images to prompts if terminal/UI supports it, or passing paths).
7. [Feature Gap 6] - [Medium Impact/Low Effort] - Implement Extractions (`-x`/`--extract`) support in `lua/llm/commands.lua` for prompt generation.
8. [Feature Gap 4] - [Low Impact/Low Effort] - Implement Model Aliases management.
9. [Feature Gap 5] - [Low Impact/Low Effort] - Expose `logs` command functionally to explore past prompts/responses inside Neovim.