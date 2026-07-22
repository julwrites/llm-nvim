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
- [Logs]: Tools for exploring logged prompts and responses (`llm logs`, `-d`, `-n`, `--log`).
- [Keys]: Manage stored API keys for different models (`llm keys`).

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
- [Gap 19]: Missing support for explicit Attachment Type (`--at`, `--attachment-type`).
- [Gap 20]: Missing support for embed-multi (`llm embed-multi`).
- [Gap 21]: Missing support for Database path (`-d`, `--database`).
- [Gap 22]: Missing support for No Log (`-n`, `--no-log`) and Log (`--log`).

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
15. [Gap 19] - [Low Impact/Low Effort] - Add support for explicit Attachment Type (`--at`, `--attachment-type`).
16. [Gap 20] - [Low Impact/Medium Effort] - Add support for embed-multi (`llm embed-multi`).
17. [Gap 21] - [Low Impact/Low Effort] - Add support for Database path (`-d`, `--database`).
18. [Gap 22] - [Low Impact/Low Effort] - Add support for No Log (`-n`, `--no-log`) and Log (`--log`).
