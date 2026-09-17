## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- [Prompt]: Execute a prompt (`llm prompt`).
- [Chat]: Hold an ongoing chat with a model. (`llm chat`).
- [Collections]: View and manage collections of embeddings (`llm collections`).
- [Embed]: Embed text and store or return the result (`llm embed`).
- [Embed-multi]: Store embeddings for multiple strings at once in the database (`llm embed-multi`).
- [Similar]: Return top N similar IDs from a collection using cosine similarity (`llm similar`).
- [Tools]: Manage tools that can be made available to LLMs (`llm tools`).
- [-s, --system TEXT]: System prompt to use (`-s`).
- [-m, --model TEXT]: Model to use (`-m`).
- [-d, --database FILE]: Path to log database (`-d`).
- [-q, --query TEXT]: Use first model matching these strings (`-q`).
- [-a, --attachment ATTACHMENT]: Attachment path or URL or - (`-a`).
- [--at, --attachment-type <TEXT TEXT>...]: Attachment with explicit mimetype, (`--at`).
- [-T, --tool TEXT]: Name of a tool to make available to the model (`-T`).
- [--functions TEXT]: Python code block or file path defining functions to register as tools (`--functions TEXT`).
- [--td, --tools-debug]: Show full details of tool executions (`--td`).
- [--ta, --tools-approve]: Manually approve every tool execution (`--ta`).
- [--cl, --chain-limit INTEGER]: How many chained tool responses to allow, default 5, set 0 for unlimited (`--cl`).
- [-o, --option <TEXT TEXT>...]: key/value options for the model (`-o`).
- [--options]: Show options for the selected model (`--options`).
- [--schema TEXT]: Schema DSL, JSON schema, filepath or ID (`--schema TEXT`).
- [--schema-multi TEXT]: Schema for multiple results (`--schema-multi TEXT`).
- [-f, --fragment TEXT]: Fragment (alias, URL, hash or file path) to add to the prompt (`-f`).
- [--sf, --system-fragment TEXT]: Fragment to add to system prompt (`--sf`).
- [-t, --template TEXT]: Template to use; can be repeated to combine templates (`-t`).
- [-p, --param <TEXT TEXT>...]: Parameters for template (`-p`).
- [--no-stream]: Do not stream output (`--no-stream`).
- [-n, --no-log]: Don't log to database (`-n`).
- [--log]: Log prompt and response to the database (`--log`).
- [-R, --hide-reasoning]: Hide reasoning output (`-R`).
- [-c, --continue]: Continue the most recent conversation. (`-c`).
- [--cid, --conversation TEXT]: Continue the conversation with the given ID. (`--cid`).
- [--key TEXT]: API key to use (`--key TEXT`).
- [--save TEXT]: Save prompt with this template name (`--save TEXT`).
- [--async]: Run prompt asynchronously (`--async`).
- [-u, --usage]: Show token usage (`-u`).
- [-x, --extract]: Extract first fenced code block (`-x`).
- [--xl, --extract-last]: Extract last fenced code block (`--xl`).
- [--json]: Output the response as JSON, same format as llm logs --json (`--json`).

## Gaps & Tech Debt
- [Tech Debt]: In `lua/llm/chat.lua`, the `on_stdout` callback blindly iterates over chunks and improperly parses partial lines instead of accumulating a proper string buffer.
- [Tech Debt]: In `lua/llm/commands.lua`, argument parsing is directly coupled to `config.get()`, limiting the ability to supply local overrides per command execution.

## Ranked Backlog
1. [Fix String Buffering in Chat] - [High Impact/Low Effort] - In `lua/llm/chat.lua`, the `on_stdout` callback blindly iterates over chunks and improperly parses partial lines instead of accumulating a proper string buffer.
2. [Global Config Coupling] - [Medium Impact/Medium Effort] - In `lua/llm/commands.lua`, argument parsing is directly coupled to `config.get()`, limiting the ability to supply local overrides per command execution.
