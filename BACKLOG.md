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
- [API Keys]: Manage stored API keys for different models (`llm keys`).

## Gaps & Tech Debt
- [Bug 1]: Missing carriage return (`\r`) handling when splitting buffer on newlines in `job.lua`.
- [Gap 2]: Missing support for Usage tracking (`-u`, `--usage`).
- [Gap 5]: Missing support for Query Selection (`-q`, `--query`).
- [Gap 6]: Missing support for Stream Control (`--no-stream`) and Async Execution (`--async`).
- [Gap 9]: Missing support for Extract Last (`--xl`, `--extract-last`).
- [Gap 11]: Missing support for System Fragment (`--sf`, `--system-fragment`).
- [Gap 16]: Missing support for embed-models management (`llm embed-models`).
- [Gap 17]: Missing support for managing Collections (`llm collections`).
- [Gap 18]: Missing support for Similarity search (`llm similar`).
- [Gap 19]: Missing support for explicit Attachment Type (`--at`, `--attachment-type`).
- [Gap 20]: Missing support for embed-multi (`llm embed-multi`).
- [Gap 23]: Missing support for Model Aliases (`llm aliases`).
- [Bug 2]: Missing URLError exception handling in scripts/llm.py.
- [Tech Debt 1.1]: Increase test coverage for templates_manager.lua to >80%.
- [Tech Debt 1.2]: Increase test coverage for schemas_manager.lua to >80%.
- [Tech Debt 1.3]: Increase test coverage for models_manager.lua to >80%.
- [Tech Debt 1.4]: Increase test coverage for unified_manager.lua to >80%.
- [Tech Debt 1.5]: Increase test coverage for plugins_manager.lua to >80%.
- [Tech Debt 2]: Improve async job handling robustness in `job.lua` based on known failure patterns.
- [Tech Debt 3]: Test coverage missing for `M.interactive_prompt_with_fragments` in `commands.lua`.
- [Tech Debt 4]: Replace `os.tmpname()` with secure temporary file creation and reliable cleanup in `commands.lua`.
- [Bug 3]: Unhandled empty string return from `write_context_to_temp_file` in `M.prompt_with_selection` leads to invalid command arguments.
- [Gap 24]: Missing support for API Key management (`llm keys`, `--key`).
- [Bug 4]: Missing `os.getenv` handling for API keys in `scripts/llm.py` could fail silently if `urllib` isn't properly mocked.
- [Bug 5]: Neovim's `vim.fn.jobstart` behaves asynchronously, but `tests/spec/api_spec.lua` misses validation on output stream timing and truncation issues during `job.lua` data accumulation.

## Ranked Backlog
1. [Bug 5] - [High Impact/Low Effort] - Neovim's `vim.fn.jobstart` behaves asynchronously, but `tests/spec/api_spec.lua` misses validation on output stream timing and truncation issues during `job.lua` data accumulation.
2. [Tech Debt 1.2] - [Medium Impact/Medium Effort] - Increase test coverage for schemas_manager.lua to >80%.
3. [Tech Debt 1.3] - [Medium Impact/Medium Effort] - Increase test coverage for models_manager.lua to >80%.
4. [Tech Debt 1.4] - [Medium Impact/Medium Effort] - Increase test coverage for unified_manager.lua to >80%.
5. [Tech Debt 1.5] - [Medium Impact/Medium Effort] - Increase test coverage for plugins_manager.lua to >80%.
6. [Bug 1] - [Medium Impact/Low Effort] - Handle carriage returns (`\r\n`) when splitting buffers in `job.lua`.
7. [Bug 2] - [Medium Impact/Low Effort] - Missing URLError exception handling in scripts/llm.py.
8. [Bug 4] - [Medium Impact/Low Effort] - Improve API key retrieval robustness in `scripts/llm.py`.
9. [Tech Debt 2] - [Medium Impact/Medium Effort] - Enhance async job handling logic in `job.lua` for edge cases.
10. [Bug 3] - [Medium Impact/Low Effort] - Handle empty string return from `write_context_to_temp_file` in `commands.lua`.
11. [Tech Debt 4] - [Low Impact/Medium Effort] - Replace `os.tmpname()` with secure temporary file creation and reliable cleanup in `commands.lua`.
12. [Gap 24] - [Low Impact/Low Effort] - Add support for explicit API Keys (`--key`) and keys management (`llm keys`).
13. [Gap 23] - [Low Impact/Low Effort] - Add support for Model Aliases (`llm aliases`).
14. [Gap 2] - [Low Impact/Low Effort] - Expose token Usage tracking (`-u`, `--usage`) visually after execution.
15. [Gap 5] - [Low Impact/Low Effort] - Enable dynamic Query Selection (`-q`, `--query`).
16. [Gap 6] - [Low Impact/Low Effort] - Add options for explicit Async Execution (`--async`) and blocking Stream Control (`--no-stream`).
17. [Tech Debt 3] - [Low Impact/Low Effort] - Write explicit unit tests for `interactive_prompt_with_fragments` in `commands.lua`.
18. [Gap 9] - [Low Impact/Low Effort] - Add support for Extract Last (`--xl`, `--extract-last`).
19. [Gap 11] - [Low Impact/Low Effort] - Add support for System Fragment (`--sf`, `--system-fragment`).
20. [Gap 16] - [Low Impact/Medium Effort] - Add support for embed-models management (`llm embed-models`).
21. [Gap 17] - [Low Impact/Medium Effort] - Add support for managing Collections (`llm collections`).
22. [Gap 18] - [Low Impact/Medium Effort] - Add support for Similarity search (`llm similar`).
23. [Gap 19] - [Low Impact/Low Effort] - Add support for explicit Attachment Type (`--at`, `--attachment-type`).
24. [Gap 20] - [Low Impact/Medium Effort] - Add support for embed-multi (`llm embed-multi`).
