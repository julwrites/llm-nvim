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

### Current Priority Tasks

**Phase 1 - Critical Fixes** (start here):
- CRITICAL-001: Fix Lua 5.2+ compatibility (unpack → table.unpack)
- CRITICAL-002: Implement proper line buffering in job.lua

**Phase 2 - Quality** (after Phase 1):
- CODE-QUALITY-001: Remove excessive debug logging
- TESTING-001: Audit Lua compatibility
- DOCUMENTATION-001: Document Lua version requirements

See `docs/tasks/README.md` for complete task list and phases.

## Testing

Run tests using the Makefile:

```bash
# Install test dependencies
make test-deps

# Run all tests
make test

# Run specific test file
make test file=init_spec.lua
```

Tests use busted framework and require luarocks packages: busted and luassert.

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
