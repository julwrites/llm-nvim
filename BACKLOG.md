## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- [Prompt]: Execute a prompt (`llm prompt`).
- [Aliases]: Manage model aliases (`llm aliases`).
- [Chat]: Hold an ongoing chat with a model. (`llm chat`).
- [Collections]: View and manage collections of embeddings (`llm collections`).
- [Embed]: Embed text and store or return the result (`llm embed`).
- [Embed-models]: Manage available embedding models (`llm embed-models`).
- [Embed-multi]: Store embeddings for multiple strings at once in the... (`llm embed-multi`).
- [Fragments]: Manage fragments that are stored in the database (`llm fragments`).
- [Models]: Manage available models (`llm models`).
- [Openai]: Commands for working with OpenAI and OpenAI-compatible APIs (`llm openai`).
- [Schemas]: Manage stored schemas (`llm schemas`).
- [Similar]: Return top N similar IDs from a collection using cosine... (`llm similar`).
- [Templates]: Manage stored prompt templates (`llm templates`).
- [Tools]: Manage tools that can be made available to LLMs (`llm tools`).
- [-s, --system TEXT]: System prompt to use (`-s, --system TEXT`).
- [-m, --model TEXT]: Model to use (`-m, --model TEXT`).
- [-q, --query TEXT]: Use first model matching these strings (`-q, --query TEXT`).
- [-a, --attachment ATTACHMENT]: Attachment path or URL or - (`-a, --attachment ATTACHMENT`).
- [-T, --tool TEXT]: Name of a tool to make available to the (`-T, --tool TEXT`).
- [--functions TEXT]: Python code block or file path defining (`--functions TEXT`).
- [--td, --tools-debug]: Show full details of tool executions (`--td, --tools-debug`).
- [--ta, --tools-approve]: Manually approve every tool execution (`--ta, --tools-approve`).
- [--cl, --chain-limit INTEGER]: How many chained tool responses to allow, (`--cl, --chain-limit INTEGER`).
- [-o, --option <TEXT TEXT>...]: key/value options for the model (`-o, --option <TEXT TEXT>...`).
- [--options]: Show options for the selected model (`--options`).
- [--schema TEXT]: JSON schema, filepath or ID (`--schema TEXT`).
- [--schema-multi TEXT]: JSON schema to use for multiple results (`--schema-multi TEXT`).
- [-f, --fragment TEXT]: Fragment (alias, URL, hash or file path) to (`-f, --fragment TEXT`).
- [--sf, --system-fragment TEXT]: Fragment to add to system prompt (`--sf, --system-fragment TEXT`).
- [-t, --template TEXT]: Template to use (`-t, --template TEXT`).
- [-p, --param <TEXT TEXT>...]: Parameters for template (`-p, --param <TEXT TEXT>...`).
- [--no-stream]: Do not stream output (`--no-stream`).
- [-R, --hide-reasoning]: Hide reasoning output (`-R, --hide-reasoning`).
- [-c, --continue]: Continue the most recent conversation. (`-c, --continue`).
- [--cid, --conversation TEXT]: Continue the conversation with the given ID. (`--cid, --conversation TEXT`).
- [--key TEXT]: API key to use (`--key TEXT`).
- [--save TEXT]: Save prompt with this template name (`--save TEXT`).
- [--async]: Run prompt asynchronously (`--async`).
- [-u, --usage]: Show token usage (`-u, --usage`).
- [-x, --extract]: Extract first fenced code block (`-x, --extract`).
- [--xl, --extract-last]: Extract last fenced code block (`--xl, --extract-last`).
- [--json]: Output the response as JSON, same format as (`--json`).

## Gaps & Tech Debt
- [Gap 1]: Missing support for Usage tracking (`-u`, `--usage`).
- [Gap 2]: Missing support for Query Selection (`-q`, `--query`).
- [Gap 3]: Missing support for Stream Control (`--no-stream`) and Async Execution (`--async`).
- [Gap 4]: Missing support for Extract Last (`--xl`, `--extract-last`).
- [Gap 5]: Missing support for System Fragment (`--sf`, `--system-fragment`).
- [Gap 6]: Missing support for embed-models management (`llm embed-models`).
- [Gap 9]: Missing support for explicit Attachment Type (`--at`, `--attachment-type`).
- [Tech Debt 2]: Improve async job handling robustness in `job.lua` based on known failure patterns.
- [Tech Debt 3]: Test coverage missing for `M.interactive_prompt_with_fragments` in `commands.lua`.
- [Tech Debt 5]: Increase test coverage for templates_manager.lua to >80%.
- [Tech Debt 6]: Increase test coverage for schemas_manager.lua to >80%.
- [Tech Debt 7]: Increase test coverage for models_manager.lua to >80%.
- [Tech Debt 8]: Increase test coverage for unified_manager.lua to >80%.
- [Tech Debt 9]: Increase test coverage for plugins_manager.lua to >80%.
- [Tech Debt 10]: Increase test coverage for tools_manager.lua to >80%.

## Ranked Backlog
1. [Tech Debt 2] - [High Impact/Medium Effort] - Enhance async job handling logic in `job.lua` for edge cases.
2. [Tech Debt 3] - [Medium Impact/Low Effort] - Write explicit unit tests for `interactive_prompt_with_fragments` in `commands.lua`.
3. [Gap 1] - [Medium Impact/Low Effort] - Expose token Usage tracking (`-u`, `--usage`) visually after execution.
4. [Gap 2] - [Medium Impact/Low Effort] - Enable dynamic Query Selection (`-q`, `--query`).
5. [Gap 3] - [Medium Impact/Low Effort] - Add options for explicit Async Execution (`--async`) and blocking Stream Control (`--no-stream`).
6. [Gap 4] - [Medium Impact/Low Effort] - Add support for Extract Last (`--xl`, `--extract-last`).
7. [Gap 5] - [Medium Impact/Low Effort] - Add support for System Fragment (`--sf`, `--system-fragment`).
8. [Gap 9] - [Medium Impact/Low Effort] - Add support for explicit Attachment Type (`--at`, `--attachment-type`).
9. [Tech Debt 5] - [Medium Impact/Medium Effort] - Increase test coverage for templates_manager.lua to >80%.
10. [Tech Debt 6] - [Medium Impact/Medium Effort] - Increase test coverage for schemas_manager.lua to >80%.
11. [Tech Debt 7] - [Medium Impact/Medium Effort] - Increase test coverage for models_manager.lua to >80%.
12. [Tech Debt 8] - [Medium Impact/Medium Effort] - Increase test coverage for unified_manager.lua to >80%.
13. [Tech Debt 9] - [Medium Impact/Medium Effort] - Increase test coverage for plugins_manager.lua to >80%.
14. [Tech Debt 10] - [Medium Impact/Medium Effort] - Increase test coverage for tools_manager.lua to >80%.
15. [Gap 6] - [Low Impact/Medium Effort] - Add support for embed-models management (`llm embed-models`).
