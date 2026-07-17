## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- [Prompting]: Execute a prompt.
- [Ongoing Chat]: Hold an ongoing chat with a model.
- [Model Aliases]: Manage model aliases.
- [Models]: View available models.
- [Templates]: Manage stored prompt templates.
- [Multi-modal attachments]: Call models with attachments like images.
- [Tools / Function Calling]: Make tools available to the model.
- [Extractions]: Extract content of fenced code blocks.
- [Model Options]: Key/value options for the model.
- [Template Parameters]: Parameters for template.
- [Usage tracking]: Show token usage.
- [Continue Conversation]: Continue the most recent or specific conversation.
- [Query Selection]: Use first model matching strings.
- [Save as Template]: Save prompt with a template name.
- [Async Execution]: Run prompt asynchronously.
- [Stream Control]: Do not stream output.
- [Schemas]: Manage stored schemas and use them in prompts.
- [System Fragment]: Add fragment to system prompt.
- [Embeddings]: Create embeddings, find similar items, and manage collections.

## Gaps & Tech Debt
- [Gap 1]: Missing support for Multi-modal attachments (`-a`, `--attachment`, `--at`, `--attachment-type`).
- [Gap 2]: Missing support for Usage tracking (`-u`, `--usage`).
- [Gap 3]: Missing support for Extended Tool Options (`--functions`, `--td`, `--ta`, `--cl`).
- [Gap 5]: Missing support for Query Selection (`-q`, `--query`).
- [Gap 6]: Missing support for Stream Control (`--no-stream`) and Async Execution (`--async`).
- [Gap 7]: Missing support for Schema Options (`--schema`, `--schema-multi`) in prompting.
- [Gap 8]: Missing support for Save as Template (`--save`).
- [Gap 9]: Missing support for Extract Last (`--xl`, `--extract-last`).
- [Tech Debt 1]: Increase overall code coverage. Test coverage is currently well below the 80% target.
- [Tech Debt 2]: Improve async job handling robustness in `job.lua` based on known failure patterns.
- [Tech Debt 3]: Test coverage missing for `M.interactive_prompt_with_fragments` in `commands.lua`.
- [Tech Debt 5]: Refactor duplicated command construction logic across `M.prompt`, `M.prompt_with_current_file`, and `M.prompt_with_selection` in `lua/llm/commands.lua`.
- [Gap 11]: Missing support for System Fragment (`--sf`, `--system-fragment`).
- [Gap 12.1.1a]: Core Logic - Create `embeddings_manager.lua` with the underlying API call for `embed`.
- [Gap 12.1.1b]: UI/Commands - Update `commands.lua` and `plugin/llm.lua` to expose the `:LLM embed` command.
- [Gap 12.1.1c]: Testing - Add unit tests for the new embeddings manager and commands.
- [Gap 12.1.2]: Missing support for Embeddings commands (`embed-multi`).
- [Gap 12.2]: Missing support for Embeddings commands (`similar`).
- [Gap 12.3]: Missing support for Embeddings commands (`collections` and `aliases`).
- [Gap 13]: Missing support for API Key override (`--key`).

## Ranked Backlog
1. [Gap 12.1.1a] - [High Impact/Medium Effort] - Core Logic - Create `embeddings_manager.lua` with the underlying API call for `embed`.
2. [Gap 12.1.1b] - [High Impact/Medium Effort] - UI/Commands - Update `commands.lua` and `plugin/llm.lua` to expose the `:LLM embed` command.
3. [Gap 12.1.1c] - [High Impact/Medium Effort] - Testing - Add unit tests for the new embeddings manager and commands.
4. [Gap 12.1.2] - [High Impact/Medium Effort] - Add support for Embeddings commands (`embed-multi`).
5. [Gap 12.2] - [High Impact/Medium Effort] - Add support for Embeddings commands (`similar`).
6. [Gap 12.3] - [High Impact/Medium Effort] - Add support for Embeddings commands (`collections` and `aliases`).
7. [Gap 7] - [Medium Impact/Low Effort] - Add support for Schema Options (`--schema`, `--schema-multi`) in prompts.
8. [Gap 8] - [Medium Impact/Low Effort] - Add support to Save as Template (`--save`).
9. [Tech Debt 5] - [Medium Impact/Medium Effort] - Refactor duplicated command construction logic in `lua/llm/commands.lua`.
10. [Gap 1] - [Medium Impact/Medium Effort] - Implement Multi-modal attachment support for models that accept images or other data types (`-a`, `--attachment`, `--at`, `--attachment-type`).
11. [Gap 3] - [Medium Impact/Medium Effort] - Implement Extended Tool Options (`--functions`, `--td`, `--ta`, `--cl`).
12. [Tech Debt 1] - [Medium Impact/Medium Effort] - Increase overall code coverage. Test coverage is currently well below the 80% target.
13. [Tech Debt 2] - [Medium Impact/Medium Effort] - Enhance async job handling logic in `job.lua` for edge cases.
14. [Gap 2] - [Low Impact/Low Effort] - Expose token Usage tracking (`-u`, `--usage`) visually after execution.
15. [Gap 5] - [Low Impact/Low Effort] - Enable dynamic Query Selection (`-q`, `--query`).
16. [Gap 6] - [Low Impact/Low Effort] - Add options for explicit Async Execution (`--async`) and blocking Stream Control (`--no-stream`).
17. [Tech Debt 3] - [Low Impact/Low Effort] - Write explicit unit tests for `interactive_prompt_with_fragments` in `commands.lua`.
18. [Gap 9] - [Low Impact/Low Effort] - Add support for Extract Last (`--xl`, `--extract-last`).
19. [Gap 11] - [Low Impact/Low Effort] - Add support for System Fragment (`--sf`, `--system-fragment`).
20. [Gap 13] - [Low Impact/Low Effort] - Add support for API Key override (`--key`).
