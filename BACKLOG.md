## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- Prompting (`llm prompt`): Execute a prompt.
- Ongoing Chat (`llm chat`): Hold an ongoing chat with a model.
- Model Aliases (`llm aliases`): Manage model aliases.
- Models (`llm models`): View available models.
- Templates (`llm templates`): Manage stored prompt templates.
- Multi-modal attachments (`-a` / `--attachment`, `--at` / `--attachment-type`): Call models with attachments like images.
- Tools / Function Calling Options (`-T`, `--tool`, `--functions`, `--td`, `--ta`, `--cl`): Make tools available to the model.
- Extractions (`-x` / `--extract`, `--xl` / `--extract-last`): Extract content of fenced code blocks.
- Model Options (`-o` / `--option`): key/value options for the model.
- Template Parameters (`-p` / `--param`): Parameters for template.
- Usage tracking (`-u` / `--usage`): Show token usage.
- System Fragments (`--sf` / `--system-fragment`): Fragment to add to system prompt.
- Continue Prompt Conversation (`-c`, `--continue`, `--cid`, `--conversation`): Continue the most recent or specific conversation.
- Query Selection (`-q` / `--query`): Use first model matching strings.
- Save as Template (`--save`): Save prompt with a template name.
- Async Execution (`--async`): Run prompt asynchronously.
- Stream Control (`--no-stream`): Do not stream output.
- Schemas (`llm schemas`, `--schema`, `--schema-multi`): Manage stored schemas and use them in prompts.
- Database Logging (`-d` / `--database`, `-n` / `--no-log`, `--log`): Log prompt and response to the database.

## Gaps & Tech Debt
- [Gap 1]: Missing support for Multi-modal attachments (`-a`, `--attachment`, `--at`, `--attachment-type`).
- [Gap 3]: Missing support for Template Parameters (`-p`, `--param`).
- [Gap 4]: Missing support for Usage tracking (`-u`, `--usage`).
- [Gap 5]: Missing support for Extended Tool Options (`--functions`, `--td`, `--ta`, `--cl`).
- [Gap 6]: Missing support for Continue Conversation (`-c`, `--continue`, `--cid`, `--conversation`).
- [Gap 7]: Missing support for Query Selection (`-q`, `--query`).
- [Gap 8]: Missing support for Stream Control (`--no-stream`) and Async Execution (`--async`).
- [Gap 9]: Missing support for Schema Options (`--schema`, `--schema-multi`) in prompting.
- [Gap 10]: Missing support for Database Logging (`-d`, `--database`, `-n`, `--no-log`, `--log`).
- [Gap 11]: Missing support for Save as Template (`--save`).
- [Tech Debt 1]: Increase overall code coverage. Test coverage is currently well below the 80% target.
- [Tech Debt 2]: Improve async job handling robustness in `job.lua` based on known failure patterns.
- [Tech Debt 3]: Test coverage missing for `M.interactive_prompt_with_fragments` in `commands.lua`.
- [Gap 12]: Missing support for specifying an API key per request (`--key`).
- [Gap 13]: Missing support for Extract Last (`--xl`, `--extract-last`).

## Ranked Backlog
1. [Gap 3] - [Medium Impact/Low Effort] - Support dynamic Template Parameters (`-p`, `--param`).
3. [Gap 6] - [Medium Impact/Low Effort] - Add functionality to Continue Conversations (`-c`, `--continue`, `--cid`, `--conversation`) easily from previous prompt sessions.
4. [Gap 9] - [Medium Impact/Low Effort] - Add support for Schema Options (`--schema`, `--schema-multi`) in prompts.
5. [Gap 11] - [Medium Impact/Low Effort] - Add support to Save as Template (`--save`).
6. [Gap 1] - [Medium Impact/Medium Effort] - Implement Multi-modal attachment support for models that accept images or other data types (`-a`, `--attachment`, `--at`, `--attachment-type`).
7. [Gap 5] - [Medium Impact/Medium Effort] - Implement Extended Tool Options (`--functions`, `--td`, `--ta`, `--cl`).
8. [Tech Debt 2] - [Medium Impact/Medium Effort] - Enhance async job handling logic in `job.lua` for edge cases.
9. [Tech Debt 1 - Subtask 1] - [High Impact/High Effort] - Increase test coverage for models_manager, templates_manager, and schemas_manager.
10. [Tech Debt 1 - Subtask 2] - [High Impact/High Effort] - Increase test coverage for keys_manager, fragments_manager.
11. [Tech Debt 1 - Subtask 3] - [High Impact/High Effort] - Increase test coverage for custom_openai, plugins_manager.
12. [Gap 4] - [Low Impact/Low Effort] - Expose token Usage tracking (`-u`, `--usage`) visually after execution.
13. [Gap 7] - [Low Impact/Low Effort] - Enable dynamic Query Selection (`-q`, `--query`).
14. [Gap 8] - [Low Impact/Low Effort] - Add options for explicit Async Execution (`--async`) and blocking Stream Control (`--no-stream`).
15. [Gap 10] - [Low Impact/Low Effort] - Add support for Database Logging options (`-d`, `--database`, `-n`, `--no-log`, `--log`).
16. [Tech Debt 3] - [Low Impact/Low Effort] - Write explicit unit tests for `interactive_prompt_with_fragments` in `commands.lua`.
17. [Gap 12] - [Low Impact/Low Effort] - Support specifying an API key per request (`--key`).
18. [Gap 13] - [Low Impact/Low Effort] - Add support for Extract Last (`--xl`, `--extract-last`).
