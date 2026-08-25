## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- [Prompt]: Execute a prompt (`llm prompt`).
- [Aliases]: Manage model aliases (`llm aliases`).
- [Chat]: Hold an ongoing chat with a model. (`llm chat`).
- [Embed]: Embed text and store or return the result (`llm embed`).
- [Embed-models]: Manage available embedding models (`llm embed-models`).
- [Embed-multi]: Store embeddings for multiple strings at once (`llm embed-multi`).
- [Models]: Manage available models (`llm models`).
- [Schemas]: Manage stored schemas (`llm schemas`).
- [Similar]: Return top N similar IDs from a collection using cosine similarity (`llm similar`).
- [Templates]: Manage stored prompt templates (`llm templates`).
- [Tools]: Manage tools that can be made available to LLMs (`llm tools`).
- [-s, --system TEXT]: System prompt to use (`-s, --system TEXT`).
- [-m, --model TEXT]: Model to use (`-m, --model TEXT`).
- [-d, --database FILE]: Path to log database (`-d`, `--database`).
- [-q, --query TEXT]: Use first model matching these strings (`-q`, `--query TEXT`).
- [-a, --attachment ATTACHMENT]: Attachment path or URL or - (`-a, --attachment ATTACHMENT`).
- [--at, --attachment-type TEXT]: Attachment with explicit mimetype (`--at`, `--attachment-type`).
- [-T, --tool TEXT]: Name of a tool to make available (`-T, --tool TEXT`).
- [--functions TEXT]: Python code block or file path defining functions (`--functions TEXT`).
- [--td, --tools-debug]: Show full details of tool executions (`--td, --tools-debug`).
- [--ta, --tools-approve]: Manually approve every tool execution (`--ta, --tools-approve`).
- [--cl, --chain-limit INTEGER]: How many chained tool responses to allow (`--cl, --chain-limit INTEGER`).
- [-o, --option TEXT]: key/value options for the model (`-o, --option TEXT`).
- [--options]: Show options for the selected model (`--options`).
- [--schema TEXT]: JSON schema, filepath or ID (`--schema TEXT`).
- [--schema-multi TEXT]: Schema for multiple results (`--schema-multi TEXT`).
- [-f, --fragment TEXT]: Fragment (alias, URL, hash or file path) to add to the prompt (`-f, --fragment TEXT`).
- [--sf, --system-fragment TEXT]: Fragment to add to system prompt (`--sf, --system-fragment TEXT`).
- [-t, --template TEXT]: Template to use (`-t, --template TEXT`).
- [-p, --param TEXT]: Parameters for template (`-p, --param TEXT`).
- [--no-stream]: Do not stream output (`--no-stream`).
- [-n, --no-log]: Don't log to database (`-n, --no-log`).
- [--log]: Log prompt and response to the database (`--log`).
- [-R, --hide-reasoning]: Hide reasoning output (`-R, --hide-reasoning`).
- [-c, --continue]: Continue the most recent conversation (`-c, --continue`).
- [--cid, --conversation TEXT]: Continue the conversation with the given ID (`--cid, --conversation TEXT`).
- [--save TEXT]: Save prompt with this template name (`--save TEXT`).
- [--async]: Run prompt asynchronously (`--async`).
- [-u, --usage]: Show token usage (`-u, --usage`).
- [-x, --extract]: Extract first fenced code block (`-x, --extract`).
- [--xl, --extract-last]: Extract last fenced code block (`--xl, --extract-last`).
- [--json]: Output the response as JSON (`--json`).

## Gaps & Tech Debt
- [Gap 1]: Missing support for System Fragment (`--sf`, `--system-fragment`).
- [Gap 2]: Missing support for Schema Multi (`--schema-multi`).
- [Gap 3]: Missing support for Hide Reasoning (`-R`, `--hide-reasoning`).
- [Gap 4]: Missing support for JSON output (`--json`).
- [Gap 5]: Missing support for Usage tracking (`-u`, `--usage`).
- [Gap 6]: Missing support for Query Selection (`-q`, `--query`).
- [Gap 7]: Missing support for Stream Control (`--no-stream`) and Async Execution (`--async`).
- [Gap 8]: Missing support for Extract Last (`--xl`, `--extract-last`).
- [Tech Debt 1]: Test coverage missing for `scripts/llm.py` error conditions (JSONDecodeError handling).
- [Tech Debt 2]: Write explicit unit tests for `interactive_prompt_with_fragments` in `commands.lua`.
- [Tech Debt 3]: Increase test coverage for templates_manager.lua to >80%.
- [Tech Debt 4]: Increase test coverage for schemas_manager.lua to >80%.
- [Tech Debt 5]: Increase test coverage for models_manager.lua to >80%.
- [Tech Debt 6]: Increase test coverage for unified_manager.lua to >80%.
- [Tech Debt 7]: Increase test coverage for plugins_manager.lua to >80%.
- [Tech Debt 8]: Increase test coverage for tools_manager.lua to >80%.
- [Tech Debt 9]: Increase test coverage for custom_openai.lua to >80%.
- [Tech Debt 10]: Missing mock for `vim.trim` and potentially other global utils when testing under busted.
- [Tech Debt 11]: Missing global utility mocks in `mock_vim.lua` (e.g. vim.split, vim.list_extend, vim.tbl_isempty) for busted test environment.
- [Tech Debt 12]: Manual `os.remove` calls in `schemas_manager.lua` when using `vim.fn.tempname()` are unnecessary and should be removed.

## Ranked Backlog
2. [Gap 2] - [High Impact/Low Effort] - Missing support for Schema Multi (`--schema-multi`).
3. [Gap 5] - [Medium Impact/Low Effort] - Missing support for Usage tracking (`-u`, `--usage`).
4. [Gap 6] - [Medium Impact/Low Effort] - Missing support for Query Selection (`-q`, `--query`).
5. [Gap 7] - [Medium Impact/Low Effort] - Missing support for Stream Control (`--no-stream`) and Async Execution (`--async`).
6. [Gap 8] - [Medium Impact/Low Effort] - Missing support for Extract Last (`--xl`, `--extract-last`).
7. [Tech Debt 2] - [Medium Impact/Low Effort] - Write explicit unit tests for `interactive_prompt_with_fragments` in `commands.lua`.
8. [Tech Debt 10] - [Medium Impact/Low Effort] - Missing mock for `vim.trim` and potentially other global utils when testing under busted.
9. [Tech Debt 11] - [Medium Impact/Low Effort] - Missing global utility mocks in `mock_vim.lua` (e.g. vim.split, vim.list_extend, vim.tbl_isempty) for busted test environment.
10. [Tech Debt 3] - [Medium Impact/Medium Effort] - Increase test coverage for templates_manager.lua to >80%.
11. [Tech Debt 4] - [Medium Impact/Medium Effort] - Increase test coverage for schemas_manager.lua to >80%.
12. [Tech Debt 5] - [Medium Impact/Medium Effort] - Increase test coverage for models_manager.lua to >80%.
13. [Tech Debt 6] - [Medium Impact/Medium Effort] - Increase test coverage for unified_manager.lua to >80%.
14. [Tech Debt 7] - [Medium Impact/Medium Effort] - Increase test coverage for plugins_manager.lua to >80%.
15. [Tech Debt 8] - [Medium Impact/Medium Effort] - Increase test coverage for tools_manager.lua to >80%.
16. [Tech Debt 9] - [Medium Impact/Medium Effort] - Increase test coverage for custom_openai.lua to >80%.
17. [Gap 3] - [Low Impact/Low Effort] - Missing support for Hide Reasoning (`-R`, `--hide-reasoning`).
18. [Gap 4] - [Low Impact/Low Effort] - Missing support for JSON output (`--json`).
19. [Tech Debt 1] - [Low Impact/Low Effort] - Test coverage missing for `scripts/llm.py` error conditions (JSONDecodeError handling).
20. [Tech Debt 12] - [Low Impact/Low Effort] - Manual `os.remove` calls in `schemas_manager.lua` when using `vim.fn.tempname()` are unnecessary and should be removed.
