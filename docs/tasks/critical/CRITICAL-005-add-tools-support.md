# Task: Add Tools (Function Calling) Support

## Task Information
- **Task ID**: CRITICAL-005
- **Status**: pending
- **Priority**: High (P1)
- **Phase**: 5
- **Effort Estimate**: 8 days
- **Dependencies**: None

## Task Details
### Description
The `llm` CLI supports "tools", which allow the language model to execute predefined functions to retrieve information or perform actions. This is a powerful feature for creating more interactive and capable agents, and it is currently not implemented in the `llm-nvim` plugin. This task is to add support for using tools in prompts.

### Architecture Components Affected
- `lua/llm/commands.lua`: The `:LLM` command will need to be updated to support a new `-t` or `--tool` flag.
- `lua/llm/api.lua`: The command-building functions will need to be updated to include the tool arguments.
- `lua/llm/config.lua`: A new configuration option may be needed to define and register custom tools.
- `lua/llm/ui/unified_manager.lua`: A new view for managing tools could be beneficial.
- `lua/llm/ui/views/`: A `tools_view.lua` would be needed if a manager view is implemented.
- `lua/llm/managers/`: A `tools_manager.lua` would be needed to manage the tools.

### Acceptance Criteria
- [ ] Users can specify a tool to be used in a prompt with the `:LLM` command.
- [ ] The plugin correctly parses the model's response and displays the tool's output.
- [ ] A new view in the `:LLMConfig` manager allows users to view available tools.
- [ ] The implementation is well-tested with a new `tests/spec/tools_spec.lua` test file.

### Implementation Notes
- The initial implementation should focus on supporting the default tools provided by the `llm` CLI.
- A follow-up task can be created to support user-defined custom tools.
- The `tools_manager.lua` will be responsible for listing and describing the available tools.

## Implementation Status
- **Completed Work**: None
- **Current Blockers**: None
- **Remaining Work**:
  - Implement `tools_manager.lua`
  - Implement `tools_view.lua`
  - Update the `:LLM` command to support tools
  - Write tests for all new functionality

## Git History
- *No commits yet*

---
*Created: 2025-11-14*
*Last updated: 2025-11-14*
