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
- [-q, --query TEXT]: Use first model matching these strings (`-q, --query TEXT`).
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
- [--schema-multi TEXT]: JSON schema to use for multiple results (`--schema-multi TEXT`).
- [-t, --template TEXT]: Template to use (`-t, --template TEXT`).
- [-p, --param TEXT]: Parameters for template (`-p, --param TEXT`).
- [--no-stream]: Do not stream output (`--no-stream`).
- [-R, --hide-reasoning]: Hide reasoning output (`-R, --hide-reasoning`).
- [-c, --continue]: Continue the most recent conversation (`-c, --continue`).
- [--cid, --conversation TEXT]: Continue the conversation with the given ID (`--cid, --conversation TEXT`).
- [--key TEXT]: API key to use (`--key TEXT`).
- [--save TEXT]: Save prompt with this template name (`--save TEXT`).
- [--async]: Run prompt asynchronously (`--async`).
- [-u, --usage]: Show token usage (`-u, --usage`).
- [-x, --extract]: Extract first fenced code block (`-x, --extract`).
- [--xl, --extract-last]: Extract last fenced code block (`--xl, --extract-last`).
- [--json]: Output the response as JSON (`--json`).
- [-d, --database FILE]: Path to log database (`-d, --database FILE`).
- [-n, --no-log]: Don't log to database (`-n, --no-log`).
- [--log]: Log prompt and response to the database (`--log`).

## Gaps & Tech Debt
- [Gap 1]: Missing support for explicit Attachment Type (`--at`, `--attachment-type`).
- [Gap 2]: Missing support for Hide Reasoning (`-R`, `--hide-reasoning`).
- [Gap 3]: Missing support for JSON output (`--json`).
- [Gap 4]: Missing support for Usage tracking (`-u`, `--usage`).
- [Gap 5]: Missing support for Query Selection (`-q`, `--query`).
- [Gap 6]: Missing support for Stream Control (`--no-stream`) and Async Execution (`--async`).
- [Gap 7]: Missing support for Extract Last (`--xl`, `--extract-last`).
- [Gap 8]: Missing support for explicit Schema Multi (`--schema-multi`).
- [Gap 9]: Missing support for explicitly setting the API key for a prompt (`--key`).
- [Gap 10]: Missing support for Database Path (`-d`, `--database FILE`).
- [Gap 11]: Missing support for No Log (`-n`, `--no-log`).
- [Gap 12]: Missing support for explicit Log (`--log`).
- [Tech Debt 1]: Refactor scripts/llm.py to cleanly handle urllib exceptions when JSON is malformed.
- [Tech Debt 2]: Test coverage missing for `scripts/llm.py` error conditions (JSONDecodeError handling).
- [Tech Debt 3]: Write explicit unit tests for `interactive_prompt_with_fragments` in `commands.lua`.
- [Tech Debt 4]: Increase test coverage for templates_manager.lua to >80%.
- [Tech Debt 5]: Increase test coverage for schemas_manager.lua to >80%.
- [Tech Debt 6]: Increase test coverage for models_manager.lua to >80%.
- [Tech Debt 7]: Increase test coverage for unified_manager.lua to >80%.
- [Tech Debt 8]: Increase test coverage for plugins_manager.lua to >80%.
- [Tech Debt 9]: Increase test coverage for tools_manager.lua to >80%.
- [Tech Debt 10]: Increase test coverage for custom_openai.lua to >80%.
- [Tech Debt 11]: Missing mock for `vim.trim` and potentially other global utils when testing under busted.
- [Tech Debt 12]: Missing global utility mocks in `mock_vim.lua` (e.g. vim.split, vim.list_extend, vim.tbl_isempty) for busted test environment.
- [Tech Debt 13]: Manual `os.remove` calls in `schemas_manager.lua` when using `vim.fn.tempname()` are unnecessary and should be removed.
- [Tech Debt 14]: Global API mocks in `api_spec.lua` and others leak global state (e.g. _G.vim.fn.jobstart).

## Ranked Backlog
1. [Tech Debt 14] - [High Impact/Medium Effort] - Global API mocks in `api_spec.lua` and others leak global state (e.g. _G.vim.fn.jobstart).
2. [Gap 10] - [Medium Impact/Low Effort] - Missing support for Database Path (`-d`, `--database FILE`).
3. [Gap 11] - [Medium Impact/Low Effort] - Missing support for No Log (`-n`, `--no-log`).
4. [Gap 12] - [Medium Impact/Low Effort] - Missing support for explicit Log (`--log`).
5. [Gap 1] - [Medium Impact/Low Effort] - Missing support for explicit Attachment Type (`--at`, `--attachment-type`).
6. [Gap 4] - [Medium Impact/Low Effort] - Missing support for Usage tracking (`-u`, `--usage`).
7. [Gap 5] - [Medium Impact/Low Effort] - Missing support for Query Selection (`-q`, `--query`).
8. [Gap 6] - [Medium Impact/Low Effort] - Missing support for Stream Control (`--no-stream`) and Async Execution (`--async`).
9. [Gap 7] - [Medium Impact/Low Effort] - Missing support for Extract Last (`--xl`, `--extract-last`).
10. [Gap 8] - [Medium Impact/Low Effort] - Missing support for explicit Schema Multi (`--schema-multi`).
11. [Tech Debt 3] - [Medium Impact/Low Effort] - Write explicit unit tests for `interactive_prompt_with_fragments` in `commands.lua`.
12. [Tech Debt 11] - [Medium Impact/Low Effort] - Missing mock for `vim.trim` and potentially other global utils when testing under busted.
13. [Tech Debt 12] - [Medium Impact/Low Effort] - Missing global utility mocks in `mock_vim.lua` (e.g. vim.split, vim.list_extend, vim.tbl_isempty) for busted test environment.
14. [Tech Debt 4] - [Medium Impact/Medium Effort] - Increase test coverage for templates_manager.lua to >80%.
15. [Tech Debt 5] - [Medium Impact/Medium Effort] - Increase test coverage for schemas_manager.lua to >80%.
16. [Tech Debt 6] - [Medium Impact/Medium Effort] - Increase test coverage for models_manager.lua to >80%.
17. [Tech Debt 7] - [Medium Impact/Medium Effort] - Increase test coverage for unified_manager.lua to >80%.
18. [Tech Debt 8] - [Medium Impact/Medium Effort] - Increase test coverage for plugins_manager.lua to >80%.
19. [Tech Debt 9] - [Medium Impact/Medium Effort] - Increase test coverage for tools_manager.lua to >80%.
20. [Tech Debt 10] - [Medium Impact/Medium Effort] - Increase test coverage for custom_openai.lua to >80%.
21. [Gap 2] - [Low Impact/Low Effort] - Missing support for Hide Reasoning (`-R`, `--hide-reasoning`).
22. [Gap 3] - [Low Impact/Low Effort] - Missing support for JSON output (`--json`).
23. [Gap 9] - [Low Impact/Low Effort] - Missing support for explicitly setting the API key for a prompt (`--key`).
24. [Tech Debt 2] - [Low Impact/Low Effort] - Test coverage missing for `scripts/llm.py` error conditions (JSONDecodeError handling).
