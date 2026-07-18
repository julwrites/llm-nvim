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
- [Logs]: Explore logged prompts and responses.
- [Database Options]: Options for logging to database.

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
- [Gap 13]: Missing support for API Key override (`--key`).
- [Gap 14]: Missing support for Logs commands to explore logged prompts and responses.
- [Gap 15]: Missing support for Database Options (`--log`, `--no-log`, `-d`, `--database`).

## Ranked Backlog
1. [Gap 7] - [Medium Impact/Low Effort] - Add support for Schema Options (`--schema`, `--schema-multi`) in prompts.
2. [Gap 8] - [Medium Impact/Low Effort] - Add support to Save as Template (`--save`).
3. [Tech Debt 5] - [Medium Impact/Medium Effort] - Refactor duplicated command construction logic in `lua/llm/commands.lua`.
4. [Gap 1] - [Medium Impact/Medium Effort] - Implement Multi-modal attachment support for models that accept images or other data types (`-a`, `--attachment`, `--at`, `--attachment-type`).
5. [Gap 3] - [Medium Impact/Medium Effort] - Implement Extended Tool Options (`--functions`, `--td`, `--ta`, `--cl`).
6. [Tech Debt 1] - [Medium Impact/Medium Effort] - Increase overall code coverage. Test coverage is currently well below the 80% target.
7. [Tech Debt 2] - [Medium Impact/Medium Effort] - Enhance async job handling logic in `job.lua` for edge cases.
8. [Gap 2] - [Low Impact/Low Effort] - Expose token Usage tracking (`-u`, `--usage`) visually after execution.
9. [Gap 5] - [Low Impact/Low Effort] - Enable dynamic Query Selection (`-q`, `--query`).
10. [Gap 6] - [Low Impact/Low Effort] - Add options for explicit Async Execution (`--async`) and blocking Stream Control (`--no-stream`).
11. [Tech Debt 3] - [Low Impact/Low Effort] - Write explicit unit tests for `interactive_prompt_with_fragments` in `commands.lua`.
12. [Gap 9] - [Low Impact/Low Effort] - Add support for Extract Last (`--xl`, `--extract-last`).
13. [Gap 11] - [Low Impact/Low Effort] - Add support for System Fragment (`--sf`, `--system-fragment`).
14. [Gap 13] - [Low Impact/Low Effort] - Add support for API Key override (`--key`).
15. [Gap 14] - [Low Impact/Low Effort] - Add support for Logs commands to explore logged prompts and responses.
16. [Gap 15] - [Low Impact/Low Effort] - Add support for Database Options (`--log`, `--no-log`, `-d`, `--database`).