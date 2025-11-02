# Features and Requirements

## Core Features

### Unified LLM Command Interface (`:LLM`)
- Send prompts directly to LLMs
- Process selected text or entire files with LLMs
- Explain code in current buffer
- Support for custom models and system prompts
- Interactive prompting with fragments support

### Chat Interface (`:LLMChat`)
- Start interactive chat sessions with LLMs
- Conversation history management
- Streaming responses
- Continue previous conversations with `--continue` flag

### Unified Manager Window (`:LLMToggle`)
- Models view: List, select, and set default models
- Plugins view: Manage LLM plugins
- API Keys view: Manage API keys for multiple providers
- Fragments view: Manage files, URLs, and GitHub repos as fragments
- Templates view: Create and execute templates
- Schemas view: Manage and execute schemas

### Fragment Management
- Add files as fragments
- Add URLs as fragments
- Add GitHub repositories as fragments
- Reference fragments by alias or hash
- Use fragments in prompts to provide context

### Template System
- Create reusable prompt templates
- Execute templates with variable substitution
- Manage template library

### Schema System
- Define structured interaction schemas
- Execute schemas for consistent workflows
- Manage schema library

### API Key Management
- Store API keys for multiple LLM providers
- Set keys via unified manager
- Secure key storage through llm CLI

### Model Management
- List available models
- Select and set default model
- Support for custom models
- Integration with llm CLI model registry

### Plugin Management
- List available llm plugins
- Install plugins via manager
- Refresh plugin list

## Technical Requirements

### Dependencies
- Neovim 0.7.0 or later (includes LuaJIT 2.1+)
- Lua 5.2+ API compatibility
  - Uses `table.unpack` (Lua 5.2+)
  - Compatible with Neovim's bundled LuaJIT
  - No deprecated Lua 5.1-only APIs
- llm CLI tool (Simon Willison's llm)

### Output Format
- Markdown-formatted responses
- Syntax highlighting in response buffers
- Streaming output for real-time feedback

### Asynchronous Execution
- Non-blocking command execution
- Job-based process management
- Callback-driven output handling

### Auto-Update Feature
- Optional automatic CLI update checks
- Configurable update interval (default: 7 days)
- Multiple package manager support (uv, pipx, pip, brew)

## Configuration Options

- `model`: Default model to use
- `system_prompt`: Default system prompt for queries
- `no_mappings`: Disable default key mappings
- `debug`: Enable debug logging
- `auto_update_cli`: Enable/disable automatic CLI updates
- `auto_update_interval_days`: Update check interval
- `llm_executable_path`: Path to llm executable
