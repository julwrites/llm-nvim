# AGENTS.md

This file provides guidance to Qoder (qoder.com) when working with code in this repository.

## Project Overview

llm-nvim is a Neovim plugin that integrates with Simon Willison's llm CLI tool, enabling users to interact with large language models directly from Neovim. The plugin provides a unified interface for prompting LLMs, managing models, API keys, fragments, templates, and schemas.

## Requirements

- Neovim 0.7.0 or later (LuaJIT 2.1+)
- Lua 5.2+ compatible code
- llm CLI tool (`pip install llm` or `brew install llm`)

**Lua Environment**: Neovim uses LuaJIT 2.1+ which provides Lua 5.1 base with 5.2+ extensions. This plugin uses Lua 5.2+ APIs (`table.unpack`) for forward compatibility. See TESTING-001 for full compatibility audit results.

## Documentation

**IMPORTANT**: Always consult these documents during planning and development:

- `docs/features.md`: Complete feature list and requirements
- `docs/architecture.md`: Architecture decisions, data flows, and technical rationale
- `docs/tasks/README.md`: Overview of task system and current task status
- Individual task files in `docs/tasks/[category]/`: Detailed implementation tasks

When planning new features or refactoring:
1. First read `docs/features.md` to understand existing functionality
2. Review `docs/architecture.md` to understand design patterns and decisions
3. Check `docs/tasks/README.md` for pending tasks and priorities
4. Read specific task documents before implementing
5. Update task documents as work progresses
6. Update relevant docs when making architectural changes

## Task Documentation System

All implementation tasks are documented in `docs/tasks/` following a standardized format.

### Task Categories

- **critical/**: Blocking issues affecting functionality (P0)
- **code-quality/**: Code cleanup and maintainability (P1)
- **testing/**: Test infrastructure and quality (P1-P2)
- **documentation/**: Documentation improvements (P2)
- **performance/**: Performance optimizations (P3)

### Working with Tasks

**Before starting work**:
1. Check `docs/tasks/README.md` for task overview and status
2. Read the specific task document in `docs/tasks/[category]/`
3. Verify dependencies are completed
4. Update task status to `in_progress`

**During implementation**:
1. Follow acceptance criteria in the task document
2. Use implementation notes as guidance
3. Update task document with:
   - Completed acceptance criteria (check boxes)
   - Decisions made and why
   - Blockers encountered and resolution
   - Git commits with references
4. Create new tasks if you discover additional work needed

**After completion**:
1. Mark all acceptance criteria as complete
2. Update status to `completed`
3. Record actual effort and completion date
4. Update `docs/tasks/README.md` status table
5. Create follow-up tasks if needed

### Finding Tasks

```bash
# View all pending tasks by category
ls docs/tasks/critical/
ls docs/tasks/code-quality/
ls docs/tasks/testing/

# Find tasks with no dependencies (can start immediately)
grep -r "Dependencies**: None" docs/tasks/

# Find blocked tasks
grep -r "Status**: blocked" docs/tasks/
```

### Creating New Tasks

1. Choose appropriate category (critical, code-quality, testing, documentation, performance)
2. Generate task ID: `[CATEGORY]-NNN` (use next available number in category)
3. Create file: `docs/tasks/[category]/[TASK-ID]-[descriptive-slug].md`
4. Use template from `task-documentation-guide.md`
5. Include:
   - Clear description and problem statement
   - Acceptance criteria (specific and measurable)
   - Implementation notes with file references
   - Architecture components affected
   - Dependencies on other tasks
6. Add to `docs/tasks/README.md` task list

### Completed Tasks

When a task is completed, it should be moved from its category directory to the `docs/tasks/completed/` directory. This keeps the main task directories focused on pending work.

## Current Status and Quick Start

### 🎯 Current Priority Tasks

**✅ Completed Tasks** (ready for new feature development):
- All critical fixes completed
- Test suite stable (180/180 tests passing)
- Architecture fully documented with ADRs
- Core functionality working reliably

**🚀 Ready for New Contributors** (no blockers):
- Codebase is stable and well-tested
- Comprehensive documentation available
- Clear architectural patterns established
- No blocking technical debt

**📋 What to Work On Next**:
1. **New Features**: Check `docs/features.md` for planned features
2. **Enhancements**: Review `docs/tasks/README.md` for pending improvements
3. **Documentation**: Update docs when adding new functionality

See `docs/tasks/README.md` for complete task list and current status.

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
