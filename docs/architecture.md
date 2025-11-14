# Architecture and Technical Decisions

This document provides an overview of llm-nvim's architecture. For detailed rationale behind major design decisions, see [Architectural Decision Records (ADRs)](adr/README.md).

## Quick Links

- **[ADRs](adr/README.md)**: Architectural decision records with detailed context and rationale
- **[Features](features.md)**: Complete feature list
- **[Development History](history.md)**: Historical record of completed work

## Project Structure

```
llm-nvim/
├── plugin/llm.lua              # Plugin initialization and command registration
├── lua/llm/
│   ├── init.lua               # Module entry point and setup
│   ├── facade.lua             # Centralized API surface with lazy loading
│   ├── config.lua             # Configuration management
│   ├── commands.lua           # Command execution layer
│   ├── api.lua                # LLM CLI interaction
│   ├── chat.lua               # Chat session management
│   ├── errors.lua             # Error handling
│   ├── core/
│   │   ├── loaders.lua        # Data loading on initialization
│   │   ├── data/
│   │   │   ├── llm_cli.lua    # LLM CLI data operations
│   │   │   └── cache.lua      # Caching layer
│   │   └── utils/
│   │       ├── shell.lua      # Shell command execution
│   │       ├── ui.lua         # Buffer and UI operations
│   │       ├── text.lua       # Text manipulation
│   │       ├── validate.lua   # Validation utilities
│   │       ├── job.lua        # Async job execution
│   │       ├── file_utils.lua # File operations
│   │       └── notify.lua     # User notifications
│   ├── managers/
│   │   ├── models_manager.lua
│   │   ├── plugins_manager.lua
│   │   ├── keys_manager.lua
│   │   ├── fragments_manager.lua
│   │   ├── templates_manager.lua
│   │   ├── schemas_manager.lua
│   │   └── custom_openai.lua
│   └── ui/
│       ├── unified_manager.lua  # Multi-view manager window
│       ├── styles.lua           # Syntax highlighting
│       └── views/
│           ├── models_view.lua
│           ├── plugins_view.lua
│           ├── keys_view.lua
│           ├── fragments_view.lua
│           ├── templates_view.lua
│           └── schemas_view.lua
└── tests/
    └── spec/                    # Test suite using busted
```

## Key Architectural Decisions

For detailed context, rationale, and alternatives considered for each decision, see the corresponding ADR in [docs/adr/](adr/README.md).

### 1. Facade Pattern for Manager Access

**Decision**: Use a facade with lazy loading for manager modules.

**See**: [ADR-003: Lazy-Loaded Manager Facade](adr/ADR-003-lazy-manager-facade.md)

**Rationale**: 
- Reduces startup time by loading managers only when needed
- Centralizes manager access for easier maintenance
- Provides clean API surface for external consumers

**Implementation**: `lua/llm/facade.lua` maintains a registry of managers and loads them on first access.

### 2. Streaming Command Execution

**Decision**: Use unified streaming function with callback-based output handling.

**See**: [ADR-001: Unified Streaming Command Execution](adr/ADR-001-streaming-unification.md)

**Rationale**:
- Provides real-time feedback to users
- Reduces memory footprint for large responses
- Allows for progressive rendering of markdown content

**Implementation**: `api.run_streaming_command()` accepts callbacks for stdout, stderr, and exit events. Commands define their own callback behavior.

### 3. Configuration System

**Decision**: Centralized configuration with validation and change listeners.

**See**: [ADR-005: Centralized Configuration System](adr/ADR-005-configuration-system.md)

**Rationale**:
- Single source of truth for all settings
- Type validation prevents runtime errors
- Change listeners enable reactive updates

**Implementation**: `config.lua` provides `setup()`, `get()`, and `on_change()` with metadata-driven validation.

### 4. Visual Selection Handling

**Decision**: Use temporary files for passing selections to llm CLI.

**See**: [ADR-004: Temporary Files for Visual Selection](adr/ADR-004-temp-file-selection.md)

**Rationale**:
- llm CLI expects file-based fragments
- Avoids shell escaping issues with multiline text
- Consistent with fragment system

**Implementation**: Selection written to `os.tmpname()`, passed as `-f` argument, cleaned up in `on_exit` callback.

### 5. Manager Pattern

**Decision**: Each domain (models, keys, fragments, etc.) has dedicated manager module.

**See**: [ADR-006: Domain-Specific Manager Pattern](adr/ADR-006-manager-pattern.md)

**Rationale**:
- Separation of concerns
- Independent testing
- Clear ownership of functionality

**Implementation**: Managers in `lua/llm/managers/` expose public API for their domain and encapsulate llm CLI interactions.

### 6. Buffer Management

**Decision**: Create specialized response buffers with filetype and syntax highlighting.

**Rationale**:
- Better UX with syntax-highlighted markdown
- Non-modifiable buffers prevent accidental edits
- Named buffers aid navigation

**Implementation**: `ui.lua` utilities create buffers with appropriate options and content.

### 7. Test Environment

**Decision**: Use busted with comprehensive vim mocking.

**Rationale**:
- Enables testing without Neovim instance
- Fast test execution
- Isolated test environment

**Implementation**: 
- `mock_vim.lua` provides complete vim API mock
- `spec_helper.lua` ensures consistent test setup
- Tests use spies and stubs for dependencies

### 8. Chat Conversation Management

**Decision**: Use llm CLI's built-in conversation tracking with `--continue` flag.

**See**: [ADR-002: LLM CLI Native Conversation Management](adr/ADR-002-chat-conversation.md)

**Rationale**:
- Leverages llm's native conversation storage
- Avoids reimplementing conversation history
- Consistent with llm CLI UX

**Implementation**: Buffer-local variable tracks chat state, `--continue` flag added for ongoing conversations.

### 9. Job-Based Async Execution

**Decision**: Use vim.fn.jobstart for async command execution.

**Rationale**:
- Non-blocking operation
- Native Neovim support
- Callback-driven for flexibility

**Implementation**: `job.lua` wraps jobstart with standardized callback interface.

### 10. Auto-Update System

**Decision**: Optional background CLI update checks with multiple package manager support.

**See**: [ADR-007: Auto-Update System for LLM CLI](adr/ADR-007-auto-update-system.md)

**Rationale**:
- Keeps users on latest llm CLI version
- Non-intrusive with configurable interval
- Supports diverse installation methods

**Implementation**: Timestamp tracking in `shell.lua`, async update via `vim.defer_fn`, tries uv/pipx/pip/brew in sequence.

### 11. Lua Version Compatibility

**Decision**: Use Lua 5.2+ APIs for forward compatibility.

**Rationale**:
- Neovim bundles LuaJIT 2.1+ with Lua 5.2 compatibility features
- Forward-compatible code prevents future migration issues
- `table.unpack` is available in both LuaJIT and Lua 5.2+
- Avoids deprecated Lua 5.1-only APIs that may be removed

**Implementation**: 
- Use `table.unpack` instead of global `unpack`
- Avoid `module()`, `setfenv`, `getfenv` (deprecated in 5.2)
- Use `load` instead of `loadstring` if needed
- Modern module pattern: `local M = {} ... return M`
- Standard library functions from Lua 5.2+

**Compatibility Audit Results** (from TESTING-001):
- ✅ 0 deprecated Lua 5.1 functions found
- ✅ All code uses modern, forward-compatible APIs
- ✅ 100% Lua 5.2+ compatible
- ✅ Full test suite passes on Neovim's LuaJIT

## Data Flow

### Command Execution Flow

**See**: [ADR-008: Command System Architecture](adr/ADR-008-command-system.md)

1. User invokes command (`:LLM`, `:LLMChat`, etc.)
2. `plugin/llm.lua` dispatches to appropriate handler
3. Handler in `commands.lua` constructs llm CLI command
4. `api.lua` executes command with streaming callbacks
5. Callbacks update response buffer via `ui.lua`
6. Cleanup runs in `on_exit` callback

### Manager Interaction Flow

1. User opens manager (`:LLMConfig [view]`)
2. `unified_manager.lua` creates/toggles window
3. View module (e.g., `models_view.lua`) renders content
4. User action triggers manager function
5. Manager interacts with llm CLI via `shell.lua`
6. Manager updates view with results

### Configuration Flow

1. User calls `setup()` in init.lua
2. `config.lua` validates and merges with defaults
3. Config values accessed via `config.get(key)`
4. Changes propagate to listeners
5. Managers react to config changes
