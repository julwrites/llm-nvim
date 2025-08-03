# LLM Command Streaming Implementation

This document outlines the plan to extend streaming functionality to all `llm` commands, building upon the existing interactive chat implementation.

## Current Status
- `llm.api.lua`: `run_llm_command_streamed` handles streaming output to a buffer using `llm.core.utils.job.lua`.
- `llm.commands.lua`:
    - `M.prompt` (for `:LLM {prompt}`)
    - `M.prompt_with_current_file` (for `:LLM file [{prompt}]` and `:LLM explain`)
    - `M.prompt_with_selection` (for `:LLM selection [{prompt}]`)
    - `M.interactive_prompt_with_fragments` (for `:LLM fragments`)
  These functions already utilize `api.run_llm_command_streamed` and `vim.fn.jobsend`.

## Plan

1.  **Review `llm.init.lua`**:
    *   Understand how all `:LLM` commands are registered.
    *   Identify any missing links or incorrect command definitions that might prevent streaming.

2.  **Investigate `:LLM schema` and `:LLM template`**:
    *   Locate the implementation for these commands, likely within `llm.managers.schemas_manager.lua` and `llm.managers.templates_manager.lua`.
    *   Modify their execution flow to use `api.run_llm_command_streamed` for output.

3.  **Verify `llm` executable interaction**:
    *   Ensure that the `llm` executable itself is configured to stream its output for all relevant commands. (This is an assumption for now, based on chat working).

4.  **Test and Refine**:
    *   After implementing changes for each command, test thoroughly to ensure streaming works as expected and output is correctly displayed in the target buffer.
    *   Address any issues with buffer management, prompt handling, or job lifecycle.

## Addressing Input Context for `llm` Commands

**Problem**: Commands are currently sending a newly created streaming buffer as input to the `llm` executable, instead of the intended file path or selected text. This results in incorrect context being provided to the LLM.

**Goal**: Ensure that `llm` commands correctly identify and pass either the current file's path (as a fragment) or the visually selected text as input to the `llm` executable.

**Tasks**:

1.  **Identify where input context is determined**:
    *   Locate the code responsible for preparing the input to the `llm` executable for commands like `:LLM file`, `:LLM selection`, and `:LLM explain`. This is likely within `llm.commands.lua` or related utility functions.

2.  **Modify input preparation logic**:
    *   For `:LLM file`:
        *   Ensure the absolute path of the currently focused file is retrieved.
        *   Pass this path to the `llm` executable using the `-f` flag (e.g., `llm -f <filepath> -s <prompt>`).
        *   Verify that the file content is not being streamed directly as standard input unless explicitly intended.
    *   For `:LLM selection`:
        *   Ensure the visually selected text is correctly captured.
        *   Pass this text to the `llm` executable as part of the prompt or via standard input, as appropriate (e.g., `llm -s <selected text + prompt>`).
        *   Avoid creating a new buffer solely for streaming the selected text if it can be passed directly.
    *   For `:LLM explain`:
        *   Confirm that this command correctly uses the current file's path as a fragment, similar to `:LLM file`.

3.  **Update `llm` executable command construction**:
    *   Review the `llm` command construction (e.g., in `llm.core.utils.shell.lua` or `llm.api.lua`) to ensure it correctly incorporates the `-f` or `-s` flags and their respective arguments.

## Detailed Steps for Each Command

### `:LLM {prompt}`
- **Status**: **COMPLETED**. Core streaming logic is in place via `M.prompt`.
- **Action**: Verify command registration in `llm.init.lua` and ensure the prompt is correctly passed to `M.prompt`.

### `:LLM file [{prompt}]`
- **Status**: **COMPLETED**. Core streaming logic is in place via `M.prompt_with_current_file`.
- **Action**:
    *   Verify command registration in `llm.init.lua`.
    *   **COMPLETED**: Ensure the absolute path of the current file is correctly identified and passed to the `llm` executable using the `-f` flag, and that the file content itself is *not* being streamed as a new buffer.
    *   Ensure optional prompt is correctly handled.

### `:LLM selection [{prompt}]`
- **Status**: **COMPLETED**. Core streaming logic is in place via `M.prompt_with_selection`.
- **Action**:
    *   Verify command registration in `llm.init.lua`.
    *   **COMPLETED**: Ensure the visually selected text is correctly captured and passed to the `llm` executable as part of the prompt or via standard input, and that a new buffer is *not* being created solely for this purpose.
    *   Ensure optional prompt is correctly handled.

### `:LLM explain`
- **Status**: **COMPLETED**. Handled by `M.prompt_with_current_file`.
- **Action**:
    *   Verify command registration in `llm.init.lua`.
    *   **COMPLETED**: Confirm that the current file's path is correctly used as a fragment for the `llm` executable, similar to `:LLM file`.

### `:LLM fragments`
- **Status**: **COMPLETED**. `M.interactive_prompt_with_fragments` eventually calls `M.prompt`.
- **Action**: Verified the flow from interactive selection to `M.prompt` ensures streaming and that the selected fragment's content is correctly passed as input to the `llm` executable.

### `:LLM schema`
- **Status**: **COMPLETED**. Modified `llm.managers.schemas_manager.lua` to use `api.run_llm_command_streamed`.
- **Action**: No further action required.

### `:LLM template`
- **Status**: **COMPLETED**. Core streaming logic is in place via `llm.managers.templates_manager.lua`.
- **Action**: No further action required.

## Plugin Manager Fix
- **Status**: **COMPLETED**. Modified `llm.managers.plugins_manager.lua` to correctly parse installed plugins by requesting JSON output from `llm plugins --json`.
- **Action**: No further action required.

## Plugin Manager Cache Invalidation Fix
- **Status**: **COMPLETED**. Modified `M.refresh_available_plugins` in `lua/llm/managers/plugins_manager.lua` to invalidate both `available_plugins` and `installed_plugins` caches.
- **Action**: No further action required.

## Plugin Manager JSON Parsing Fix
- **Status**: **COMPLETED**. Reverted `string.gmatch` and added `trim` function to `plugins_output` before `vim.fn.json_decode` in `M.get_installed_plugins`. Also added newline removal.
- **Action**: No further action required.

## Plugin Manager Unfinished String Fix
- **Status**: **COMPLETED**. Removed problematic debug notification line from `plugins_manager.lua`.
- **Action**: No further action required.