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
- [Logging]: Options to log prompts and responses.
- [Continue Conversation]: Continue the most recent or specific conversation.
- [Query Selection]: Use first model matching strings.
- [Save as Template]: Save prompt with a template name.
- [Async Execution]: Run prompt asynchronously.
- [Stream Control]: Do not stream output.
- [Schemas]: Manage stored schemas and use them in prompts.

## Gaps & Tech Debt
- [Gap 1]: Missing support for Multi-modal attachments (`-a`, `--attachment`, `--at`, `--attachment-type`).
- [Gap 2]: Missing support for Usage tracking (`-u`, `--usage`).
- [Gap 3]: Missing support for Extended Tool Options (`--functions`, `--td`, `--ta`, `--cl`).
- [Gap 4]: Missing support for Continue Conversation (`-c`, `--continue`, `--cid`, `--conversation`).
- [Gap 5]: Missing support for Query Selection (`-q`, `--query`).
- [Gap 6]: Missing support for Stream Control (`--no-stream`) and Async Execution (`--async`).
- [Gap 7]: Missing support for Schema Options (`--schema`, `--schema-multi`) in prompting.
- [Gap 8]: Missing support for Save as Template (`--save`).
- [Gap 9]: Missing support for Extract Last (`--xl`, `--extract-last`).
- [Tech Debt 1]: Increase overall code coverage. Test coverage is currently well below the 80% target.
- [Tech Debt 2]: Improve async job handling robustness in `job.lua` based on known failure patterns.
- [Tech Debt 3]: Test coverage missing for `M.interactive_prompt_with_fragments` in `commands.lua`.
- [Gap 10]: Missing support for Logging options (`-d`, `--database`, `-n`, `--no-log`, `--log`).
- [Tech Debt 4]: Remove invalid/dead code for `--system-fragment` (`-sf`) in `lua/llm/commands.lua` as it is not supported by upstream `llm` CLI.
- [Tech Debt 5]: Refactor duplicated command construction logic across `M.prompt`, `M.prompt_with_current_file`, and `M.prompt_with_selection` in `lua/llm/commands.lua`.

## Ranked Backlog
4. [Tech Debt 4] - [High Impact/Low Effort] - Remove invalid/dead code for `--system-fragment` (`-sf`) in `lua/llm/commands.lua`.
5. [Gap 4] - [Medium Impact/Low Effort] - Add functionality to Continue Conversations (`-c`, `--continue`, `--cid`, `--conversation`) easily from previous prompt sessions.
6. [Gap 7] - [Medium Impact/Low Effort] - Add support for Schema Options (`--schema`, `--schema-multi`) in prompts.
7. [Gap 8] - [Medium Impact/Low Effort] - Add support to Save as Template (`--save`).
8. [Tech Debt 5] - [Medium Impact/Medium Effort] - Refactor duplicated command construction logic in `lua/llm/commands.lua`.
9. [Gap 1] - [Medium Impact/Medium Effort] - Implement Multi-modal attachment support for models that accept images or other data types (`-a`, `--attachment`, `--at`, `--attachment-type`).
10. [Gap 3] - [Medium Impact/Medium Effort] - Implement Extended Tool Options (`--functions`, `--td`, `--ta`, `--cl`).
11. [Tech Debt 2] - [Medium Impact/Medium Effort] - Enhance async job handling logic in `job.lua` for edge cases.
12. [Gap 2] - [Low Impact/Low Effort] - Expose token Usage tracking (`-u`, `--usage`) visually after execution.
13. [Gap 5] - [Low Impact/Low Effort] - Enable dynamic Query Selection (`-q`, `--query`).
14. [Gap 6] - [Low Impact/Low Effort] - Add options for explicit Async Execution (`--async`) and blocking Stream Control (`--no-stream`).
15. [Tech Debt 3] - [Low Impact/Low Effort] - Write explicit unit tests for `interactive_prompt_with_fragments` in `commands.lua`.
16. [Gap 9] - [Low Impact/Low Effort] - Add support for Extract Last (`--xl`, `--extract-last`).
17. [Gap 10] - [Low Impact/Low Effort] - Add support for Logging options (`-d`, `--database`, `-n`, `--no-log`, `--log`).
