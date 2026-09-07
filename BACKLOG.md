## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- [Prompt]: Execute a prompt (`llm prompt`).
- [Aliases]: Manage model aliases (`llm aliases`).
- [Chat]: Hold an ongoing chat with a model. (`llm chat`).
- [Collections]: View and manage collections of embeddings (`llm collections`).
- [Embed]: Embed text and store or return the result (`llm embed`).
- [Embed-models]: Manage available embedding models (`llm embed-models`).
- [Embed-multi]: Store embeddings for multiple strings at once (`llm embed-multi`).
- [Fragments]: Manage fragments that are stored in the database (`llm fragments`).
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
- [--key TEXT]: API key to use (`--key TEXT`).
- [--save TEXT]: Save prompt with this template name (`--save TEXT`).
- [--async]: Run prompt asynchronously (`--async`).
- [-u, --usage]: Show token usage (`-u`, `--usage`).
- [-x, --extract]: Extract first fenced code block (`-x, --extract`).
- [--xl, --extract-last]: Extract last fenced code block (`--xl, --extract-last`).
- [--json]: Output the response as JSON (`--json`).

## Gaps & Tech Debt
- [Gap 1]: Missing support for managing available embedding models (`llm embed-models`).
- [Gap 2]: Missing support for showing options for the selected model (`--options`).
- [Gap 3]: Missing support for explicitly disabling logging via `--no-log` (`-n, --no-log`).
- [Gap 4]: Missing support for explicitly enabling logging via `--log` (`--log`).
- [Gap 5]: Missing commands for logs management in editor context (`llm logs list`).
- [Tech Debt 1]: Hacky directory writability check using test file creation and `os.remove` in `file_utils.lua` instead of `vim.fn.filewritable`.

## Ranked Backlog
1. [Tech Debt 1] - [Medium Impact/Low Effort] - Hacky directory writability check using test file creation and `os.remove` in `file_utils.lua` instead of `vim.fn.filewritable`.
2. [Gap 2] - [Medium Impact/Low Effort] - Missing support for showing options for the selected model (`--options`).
3. [Gap 3] - [Low Impact/Low Effort] - Missing support for explicitly disabling logging via `--no-log` (`-n, --no-log`).
4. [Gap 4] - [Low Impact/Low Effort] - Missing support for explicitly enabling logging via `--log` (`--log`).
5. [Gap 5] - [Low Impact/Medium Effort] - Missing commands for logs management in editor context (`llm logs list`).
6. [Gap 1] - [Medium Impact/Medium Effort] - Missing support for managing available embedding models (`llm embed-models`).
