## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- [Prompt]: Execute a prompt (`llm prompt`).
- [Chat]: Hold an ongoing chat with a model. (`llm chat`).
- [Tools]: Manage tools that can be made available to LLMs (`llm tools`).
- [Collections]: View and manage collections of embeddings (`llm collections`).
- [Embed]: Embed text and store or return the result (`llm embed`).
- [Embed Multi]: Store embeddings for multiple strings at once (`llm embed-multi`).
- [Similar]: Return top N similar IDs from a collection using cosine similarity (`llm similar`).
- [-s, --system TEXT]: System prompt to use (`-s`).
- [-m, --model TEXT]: Model to use (`-m`).
- [-d, --database FILE]: Path to log database (`-d`).
- [-q, --query TEXT]: Use first model matching these strings (`-q`).
- [-a, --attachment ATTACHMENT]: Attachment path or URL or - (`-a`).
- [--at, --attachment-type <TEXT TEXT>...]: Attachment with explicit mimetype (`--at`).
- [-T, --tool TEXT]: Name of a tool to make available to the model (`-T`).
- [--functions TEXT]: Python code block or file path defining functions to register as tools (`--functions`).
- [--td, --tools-debug]: Show full details of tool executions (`--td`).
- [--ta, --tools-approve]: Manually approve every tool execution (`--ta`).
- [--cl, --chain-limit INTEGER]: How many chained tool responses to allow, default 5, set 0 for unlimited (`--cl`).
- [-o, --option <TEXT TEXT>...]: key/value options for the model (`-o`).
- [--schema TEXT]: Schema DSL, JSON schema, filepath or ID (`--schema`).
- [--schema-multi TEXT]: Schema for multiple results (`--schema-multi`).
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
- [--key TEXT]: API key to use (`--key`).
- [--save TEXT]: Save prompt with this template name (`--save`).
- [--async]: Run prompt asynchronously (`--async`).
- [-u, --usage]: Show token usage (`-u`).
- [-x, --extract]: Extract first fenced code block (`-x`).
- [--xl, --extract-last]: Extract last fenced code block (`--xl`).
- [--json]: Output the response as JSON, same format as llm logs --json (`--json`).

## Gaps & Tech Debt
- [Feature Gap]: Missing Interactive Command implementations for Extractions (`-x`, `--xl`), Schema Options (`--schema`, `--schema-multi`), Output Control (`--json`, `-R`), token usage (`-u`), explicit attachment type (`--at`), and tool options (`--td`, `--ta`, `--cl`). These arguments are parsed in `lua/llm/commands.lua` but lack exposed interactive UI flows.
- [Tech Debt & Bugs]: In modules evaluating callback logic (`lua/llm/chat.lua`, `lua/llm/core/data/llm_cli.lua`, and `lua/llm/core/utils/job.lua`), `on_stdout` callbacks blindly iterate and directly mutate the original `data` array payload (e.g., `data[1] = ...`, `table.remove(data)`), which breaks downstream consumers expecting the original payload. Furthermore, `lua/llm/core/data/llm_cli.lua` uses inefficient O(N) manual iteration with `table.insert` instead of directly leveraging `table.concat`.

## Ranked Backlog
1. [Stream Buffering State Fix] - [High Impact/Low Effort] - Refactor `on_stdout` callbacks in `lua/llm/chat.lua`, `lua/llm/core/data/llm_cli.lua`, and `lua/llm/core/utils/job.lua` to first copy the `data` array before stateful modification, preventing mutation bugs for downstream consumers, and replace blind iterations with `table.concat(data, "\n")` where applicable.
2. [Extraction UI Flow] - [Medium Impact/Medium Effort] - Plumb extraction flags (`-x`, `--xl`) into the UI/commands so users can interactively request just code blocks rather than full text responses.
3. [Schema Output Flow] - [Medium Impact/Medium Effort] - Plumb schema flags (`--schema`, `--schema-multi`, `--json`) into the UI/commands to allow users to enforce structured output generation inside the editor.
4. [Tool Options UI] - [Low Impact/Medium Effort] - Plumb tool flags (`--td`, `--ta`, `--cl`) into the UI/commands for better tool debugging and approval.
5. [Token Usage & Hide Reasoning UI] - [Low Impact/Low Effort] - Plumb the `-u` usage flag and `-R` hide reasoning flag into the UI/commands to show token usage for prompts and responses, and support models that output long thought traces.
