# AI Agent Instructions

You are an expert Software Engineer working on this project. Your primary responsibility is to implement features and fixes while strictly adhering to the **Task Documentation System**.

## Core Philosophy
**"If it's not documented in `docs/tasks/`, it didn't happen."**

## Workflow
1.  **Pick a Task**: Run `python3 scripts/tasks.py next` to find the best task, `context` to see active tasks, or `list` to see pending ones.
2.  **Plan & Document**:
    *   **Memory Check**: Run `python3 scripts/memory.py list` (or use the Memory Skill) to recall relevant long-term information.
    *   **Security Check**: Ask the user about specific security considerations for this task.
    *   If starting a new task, use `scripts/tasks.py create` (or `python3 scripts/tasks.py create`) to generate a new task file.
    *   Update the task status: `python3 scripts/tasks.py update [TASK_ID] in_progress`.
3.  **Implement**: Write code, run tests.
4.  **Update Documentation Loop**:
    *   As you complete sub-tasks, check them off in the task document.
    *   If you hit a blocker, update status to `wip_blocked` and describe the issue in the file.
    *   Record key architectural decisions in the task document.
    *   **Memory Update**: If you learn something valuable for the long term, use `scripts/memory.py create` to record it.
5.  **Review & Verify**:
    *   Once implementation is complete, update status to `review_requested`: `python3 scripts/tasks.py update [TASK_ID] review_requested`.
    *   Ask a human or another agent to review the code.
    *   Once approved and tested, update status to `verified`.
6.  **Finalize**:
    *   Update status to `completed`: `python3 scripts/tasks.py update [TASK_ID] completed`.
    *   Record actual effort in the file.
    *   Ensure all acceptance criteria are met.

## Tools
*   **Wrapper**: `./scripts/tasks` (Checks for Python, recommended).
*   **Next**: `./scripts/tasks next` (Finds the best task to work on).
*   **Create**: `./scripts/tasks create [category] "Title"`
*   **List**: `./scripts/tasks list [--status pending]`
*   **Context**: `./scripts/tasks context`
*   **Update**: `./scripts/tasks update [ID] [status]`
*   **Migrate**: `./scripts/tasks migrate` (Migrate legacy tasks to new format)
*   **Memory**: `./scripts/memory.py [create|list|read]`
*   **JSON Output**: Add `--format json` to any command for machine parsing.

## Documentation Reference
*   **Guide**: Read `docs/tasks/GUIDE.md` for strict formatting and process rules.
*   **Architecture**: Refer to `docs/architecture/` for system design.
*   **Features**: Refer to `docs/features/` for feature specifications.
*   **Security**: Refer to `docs/security/` for risk assessments and mitigations.
*   **Memories**: Refer to `docs/memories/` for long-term project context.

## Code Style & Standards
*   Follow the existing patterns in the codebase.
*   Ensure all new code is covered by tests (if testing infrastructure exists).

## PR Review Methodology
When performing a PR review, follow this "Human-in-the-loop" process to ensure depth and efficiency.

### 1. Preparation
1.  **Create Task**: `python3 scripts/tasks.py create review "Review PR #<N>: <Title>"`
2.  **Fetch Details**: Use `gh` to get the PR context.
    *   `gh pr view <N>`
    *   `gh pr diff <N>`

### 2. Analysis & Planning (The "Review Plan")
**Do not review line-by-line yet.** Instead, analyze the changes and document a **Review Plan** in the task file (or present it for approval).

Your plan must include:
*   **High-Level Summary**: Purpose, new APIs, breaking changes.
*   **Dependency Check**: New libraries, maintenance status, security.
*   **Impact Assessment**: Effect on existing code/docs.
*   **Focus Areas**: Prioritized list of files/modules to check.
*   **Suggested Comments**: Draft comments for specific lines.
    *   Format: `File: <path> | Line: <N> | Comment: <suggestion>`
    *   Tone: Friendly, suggestion-based ("Consider...", "Nit: ...").

### 3. Execution
Once the human approves the plan and comments:
1.  **Pending Review**: Create a pending review using `gh`.
    *   `COMMIT_SHA=$(gh pr view <N> --json headRefOid -q .headRefOid)`
    *   `gh api repos/{owner}/{repo}/pulls/{N}/reviews -f commit_id="$COMMIT_SHA"`
2.  **Batch Comments**: Add comments to the pending review.
    *   `gh api repos/{owner}/{repo}/pulls/{N}/comments -f body="..." -f path="..." -f commit_id="$COMMIT_SHA" -F line=<L> -f side="RIGHT"`
3.  **Submit**:
    *   `gh pr review <N> --approve --body "Summary..."` (or `--request-changes`).

### 4. Close Task
*   Update task status to `completed`.

## Agent Interoperability
- **Task Manager Skill**: `.claude/skills/task_manager/`
- **Memory Skill**: `.claude/skills/memory/`
- **Tool Definitions**: `docs/interop/tool_definitions.json`

---

# Project Specifics

## Project Overview

llm-nvim is a Neovim plugin that integrates with Simon Willison's llm CLI tool, enabling users to interact with large language models directly from Neovim. The plugin provides a unified interface for prompting LLMs, managing models, API keys, and fragments.

## Requirements

- Neovim 0.7.0 or later (LuaJIT 2.1+)
- Lua 5.2+ compatible code
- llm CLI tool (`pip install llm` or `brew install llm`)

**Lua Environment**: Neovim uses LuaJIT 2.1+ which provides Lua 5.1 base with 5.2+ extensions. This plugin uses Lua 5.2+ APIs (`table.unpack`) for forward compatibility. See TESTING-001 for full compatibility audit results.

## Testing

Run tests using the Makefile:

```bash
# Install test dependencies
make test-deps

# Run all tests
make test

# Run a specific test file
make test file=init_spec.lua

# Run tests with code coverage
make coverage
```

Tests use the `busted` framework and require `luarocks` packages: `busted` and `luassert`.

The `make coverage` command uses `luacov` to generate a code coverage report. The CI pipeline will fail if code coverage drops below a certain threshold.

**IMPORTANT**: When adding new features or modifying existing code, it is crucial to add or update tests to maintain or increase the code coverage. All new code should be accompanied by corresponding tests.

**Testing `vim.api`**: The testing strategy for functions using `vim.api` depends on their purpose:
- **Non-UI Operations**: For operations that manipulate buffers, lines, or other non-UI elements (e.g., `vim.api.nvim_buf_set_lines`, `vim.api.nvim_get_current_buf`), it is acceptable to call `vim.api` directly. The test environment supports these functions.
- **UI Operations**: For functions that create or manage UI elements like floating windows or pop-up menus (e.g., `vim.api.nvim_open_win`), these functions should be mocked. The test environment does not have a display server, and calling these will cause errors. Mocking allows the test to verify the business logic leading up to the UI call without testing the UI itself.
- **Verify UI Calls with Spies**: When testing functions that call UI-related functions, use spies to verify that the UI functions were called with the correct arguments. This is sufficient to confirm the integration between business logic and the UI without needing to mock the UI's internal behavior.


**Testing Strategy for UI Components**:

-   **Avoid Mocking Neovim UI**: Do not attempt to create comprehensive mocks for Neovim's UI components (e.g., buffers, windows). Mocks of the `vim.api` are brittle and lead to tests that are difficult to maintain.
-   **Focus on Unit Testing Logic**: Maximize code coverage by writing unit tests for the underlying business logic of UI components. For example, when testing a module that formats data for a buffer, test the data formatting function in isolation, not the function that writes the data to the buffer.
-   **Use Integration Tests Sparingly**: For critical UI workflows, it is acceptable to write a small number of integration tests that run inside a headless Neovim instance. However, these tests should be limited in scope and should not attempt to cover all edge cases.

## Architecture

### Entry Points

- `plugin/llm.lua`: Plugin initialization, command registration, and user command handlers
- `lua/llm/init.lua`: Main module entry point, setup configuration, and facade function exposure
- `lua/llm/facade.lua`: Centralized API surface with lazy-loaded managers

### Core Modules

- `lua/llm/config.lua`: Configuration management with validation, defaults, and change listeners
- `lua/llm/commands.lua`: Command execution layer that handles prompt processing, file/selection operations
- `lua/llm/api.lua`: LLM CLI interaction and streaming command execution
- `lua/llm/chat.lua`: Chat session management

### Managers (in `lua/llm/managers/`)

Each manager handles a specific domain:

- `models_manager.lua`: Model listing, selection, and default model management
- `plugins_manager.lua`: LLM plugin installation and management
- `keys_manager.lua`: API key management for various providers
- `fragments_manager.lua`: Fragment management (files, URLs, GitHub repos)
- `templates_manager.lua`: Template creation and execution
- `schemas_manager.lua`: Schema management and execution

### Core Utilities (in `lua/llm/core/`)

- `utils/shell.lua`: Shell command execution and LLM CLI update checks
- `utils/ui.lua`: Buffer creation and content management
- `utils/text.lua`: Text manipulation (visual selection, escaping)
- `utils/validate.lua`: Configuration validation and type conversion
- `utils/job.lua`: Asynchronous job execution
- `utils/file_utils.lua`: File operations
- `utils/notify.lua`: User notifications
- `data/llm_cli.lua`: LLM CLI data operations
- `data/cache.lua`: Caching layer
- `loaders.lua`: Data loading on initialization

### UI Components (in `lua/llm/ui/`)

- `unified_manager.lua`: Unified manager window with multi-view support
- `styles.lua`: Syntax highlighting and visual styling
- `views/`: Individual view implementations (models_view, plugins_view, keys_view, fragments_view, templates_view, schemas_view)

### Command Flow

1. User commands (`:LLM`, `:LLMChat`, `:LLMConfig`) are registered in `plugin/llm.lua`
2. Commands delegate to `lua/llm/commands.lua` for execution
3. `commands.lua` constructs llm CLI commands with proper arguments (model, system prompt, fragments)
4. `api.lua` executes commands with streaming output
5. Results are displayed in buffers created by `ui.lua`

### Manager Pattern

Managers use lazy loading via `facade.lua`:
- First access triggers `require()` and caches the module
- Managers interact with llm CLI through `api.lua` and `shell.lua`
- UI operations use unified_manager and view components
- Data persistence handled by individual managers

### Configuration System

Configuration in `config.lua`:
- Defines defaults with type metadata
- Validates and normalizes user options
- Supports change listeners for reactive updates
- Accessed via `config.get(key)` throughout the codebase

### Visual Selection Handling

When prompting with selection:
1. `text.get_visual_selection()` captures selected text
2. Selection written to temp file via `commands.write_context_to_temp_file()`
3. Temp file passed as fragment argument to llm CLI
4. Temp file cleaned up after command execution

## Recent Fixes and Learnings

### Keys Manager Fixes (November 2024)

**IMPORTANT**: The following issues were identified and fixed during keys manager development:

#### 1. Keys List JSON Parsing
- **Problem**: `llm keys list --json` command doesn't exist (no --json flag)
- **Solution**: Use plain text parsing instead of JSON
- **Files affected**: `lua/llm/managers/keys_manager.lua:get_stored_keys()`

#### 2. Key Setting Syntax
- **Problem**: Incorrect command syntax `llm keys set provider key-value`
- **Solution**: Use `llm keys set provider --value key-value` syntax
- **Files affected**: `lua/llm/managers/keys_manager.lua:set_api_key()`

#### 3. Key Removal Implementation
- **Problem**: `llm keys remove` command doesn't exist
- **Solution**: Direct JSON file editing using `llm keys path`
- **Files affected**: `lua/llm/managers/keys_manager.lua:remove_api_key()`

### Fragments Manager Fixes (November 2024)

#### 1. Fragment Viewing
- **Problem**: Parameter order incorrect in `view_fragment_under_cursor`
- **Solution**: Fixed parameter order and added nil-safe checks
- **Files affected**: `lua/llm/managers/fragments_manager.lua:view_fragment_under_cursor()`

#### 2. Alias Management
- **Problem**: Incorrect command syntax for alias add/remove
- **Solution**: Use correct commands `fragments set` and `fragments remove`
- **Files affected**: `lua/llm/managers/fragments_manager.lua:set_alias_for_fragment_under_cursor()`, `remove_alias_from_fragment_under_cursor()`

## Chat Functionality Learnings

**IMPORTANT**: The following issues were identified and fixed during chat functionality development. These should be referenced when making changes to chat-related code to prevent regression.

### Critical Issues and Solutions

#### 1. Lua Compatibility Issues
- **Problem**: `table.unpack` vs `_G.unpack` compatibility between Lua 5.1 and 5.2+
- **Solution**: Use compatibility shim: `local unpack = table.unpack or _G.unpack`
- **Files affected**: `lua/llm/chat/buffer.lua`

#### 2. API Method Naming
- **Problem**: Incorrect API method name `api.run` instead of `api.run_llm_command`
- **Solution**: Always use full method names from API documentation
- **Files affected**: `lua/llm/chat/session.lua`

#### 3. Job Utility Issues
- **Problem**: Missing command validation and nil-safe handling
- **Solution**: Add proper validation and error handling in job runner
- **Files affected**: `lua/llm/core/utils/job.lua`

#### 4. Configuration Initialization
- **Problem**: Plugin configuration not initialized before use
- **Solution**: Call `llm.setup()` during plugin initialization
- **Files affected**: `plugin/llm.lua`

#### 5. LLM Command Syntax
- **Problem**: Using `llm chat` instead of `llm` for non-interactive mode
- **Solution**: Use `llm` directly and send prompt via stdin
- **Files affected**: `lua/llm/chat/session.lua`

#### 6. Job Callback Signature
- **Problem**: Incorrect callback signature in job utility
- **Solution**: Use `function(j, data)` instead of `function(j, d, e)`
- **Files affected**: `lua/llm/core/utils/job.lua`

#### 7. Stdin Handling
- **Problem**: Not closing stdin after sending prompt, causing hanging
- **Solution**: Call `vim.fn.jobclose(job_id, "stdin")` after `vim.fn.jobsend()`
- **Files affected**: `lua/llm/api.lua`

#### 8. Buffer Modifiability
- **Problem**: Buffer becoming non-modifiable after LLM response
- **Solution**: Ensure buffer remains modifiable for user input:
  - `render()`: Leave buffer modifiable for initial input
  - `append_user_message()`: Leave modifiable for LLM operations
  - `add_llm_header()`: Leave modifiable for response
  - `append_llm_message()`: Set non-modifiable to protect response
  - `add_user_header()`: Leave modifiable for next message
- **Files affected**: `lua/llm/chat/buffer.lua`

#### 9. Session State Management
- **Problem**: Session state never reset from "processing" to "ready"
- **Solution**: Add `session:reset_state()` call in `on_exit` callback
- **Files affected**: `lua/llm/chat.lua`, `lua/llm/chat/session.lua`

### Debugging Strategy

When debugging chat functionality:
1. **Add comprehensive logging** to callback functions (`on_stdout`, `on_stderr`, `on_exit`)
2. **Check job execution flow**: command building → job start → stdin send → callback execution
3. **Verify buffer operations**: modifiability state changes and content updates
4. **Test session state**: ensure proper state transitions (ready → processing → ready)

### Testing Considerations

- Always test multi-message conversations to verify session state management
- Verify buffer remains modifiable after LLM responses
- Test with different LLM models and conversation configurations
- Ensure proper cleanup when chat buffers are closed
