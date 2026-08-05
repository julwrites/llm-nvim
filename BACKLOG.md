## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- [Prompting]: Execute a prompt (`llm prompt`).
- [Ongoing Chat]: Hold an ongoing chat with a model (`llm chat`).
- [Model Aliases]: Manage model aliases (`llm aliases`).
- [Models]: View available models (`llm models`).
- [Templates]: Manage stored prompt templates (`llm templates`).
- [Tools / Function Calling]: Make tools available to the model (`llm tools`, `-T`, `--functions`).
- [Extractions]: Extract content of fenced code blocks (`-x`, `--xl`).
- [Model Options]: Key/value options for the model (`-o`).
- [Template Parameters]: Parameters for template (`-p`).
- [Usage tracking]: Show token usage (`-u`).
- [Continue Conversation]: Continue the most recent or specific conversation (`-c`, `--cid`).
- [Query Selection]: Use first model matching strings (`-q`).
- [Save as Template]: Save prompt with a template name (`--save`).
- [Async Execution]: Run prompt asynchronously (`--async`).
- [Stream Control]: Do not stream output (`--no-stream`).
- [Schemas]: Manage stored schemas and use them in prompts (`llm schemas`, `--schema`, `--schema-multi`).
- [System Fragment]: Add fragment to system prompt (`--sf`).
- [Fragments]: Manage fragments and add to prompt (`llm fragments`, `-f`).
- [Embeddings]: Embed text and store or return the result (`llm embed`).
- [Embed Models]: Manage available embedding models (`llm embed-models`).
- [Embed Multi]: Store embeddings for multiple strings at once (`llm embed-multi`).
- [Collections]: View and manage collections of embeddings (`llm collections`).
- [Similar]: Return top N similar IDs from a collection using cosine similarity (`llm similar`).
- [Attachments]: Multi-modal models can be called with attachments (`-a`, `--at`).

## Gaps & Tech Debt
- [Tech Debt 2]: Improve async job handling robustness in `job.lua` based on known failure patterns.
- [Tech Debt 3]: Test coverage missing for `M.interactive_prompt_with_fragments` in `commands.lua`.
- [Tech Debt 5]: Increase test coverage for templates_manager.lua to >80%.
- [Tech Debt 6]: Increase test coverage for schemas_manager.lua to >80%.
- [Tech Debt 7]: Increase test coverage for models_manager.lua to >80%.
- [Tech Debt 8]: Increase test coverage for unified_manager.lua to >80%.
- [Tech Debt 9]: Increase test coverage for plugins_manager.lua to >80%.
- [Tech Debt 10]: Increase test coverage for tools_manager.lua to >80%.
- [Gap 1]: Missing support for Usage tracking (`-u`, `--usage`).
- [Gap 2]: Missing support for Query Selection (`-q`, `--query`).
- [Gap 3]: Missing support for Stream Control (`--no-stream`) and Async Execution (`--async`).
- [Gap 4]: Missing support for Extract Last (`--xl`, `--extract-last`).
- [Gap 5]: Missing support for System Fragment (`--sf`, `--system-fragment`).
- [Gap 6]: Missing support for embed-models management (`llm embed-models`).
- [Gap 9]: Missing support for explicit Attachment Type (`--at`, `--attachment-type`).
- [Gap 11]: Missing support for Model Aliases (`llm aliases`).
- [Gap 12]: Missing SSE streaming support in `scripts/llm.py` (responses are parsed as single JSON objects).
- [Bug 6]: Unnecessary manual `os.remove()` for `vim.fn.tempname()` files in `lua/llm/commands.lua` and `lua/llm/managers/schemas_manager.lua`.

## Ranked Backlog
1. [Gap 12] - [Medium Impact/Medium Effort] - Implement SSE streaming support in `scripts/llm.py` instead of waiting for full response.
2. [Tech Debt 2] - [Medium Impact/Medium Effort] - Enhance async job handling logic in `job.lua` for edge cases.
3. [Tech Debt 6] - [Medium Impact/Medium Effort] - Increase test coverage for schemas_manager.lua to >80%.
4. [Tech Debt 7] - [Medium Impact/Medium Effort] - Increase test coverage for models_manager.lua to >80%.
5. [Tech Debt 8] - [Medium Impact/Medium Effort] - Increase test coverage for unified_manager.lua to >80%.
6. [Tech Debt 9] - [Medium Impact/Medium Effort] - Increase test coverage for plugins_manager.lua to >80%.
7. [Tech Debt 10] - [Medium Impact/Medium Effort] - Increase test coverage for tools_manager.lua to >80%.
8. [Tech Debt 5] - [Medium Impact/Medium Effort] - Increase test coverage for templates_manager.lua to >80%.
9. [Gap 1] - [Low Impact/Low Effort] - Expose token Usage tracking (`-u`, `--usage`) visually after execution.
10. [Gap 2] - [Low Impact/Low Effort] - Enable dynamic Query Selection (`-q`, `--query`).
11. [Gap 3] - [Low Impact/Low Effort] - Add options for explicit Async Execution (`--async`) and blocking Stream Control (`--no-stream`).
12. [Tech Debt 3] - [Low Impact/Low Effort] - Write explicit unit tests for `interactive_prompt_with_fragments` in `commands.lua`.
13. [Gap 4] - [Low Impact/Low Effort] - Add support for Extract Last (`--xl`, `--extract-last`).
14. [Gap 5] - [Low Impact/Low Effort] - Add support for System Fragment (`--sf`, `--system-fragment`).
15. [Gap 9] - [Low Impact/Low Effort] - Add support for explicit Attachment Type (`--at`, `--attachment-type`).
16. [Bug 6] - [Low Impact/Low Effort] - Remove unnecessary manual `os.remove()` calls for files generated by `vim.fn.tempname()`.
17. [Gap 11] - [Low Impact/Low Effort] - Add support for Model Aliases (`llm aliases`).
18. [Gap 6] - [Low Impact/Medium Effort] - Add support for embed-models management (`llm embed-models`).
