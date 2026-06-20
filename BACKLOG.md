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
- Schemas (`llm schemas`): Manage stored schemas.
- Templates (`llm templates`): Manage stored prompt templates.
- Tools (`llm tools`): Manage tools that can be made available to LLMs.
- Multi-modal attachments (`-a` / `--attachment`): Call models with attachments like images.
- Tools / Function Calling (`-T`, `--tool`, `--functions`): Make tools available to the model.
- Extractions (`-x` / `--extract`): Extract just the content of the first fenced code block.

## Gaps & Tech Debt
- [Feature Gap 1]: Missing support for Multi-modal attachments (`-a`, `--attachment`).
- [Feature Gap 2]: Missing support for Tools / Function Calling (`-T`, `--tool`, `--functions`, `tools`).
- [Feature Gap 3]: Missing support for Embeddings (`embed`, `embed-models`, `embed-multi`, `collections`, `similar`).
- [Feature Gap 4]: Missing integration with Logs (`logs`) for exploring past prompts and responses.
- [Feature Gap 5]: Missing support for Extractions (`-x`, `--extract`) in prompt command execution (only implemented in template creation/saving, but not in general `llm prompt` calls).
- [Tech Debt 1]: Fix `run_llm_command_async` nil value error in `tests/spec/core/loaders_spec.lua` and `lua/llm/core/loaders.lua` which is breaking the test suite.
- [Tech Debt 2]: Increase code coverage to 80% (currently below target, tracked in CODE-QUALITY-005).
- [Tech Debt 3]: Improve async job handling robustness and line buffering edge cases in `lua/llm/core/utils/job.lua`.
- [Tech Debt 4]: Improve Lua/Python interoperability performance and reliability when interacting with Python `llm` CLI.

## Ranked Backlog
1.1 [Feature Gap 2] - [High Impact/High Effort] - Implement Tools / Function Calling support to allow models to execute tools within Neovim - Create `tools_manager.lua` and `tools_view.lua` to list and manage tools.
1.2 [Feature Gap 2] - [High Impact/High Effort] - Implement Tools / Function Calling support to allow models to execute tools within Neovim - Integrate tools view into `unified_manager.lua` and `facade.lua`.
1.3 [Feature Gap 2] - [High Impact/High Effort] - Implement Tools / Function Calling support to allow models to execute tools within Neovim - Update `:LLM` command in `commands.lua` and `api.lua` to support passing tool arguments.
1.4 [Feature Gap 2] - [High Impact/High Effort] - Implement Tools / Function Calling support to allow models to execute tools within Neovim - Write tests in `tests/spec/tools_spec.lua` and update docs (`CRITICAL-005-add-tools-support.md`).
2.1 [Feature Gap 3] - [Medium Impact/High Effort] - Implement Embeddings support - Create `embeddings_manager.lua` and `embeddings_view.lua`.
2.2 [Feature Gap 3] - [Medium Impact/High Effort] - Implement Embeddings support - Integrate embeddings view into `unified_manager.lua`.
2.3 [Feature Gap 3] - [Medium Impact/High Effort] - Implement Embeddings support - Add `:LLMEmbed` command support to generate and store embeddings.
2.4 [Feature Gap 3] - [Medium Impact/High Effort] - Implement Embeddings support - Add `:LLMSimilar` command support to search code.
3. [Tech Debt 1] - [High Impact/Low Effort] - Fix `run_llm_command_async` nil value error breaking test suite in `loaders.lua` and tests.
4. [Tech Debt 2] - [High Impact/Medium Effort] - Increase Code Coverage to 80% to ensure core logic and features do not regress.
5. [Tech Debt 3] - [High Impact/Low Effort] - Improve async job handling robustness in `job.lua` (e.g. process exiting mid-buffer).
6. [Tech Debt 4] - [Medium Impact/Medium Effort] - Optimize Lua/Python interoperability for smoother command line execution.
7. [Feature Gap 1] - [Medium Impact/Medium Effort] - Implement Multi-modal attachments support (e.g., attaching images to prompts if terminal/UI supports it, or passing paths).
8. [Feature Gap 5] - [Medium Impact/Low Effort] - Implement Extractions (`-x`/`--extract`) support in `lua/llm/commands.lua` for prompt generation.
9. [Feature Gap 4] - [Low Impact/Low Effort] - Expose `logs` command functionally to explore past prompts/responses inside Neovim.
