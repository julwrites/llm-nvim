# Task: Add Embeddings Support

## Task Information
- **Task ID**: CRITICAL-004
- **Status**: pending
- **Priority**: High (P1)
- **Phase**: 5
- **Effort Estimate**: 10 days
- **Dependencies**: None

## Task Details
### Description
The `llm` CLI provides a comprehensive suite of tools for working with embeddings, including creating embeddings, finding similar items, and managing collections. This feature set is entirely missing from the `llm-nvim` plugin. This task is to implement a user interface and the underlying logic to expose the `llm` CLI's embedding functionality within Neovim.

### Architecture Components Affected
- `lua/llm/commands.lua`: New commands will be needed to handle embedding operations.
- `lua/llm/api.lua`: New functions will be needed to interact with the `llm` CLI's embedding commands.
- `lua/llm/ui/unified_manager.lua`: A new view will be needed in the unified manager to display and manage embeddings and collections.
- `lua/llm/ui/views/`: A new view module, `embeddings_view.lua`, will need to be created.
- `lua/llm/managers/`: A new manager, `embeddings_manager.lua`, will need to be created to handle the business logic of embeddings.

### Acceptance Criteria
- [ ] Users can create embeddings from the current buffer or a selection using a new `:LLMEmbed` command.
- [ ] Users can view a list of their embedding collections in a new "Embeddings" view in the `:LLMConfig` manager.
- [ ] Users can find items similar to the current buffer or selection using a new `:LLMSimilar` command.
- [ ] The embeddings view allows users to browse, search, and delete collections and embeddings.
- [ ] The implementation is well-tested with a new `tests/spec/embeddings_spec.lua` test file.

### Implementation Notes
- The `embeddings_manager.lua` should encapsulate all calls to `llm embed`, `llm embed-multi`, `llm similar`, `llm collections`, and `llm embed-models`.
- The new UI view should be integrated into the existing `unified_manager.lua` and should follow the same design patterns as the other views.
- The `:LLMEmbed` and `:LLMSimilar` commands should be asynchronous and should display their results in a new buffer.

## Implementation Status
- **Completed Work**: None
- **Current Blockers**: None
- **Remaining Work**:
  - Implement `embeddings_manager.lua`
  - Implement `embeddings_view.lua`
  - Implement `:LLMEmbed` and `:LLMSimilar` commands
  - Write tests for all new functionality

## Git History
- *No commits yet*

---
*Created: 2025-11-14*
*Last updated: 2025-11-14*
