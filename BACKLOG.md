## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- [Prompt]: Execute a prompt (`llm prompt`).
- [Chat]: Hold an ongoing chat with a model. (`llm chat`).
- [Tools]: Manage tools that can be made available to LLMs (`llm tools`).
- [Collections]: View and manage collections of embeddings (`llm collections`).
- [Embed]: Embed text and store or return the result (`llm embed`).
- [Embed Multi]: Store embeddings for multiple strings at once (`llm embed-multi`).
- [Similar]: Return top N similar IDs from a collection using cosine similarity (`llm similar`).
- [-s, --system]: System prompt to use.
- [-m, --model]: Model to use.
- [-d, --database]: Path to log database.
- [-q, --query]: Use first model matching these strings.
- [-a, --attachment]: Attachment path or URL.
- [--at, --attachment-type]: Attachment with explicit mimetype.
- [-T, --tool]: Name of a tool to make available to the model.
- [--functions]: Python code block or file path defining functions to register as tools.
- [--td, --tools-debug]: Show full details of tool executions.
- [--ta, --tools-approve]: Manually approve every tool execution.
- [--cl, --chain-limit]: How many chained tool responses to allow.
- [-o, --option]: key/value options for the model.
- [--schema]: Schema DSL, JSON schema, filepath or ID.
- [--schema-multi]: Schema for multiple results.
- [-f, --fragment]: Fragment (alias, URL, hash or file path) to add to the prompt.
- [--sf, --system-fragment]: Fragment to add to system prompt.
- [-t, --template]: Template to use; can be repeated to combine templates.
- [-p, --param]: Parameters for template.
- [--no-stream]: Do not stream output.
- [-n, --no-log]: Don't log to database.
- [--log]: Log prompt and response to the database.
- [-R, --hide-reasoning]: Hide reasoning output.
- [-c, --continue]: Continue the most recent conversation.
- [--cid, --conversation]: Continue the conversation with the given ID.
- [--key]: API key to use.
- [--save]: Save prompt with this template name.
- [--async]: Run prompt asynchronously.
- [-u, --usage]: Show token usage.
- [-x, --extract]: Extract first fenced code block.
- [--xl, --extract-last]: Extract last fenced code block.
- [--json]: Output the response as JSON.

## Gaps & Tech Debt
- [Feature Gap - Extraction UI Flow]: Missing Interactive Command implementations for Extractions (`-x`, `--xl`). These arguments are parsed in `lua/llm/commands.lua` but lack exposed interactive UI flows.
- [Feature Gap - Schema Output Flow]: Missing Interactive Command implementations for Schema Options (`--schema`, `--schema-multi`) and Output Control (`--json`, `-R`). These arguments are parsed in `lua/llm/commands.lua` but lack exposed interactive UI flows.
- [Feature Gap - Tool Options UI]: Missing Interactive Command implementations for explicit attachment type (`--at`) and tool options (`--td`, `--ta`, `--cl`). These arguments are parsed in `lua/llm/commands.lua` but lack exposed interactive UI flows.
- [Feature Gap - Token Usage UI]: Missing Interactive Command implementation for token usage (`-u`).
- [Tech Debt - Improper String Buffering in on_stdout callbacks]: In modules evaluating the callback logic (e.g. `lua/llm/commands.lua`, `lua/llm/chat.lua`, `lua/llm/api.lua`), using `table.concat(lines, "\n")` with `ui.append_to_buffer` artificially forces newlines onto partial chunks and breaks stream buffering. Faulty implementation logic exists for string buffering.
- [Tech Debt - Loss of Blank Lines in ui.lua]: `content_to_lines` in `lua/llm/core/utils/ui.lua` uses `gmatch("[^\r\n]+")` which drops consecutive blank lines entirely, corrupting LLM output formatting.

## Ranked Backlog
1. [Fix Loss of Blank Lines in UI] - [Medium Impact/Low Effort] - Fix `content_to_lines` in `lua/llm/core/utils/ui.lua` to properly process empty lines.
2. [Fix String Buffering in Callbacks] - [High Impact/Medium Effort] - Fix faulty string buffering implementations in `lua/llm/commands.lua`, `lua/llm/chat.lua`, and `lua/llm/api.lua` (improper string buffering and `table.concat` issues).
3. [Extraction UI Flow] - [Medium Impact/Medium Effort] - Plumb extraction flags (`-x`, `--xl`) into the UI/commands so users can interactively request just code blocks rather than full text responses.
4. [Schema Output Flow] - [Medium Impact/Medium Effort] - Plumb schema flags (`--schema`, `--schema-multi`, `--json`) into the UI/commands to allow users to enforce structured output generation inside the editor.
5. [Tool Options UI] - [Low Impact/Medium Effort] - Plumb tool flags (`--td`, `--ta`, `--cl`) and explicit attachments (`--at`) into the UI/commands for better tool debugging and approval.
6. [Token Usage & Hide Reasoning UI] - [Low Impact/Low Effort] - Plumb the `-u` usage flag and `-R` hide reasoning flag into the UI/commands to show token usage for prompts and responses, and support models that output long thought traces.