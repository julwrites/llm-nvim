## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- Prompting (`llm prompt`): Execute a prompt.
- Ongoing Chat (`llm chat`): Hold an ongoing chat with a model.
- Model Aliases (`llm aliases`): Manage model aliases.
- Models (`llm models`): View available models.
- Templates (`llm templates`): Manage stored prompt templates.
- Multi-modal attachments (`-a` / `--attachment`): Call models with attachments like images.
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
- Schemas (`llm schemas`): Manage stored schemas.

## Gaps & Tech Debt
- [Gap 1]: Missing support for Tools / Function Calling (`-T`, `--tool`, `--functions`, `--td`, `--ta`, `--cl`).
- [Gap 2]: Missing support for Multi-modal attachments (`-a`, `--attachment`).
- [Gap 3]: Missing support for Extractions (`-x`, `--extract`, `--xl`, `--extract-last`) in general prompt generation.
- [Gap 4]: Missing support for Model Options (`-o`, `--option`).
- [Gap 5]: Missing support for Template Parameters (`-p`, `--param`).
- [Gap 6]: Missing support for Usage tracking (`-u`, `--usage`).
- [Gap 7]: Missing support for System Fragments (`--sf`, `--system-fragment`).
- [Gap 8]: Missing support for Continue Conversation (`-c`, `--continue`, `--cid`, `--conversation`).
- [Gap 9]: Missing support for Query Selection (`-q`, `--query`).
- [Gap 10]: Missing support for Stream Control (`--no-stream`) and Async Execution (`--async`).
- [Gap 11]: Missing support for Schema Options (`--schema`, `--schema-multi`) in prompting.
- [Tech Debt 1]: Increase overall code coverage. Test coverage is currently at ~46%, well below the 80% target. Managers like models_manager, templates_manager, schemas_manager, keys_manager, fragments_manager, custom_openai, plugins_manager all have less than 50% coverage.
- [Tech Debt 2]: Improve async job handling robustness in `job.lua` based on known failure patterns.
- [Tech Debt 3]: Test coverage missing for `M.interactive_prompt_with_fragments` in `fragments_manager.lua`.

## Ranked Backlog
1. [Gap 1 - Subtask 1] - [High Impact/Medium Effort] - Implement UI and Manager for Tools (tools_manager.lua, tools_view.lua, unified_manager.lua).
1. [Gap 1 - Subtask 2] - [High Impact/Medium Effort] - Integrate tool support into command execution and prompting in `commands.lua` and `plugin/llm.lua`.
1. [Gap 1 - Subtask 3] - [High Impact/Medium Effort] - Add tests for Tools UI and Tools command execution.
2. [Tech Debt 1 - Subtask 1] - [High Impact/High Effort] - Increase test coverage for models_manager, templates_manager, and schemas_manager.
2. [Tech Debt 1 - Subtask 2] - [High Impact/High Effort] - Increase test coverage for keys_manager, fragments_manager.
2. [Tech Debt 1 - Subtask 3] - [High Impact/High Effort] - Increase test coverage for custom_openai, plugins_manager.
3. [Gap 3] - [High Impact/Low Effort] - Implement Extractions (`-x`, `--xl`) support for targeted code block extraction from model responses.
4. [Tech Debt 2] - [Medium Impact/Medium Effort] - Enhance async job handling logic in `job.lua` for edge cases.
5. [Gap 2] - [Medium Impact/Medium Effort] - Implement Multi-modal attachment support for models that accept images or other data types (`-a`, `--attachment`).
6. [Gap 4] - [Medium Impact/Low Effort] - Expose Model Options (`-o`) configuration per model or prompt.
7. [Gap 5] - [Medium Impact/Low Effort] - Support dynamic Template Parameters (`-p`).
8. [Gap 8] - [Medium Impact/Low Effort] - Add functionality to Continue Conversations (`-c`) easily from previous prompt sessions.
9. [Tech Debt 3] - [Low Impact/Low Effort] - Write explicit unit tests for `interactive_prompt_with_fragments`.
10. [Gap 6] - [Low Impact/Low Effort] - Expose token Usage tracking (`-u`) visually after execution.
11. [Gap 7] - [Low Impact/Low Effort] - Allow composing System Fragments (`--sf`).
12. [Gap 9] - [Low Impact/Low Effort] - Enable dynamic Query Selection (`-q`).
13. [Gap 10] - [Low Impact/Low Effort] - Add options for explicit Async Execution (`--async`) and blocking Stream Control (`--no-stream`).
14. [Gap 11] - [Medium Impact/Low Effort] - Add support for Schema Options (`--schema`, `--schema-multi`) in prompts.