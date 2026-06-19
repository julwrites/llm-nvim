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
- Feature Gap: Missing support for Multi-modal attachments (`-a`, `--attachment`).
- Feature Gap: Missing support for Tools / Function Calling (`-T`, `--tool`, `--functions`).
- Feature Gap: Missing support for Embeddings (`embed`, `embed-models`, `embed-multi`, `collections`, `similar`).
- Feature Gap: Missing support for Model Aliases management (`aliases`).
- Feature Gap: Missing integration with Logs (`logs`) for exploring past prompts and responses.
- Feature Gap: Missing support for Extractions (`-x`, `--extract`) in prompt command execution (only implemented in template creation/saving, but not in general `llm prompt` calls).

## Ranked Backlog
1. [Feature Gap] - [High Impact/High Effort] - Implement Tools / Function Calling support to allow models to execute tools within Neovim.
2. [Feature Gap] - [Medium Impact/High Effort] - Implement Embeddings support to allow searching similar code and semantic search.
3. [Feature Gap] - [Medium Impact/Medium Effort] - Implement Multi-modal attachments support (e.g., attaching images to prompts if terminal/UI supports it, or passing paths).
4. [Feature Gap] - [Medium Impact/Low Effort] - Implement Extractions (`-x`/`--extract`) support in `lua/llm/commands.lua` for prompt generation.
5. [Feature Gap] - [Low Impact/Low Effort] - Implement Model Aliases management.
6. [Feature Gap] - [Low Impact/Low Effort] - Expose `logs` command functionally to explore past prompts/responses inside Neovim.
