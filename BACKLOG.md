## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- [Prompting]: Execute a prompt.
- [Ongoing Chat]: Hold an ongoing chat with a model.
- [Model Aliases]: Manage model aliases.
- [Models]: View available models.
- [Templates]: Manage stored prompt templates.
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
- [Gap 2]: Missing support for Usage tracking (`-u`, `--usage`).
- [Gap 3]: Missing support for Extended Tool Options (`--functions`, `--td`, `--ta`, `--cl`).
- [Gap 5]: Missing support for Query Selection (`-q`, `--query`).
- [Gap 6]: Missing support for Stream Control (`--no-stream`) and Async Execution (`--async`).
- [Gap 7]: Missing support for Schema Options (`--schema`, `--schema-multi`) in prompting.
- [Gap 9]: Missing support for Extract Last (`--xl`, `--extract-last`).
- [Tech Debt 1]: Increase overall code coverage. Test coverage is currently well below the 80% target.
- [Tech Debt 2]: Improve async job handling robustness in `job.lua` based on known failure patterns.
- [Tech Debt 3]: Test coverage missing for `M.interactive_prompt_with_fragments` in `commands.lua`.
- [Tech Debt 5]: Refactor duplicated command construction logic across `M.prompt`, `M.prompt_with_current_file`, and `M.prompt_with_selection` in `lua/llm/commands.lua`.
- [Gap 11]: Missing support for System Fragment (`--sf`, `--system-fragment`).
- [Gap 16]: Missing support for embed-models management (`llm embed-models`).
- [Gap 17]: Missing support for managing Collections (`llm collections`).
- [Gap 18]: Missing support for Similarity search (`llm similar`).

## Ranked Backlog
1. [Gap 3] - [Medium Impact/Medium Effort] - Implement Extended Tool Options (`--functions`, `--td`, `--ta`, `--cl`).
2. [Tech Debt 1] - [Medium Impact/Medium Effort] - Increase overall code coverage. Test coverage is currently well below the 80% target.
3. [Tech Debt 2] - [Medium Impact/Medium Effort] - Enhance async job handling logic in `job.lua` for edge cases.
4. [Tech Debt 5] - [Medium Impact/Medium Effort] - Refactor duplicated command construction logic in `commands.lua`.
5. [Gap 2] - [Low Impact/Low Effort] - Expose token Usage tracking (`-u`, `--usage`) visually after execution.
6. [Gap 5] - [Low Impact/Low Effort] - Enable dynamic Query Selection (`-q`, `--query`).
7. [Gap 6] - [Low Impact/Low Effort] - Add options for explicit Async Execution (`--async`) and blocking Stream Control (`--no-stream`).
8. [Tech Debt 3] - [Low Impact/Low Effort] - Write explicit unit tests for `interactive_prompt_with_fragments` in `commands.lua`.
9. [Gap 7] - [Low Impact/Low Effort] - Add support for Schema Options (`--schema`, `--schema-multi`) in prompting.
10. [Gap 9] - [Low Impact/Low Effort] - Add support for Extract Last (`--xl`, `--extract-last`).
11. [Gap 11] - [Low Impact/Low Effort] - Add support for System Fragment (`--sf`, `--system-fragment`).
12. [Gap 16] - [Low Impact/Medium Effort] - Add support for embed-models management (`llm embed-models`).
13. [Gap 17] - [Low Impact/Medium Effort] - Add support for managing Collections (`llm collections`).
14. [Gap 18] - [Low Impact/Medium Effort] - Add support for Similarity search (`llm similar`).