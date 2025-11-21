# Task: Add Multi-modal Attachments Support

## Task Information
- **Task ID**: CRITICAL-006
- **Status**: pending

### Investigation Summary (2025-11-16)
This task was verified as **Not Implemented**.
- The `:LLM` command in `lua/llm/commands.lua` does not handle an `--attach` or `-a` flag.

- **Priority**: Medium (P2)
- **Phase**: 6
- **Effort Estimate**: 5 days
- **Dependencies**: None

## Task Details
### Description
The `llm` CLI can process images, audio, and video files as attachments to a prompt. The `llm-nvim` plugin is currently limited to text-based inputs. This task is to add support for attaching multi-modal files to prompts.

### Architecture Components Affected
- `lua/llm/commands.lua`: The `:LLM` command will need to be updated to accept file paths as attachments.
- `lua/llm/api.lua`: The command-building functions will need to be updated to include the attachment arguments.

### Acceptance Criteria
- [ ] Users can attach image, audio, and video files to a prompt using the `:LLM` command.
- [ ] The plugin correctly passes the attachment paths to the `llm` CLI.
- [ ] The implementation is well-tested.

### Implementation Notes
- The `:LLM` command could be updated to accept a new `-a` or `--attach` flag, followed by a file path.
- The implementation should focus on passing the file path to the CLI. The CLI handles the actual processing of the file.

## Implementation Status
- **Completed Work**: None
- **Current Blockers**: None
- **Remaining Work**:
  - Update the `:LLM` command to accept attachments
  - Write tests for the new functionality

## Git History
- *No commits yet*

---
*Created: 2025-11-14*
*Last updated: 2025-11-14*
