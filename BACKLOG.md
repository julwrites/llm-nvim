## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- Prompting (`llm prompt`): Execute a prompt.
- Ongoing Chat (`llm chat`): Hold an ongoing chat with a model.
- Model Aliases (`llm aliases`): Manage model aliases.
- Collections (`llm collections`): View and manage collections of embeddings.
- Embeddings (`llm embed`, `llm embed-multi`): Embed text and store or return the result.
- Embedding Models (`llm embed-models`): Manage available embedding models.
- Fragments (`llm fragments`): Manage fragments that are stored in the database.
- Key Management (`llm keys`): Manage stored API keys for different models.
- Logs (`llm logs`): Tools for exploring logged prompts and responses.
- Models (`llm models`): Manage available models.
- Plugins (`llm plugins`, `llm install`, `llm uninstall`): Manage installed plugins.
- Schemas (`llm schemas`): Manage stored schemas.
- Similar (`llm similar`): Return top N similar IDs from a collection.
- Templates (`llm templates`): Manage stored prompt templates.
- Tools (`llm tools`): Manage tools that can be made available to LLMs.
- Multi-modal attachments (`-a` / `--attachment`): Call models with attachments like images.
- Explicit Attachment Mimetypes (`--at` / `--attachment-type`): Attachment with explicit mimetype.
- Tools / Function Calling Options (`-T`, `--tool`, `--functions`, `--td`, `--ta`, `--cl`): Make tools available to the model.
- Extractions (`-x` / `--extract`, `--xl` / `--extract-last`): Extract content of fenced code blocks.
- Model Options (`-o` / `--option`): key/value options for the model.
- Template Parameters (`-p` / `--param`): Parameters for template.
- Usage tracking (`-u` / `--usage`): Show token usage.
- System Fragments (`--sf` / `--system-fragment`): Fragment to add to system prompt.
- Schema Execution (`--schema`, `--schema-multi`): JSON schema to use for prompt results.
- Continue Prompt Conversation (`-c`, `--continue`, `--cid`, `--conversation`): Continue the most recent or specific conversation.
- Logging Options (`--log`, `-n` / `--no-log`, `-d` / `--database`): Control SQLite logging behavior.
- Query Selection (`-q` / `--query`): Use first model matching strings.
- Save as Template (`--save`): Save prompt with a template name.
- Async Execution (`--async`): Run prompt asynchronously.
- Stream Control (`--no-stream`): Do not stream output.

## Gaps & Tech Debt
- [Gap 1]: Missing support for Tools / Function Calling (`-T`, `--tool`, `--functions`, `tools`, `--td`, `--ta`, `--cl`).
- [Gap 2]: Missing support for Embeddings (`embed`, `embed-models`, `embed-multi`, `collections`, `similar`).
- [Gap 3]: Missing support for Multi-modal attachments (`-a`, `--attachment`, `--at`, `--attachment-type`).
- [Gap 4]: Missing integration with Logs (`logs`) for exploring past prompts and responses, along with logging options (`--log`, `--no-log`, `--database`).
- [Gap 5]: Missing support for Extractions (`-x`, `--extract`, `--xl`, `--extract-last`) in prompt command execution (only implemented in template creation/saving, but not in general `llm prompt` calls).
- [Gap 6]: Missing support for Model Options (`-o`, `--option`).
- [Gap 7]: Missing support for Template Parameters (`-p`, `--param`).
- [Gap 8]: Missing support for Usage tracking (`-u`, `--usage`).
- [Gap 9]: Missing support for System Fragments (`--sf`, `--system-fragment`).
- [Gap 10]: Missing support for Schemas in prompt generation (`--schema`, `--schema-multi`).
- [Gap 11]: Missing support for Continue Conversation in standard prompt command (`-c`, `--continue`, `--cid`, `--conversation`).
- [Gap 12]: Missing support for Stream Control (`--no-stream`) and Async Execution (`--async`).
- [Gap 13]: Missing support for Query Selection (`-q`, `--query`).
- [Gap 14]: Missing support for Save as Template (`--save`) directly from prompt command.
- [Tech Debt 1]: Increase code coverage from ~46.57% to 80% (currently below target, tracked in CODE-QUALITY-005).
- [Tech Debt 2]: Improve async job handling robustness and line buffering edge cases in `lua/llm/core/utils/job.lua`.
- [Tech Debt 3]: Optimize Lua/Python interoperability for smoother command line execution.
- [Tech Debt 4]: `M.interactive_prompt_with_fragments` in `fragments_manager.lua` is not fully tested.
- [Tech Debt 5]: Custom YAML parsing in `custom_openai.lua` might be fragile.

## Ranked Backlog
1. [Gap 1.1] - [High Impact/Medium Effort] - Create core `tools_manager.lua` to interface with the llm CLI to list and execute tools.
1. [Gap 1.2] - [High Impact/Medium Effort] - Create UI components (`tools_view.lua`) and integrate with `unified_manager.lua` and `facade.lua`.
1. [Gap 1.3] - [Medium Impact/Low Effort] - Update `:LLM` command in `commands.lua` and `api.lua` to parse and pass tool arguments.
1. [Gap 1.4] - [High Impact/Low Effort] - Write tests for the new tools features in `tests/spec/tools_spec.lua` and add documentation (`CRITICAL-005-add-tools-support.md`).
2. [Gap 2] - [Medium Impact/High Effort] - Implement Embeddings support. Create `embeddings_manager.lua` and `embeddings_view.lua`. Integrate embeddings view into `unified_manager.lua`. Add `:LLMEmbed` command support to generate and store embeddings. Add `:LLMSimilar` command support to search code.
3. [Tech Debt 1] - [High Impact/High Effort] - Increase Code Coverage to 80% to ensure core logic and features do not regress. Write tests for `lua/llm/managers/custom_openai.lua`, `lua/llm/managers/templates_manager.lua`, `lua/llm/managers/models_manager.lua`, and other managers (`schemas_manager`, `plugins_manager`, `fragments_manager`, etc).
4. [Tech Debt 2] - [High Impact/Low Effort] - Improve async job handling robustness in `job.lua` (e.g. process exiting mid-buffer).
5. [Tech Debt 3] - [Medium Impact/Medium Effort] - Optimize Lua/Python interoperability for smoother command line execution.
6. [Gap 3] - [Medium Impact/Medium Effort] - Implement Multi-modal attachments support (e.g., attaching images to prompts if terminal/UI supports it, or passing paths).
7. [Gap 6] - [Medium Impact/Low Effort] - Implement Model Options (`-o`/`--option`) support.
8. [Gap 7] - [Medium Impact/Low Effort] - Implement Template Parameters (`-p`/`--param`) support.
9. [Gap 5] - [Medium Impact/Low Effort] - Implement Extractions (`-x`/`--extract`, `--xl`/`--extract-last`) support in `lua/llm/commands.lua` for prompt generation.
10. [Gap 4] - [Low Impact/Low Effort] - Expose `logs` command functionally to explore past prompts/responses inside Neovim and configure Logging Options.
11. [Gap 8] - [Low Impact/Low Effort] - Expose token usage tracking (`-u`/`--usage`).
12. [Gap 10] - [Low Impact/Low Effort] - Implement Schemas in prompt generation (`--schema`, `--schema-multi`).
13. [Gap 9] - [Low Impact/Low Effort] - Implement System Fragments (`--sf`, `--system-fragment`).
14. [Gap 11] - [Low Impact/Low Effort] - Implement Continue Conversation in standard prompt command (`-c`, `--continue`, `--cid`, `--conversation`).
15. [Gap 12] - [Low Impact/Low Effort] - Implement Stream Control (`--no-stream`) and Async Execution (`--async`).
16. [Gap 13] - [Low Impact/Low Effort] - Implement Query Selection (`-q`, `--query`).
17. [Gap 14] - [Low Impact/Low Effort] - Implement Save as Template (`--save`) directly from prompt command.
18. [Tech Debt 4] - [Low Impact/Medium Effort] - Write tests for `M.interactive_prompt_with_fragments` in `fragments_manager.lua`.
19. [Tech Debt 5] - [Low Impact/Medium Effort] - Refactor custom YAML parsing in `custom_openai.lua` to be more robust.
