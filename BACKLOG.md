## Unranked Catalog (Upstream LLM CLI features applicable to Neovim)
- [Prompt]: Execute a prompt (`llm prompt`).
- [Aliases]: Manage model aliases (`llm aliases`).
- [Chat]: Hold an ongoing chat with a model (`llm chat`).
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
- [-s, --system TEXT]: System prompt to use (`-s`, `--system`).
- [-m, --model TEXT]: Model to use (`-m`, `--model`).
- [-d, --database FILE]: Path to log database (`-d`, `--database`).
- [-q, --query TEXT]: Use first model matching these strings (`-q`, `--query`).
- [-a, --attachment ATTACHMENT]: Attachment path or URL or - (`-a`, `--attachment`).
- [--at, --attachment-type TEXT]: Attachment with explicit mimetype (`--at`, `--attachment-type`).
- [-T, --tool TEXT]: Name of a tool to make available (`-T`, `--tool`).
- [--functions TEXT]: Python code block or file path defining functions (`--functions`).
- [--td, --tools-debug]: Show full details of tool executions (`--td`, `--tools-debug`).
- [--ta, --tools-approve]: Manually approve every tool execution (`--ta`, `--tools-approve`).
- [--cl, --chain-limit INTEGER]: How many chained tool responses to allow (`--cl`, `--chain-limit`).
- [-o, --option TEXT]: key/value options for the model (`-o`, `--option`).
- [--options]: Show options for the selected model (`--options`).
- [--schema TEXT]: Schema DSL, JSON schema, filepath or ID (`--schema`).
- [--schema-multi TEXT]: Schema for multiple results (`--schema-multi`).
- [-f, --fragment TEXT]: Fragment to add to the prompt (`-f`, `--fragment`).
- [--sf, --system-fragment TEXT]: Fragment to add to system prompt (`--sf`, `--system-fragment`).
- [-t, --template TEXT]: Template to use (`-t`, `--template`).
- [-p, --param TEXT]: Parameters for template (`-p`, `--param`).
- [--no-stream]: Do not stream output (`--no-stream`).
- [-n, --no-log]: Don't log to database (`-n`, `--no-log`).
- [--log]: Log prompt and response to the database (`--log`).
- [-R, --hide-reasoning]: Hide reasoning output (`-R`, `--hide-reasoning`).
- [-c, --continue]: Continue the most recent conversation (`-c`, `--continue`).
- [--cid, --conversation TEXT]: Continue the conversation with the given ID (`--cid`, `--conversation`).
- [--key TEXT]: API key to use (`--key`).
- [--save TEXT]: Save prompt with this template name (`--save`).
- [--async]: Run prompt asynchronously (`--async`).
- [-u, --usage]: Show token usage (`-u`, `--usage`).
- [-x, --extract]: Extract first fenced code block (`-x`, `--extract`).
- [--xl, --extract-last]: Extract last fenced code block (`--xl`, `--extract-last`).
- [--json]: Output the response as JSON (`--json`).

## Gaps & Tech Debt
- [Gap 1]: Missing command to view default options for all models (`llm models options`).
- [Gap 2]: Unused code/missing global command for `models_manager.manage_models` or `unified_manager.open_specific_manager("Models")`. There is no `:LLMModels` user command to easily open the model manager.

## Ranked Backlog
1. [Gap 2] - [High Impact/Low Effort] - Missing global command `:LLMModels` to directly open the models manager view.
2. [Gap 1] - [Medium Impact/Medium Effort] - Missing command to view default options for all models (`llm models options`).