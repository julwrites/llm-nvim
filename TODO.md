# Comprehensive Test Plan for llm-nvim

This document outlines the necessary tests to ensure the quality and stability of the `llm-nvim` plugin. The tests are categorized by module and functionality, with explicit tests for each function.

## Testing Framework and Dependencies

To implement these tests, the following tools are required:

*   **Test Framework:** [busted](https://github.com/Olivine-Labs/busted) is a popular and robust testing framework for Lua. It supports Arrange-Act-Assert (AAA) patterns and provides a rich set of assertion functions. Integration with Neovim can be achieved using [plenary-busted](https://github.com/nvim-lua/plenary.nvim).
*   **Mocks:** A mocking library is essential for isolating components and simulating external dependencies, especially the `llm` command-line tool and Neovim's UI functions. We can use a simple table-based mocking strategy or a more feature-rich library like [luassert](https://github.com/Olivine-Labs/luassert) which has mocking capabilities.
*   **Test Data:** A dedicated `test_data` directory should be created to store mock responses from the `llm` CLI (in JSON format), sample configuration files, and other test-related data.

## Test Plan by Module

### `lua/llm/`

#### `init.lua`

*   **Test:** `M.setup()`
    *   **Status:** ✅ Implemented
    *   **Description:** Verify the main setup function initializes the configuration, styles, loaders, and auto-update mechanism correctly.
    *   **Expected Behavior:** `config.setup`, `styles.setup_highlights`, `loaders.load_all`, and `shell.update_llm_cli` should be called under the correct conditions.
    *   **Test Implementation:** Mock the required modules (`config`, `styles`, `loaders`, `shell`). Call `M.setup` with various options (e.g., `auto_update_cli = true/false`) and assert that the mocked functions are called with the expected arguments.

#### `api.lua`

*   **Test:** `M.setup()`
    *   **Status:** ✅ Implemented
    *   **Description:** Ensure the API's setup function correctly calls the configuration setup.
    *   **Expected Behavior:** `config.setup` should be called with the provided options.
    *   **Test Implementation:** Mock `require('llm.config').setup` and assert that it is called when `M.setup` is invoked.
*   **Test:** `M.version()`
    *   **Omission Justification:** This is a one-line function that returns a value from another module. It will be implicitly tested via the tests for the `config` module.
*   **Test:** All facade functions (`get_manager`, `command`, `prompt`, etc.)
    *   **Status:** ✅ Implemented
    *   **Description:** Verify that all functions from the `facade` module are correctly exposed through the `api` module via a loop.
    *   **Expected Behavior:** Calling a function on the `api` module should call the corresponding function on the `facade` module.
    *   **Test Implementation:** Mock the `facade` module. Iterate through its functions, call them via the `api` module, and assert that the corresponding mock in the `facade` was called.

#### `commands.lua`

*   **Test:** `M.get_model_arg()`
    *   **Status:** ✅ Implemented
    *   **Description:** Test that it correctly constructs the model argument for the CLI command.
    *   **Expected Behavior:** Should return `{"-m", "model_name"}` if a model is set in the config, otherwise an empty table.
    *   **Test Implementation:** Mock `config.get`. Call the function with and without a model set and assert the returned table.
*   **Test:** `M.get_system_arg()`
    *   **Status:** ✅ Implemented
    *   **Description:** Test that it correctly constructs the system prompt argument.
    *   **Expected Behavior:** Should return `{"-s", "prompt"}` if a system prompt is set, otherwise an empty table.
    *   **Test Implementation:** Mock `config.get`. Call the function with and without a system prompt set and assert the returned table.
*   **Test:** `M.get_fragment_args()`
    *   **Status:** ✅ Implemented
    *   **Description:** Test that it correctly constructs the fragment arguments.
    *   **Expected Behavior:** Should return a table of `"-f", "fragment_path"` pairs.
    *   **Test Implementation:** Pass a list of fragment paths and assert the structure and content of the returned table.
*   **Test:** `M.get_system_fragment_args()`
    *   **Status:** ✅ Implemented
    *   **Description:** Test that it correctly constructs the system fragment arguments.
    *   **Expected Behavior:** Should return a table of `"--system-fragment", "fragment_path"` pairs.
    *   **Test Implementation:** Pass a list of fragment paths and assert the structure and content of the returned table.
*   **Test:** `M.get_pre_response_message()`
    *   **Status:** ✅ Implemented
    *   **Description:** Verify that the pre-response message is formatted correctly.
    *   **Expected Behavior:** Should return a formatted string containing the source, prompt, and fragments.
    *   **Test Implementation:** Call the function with sample data and assert the returned string is formatted as expected.
*   **Test:** `M.create_response_buffer()`
    *   **Status:** ✅ Implemented
    *   **Description:** Test the creation of the response buffer.
    *   **Expected Behavior:** `ui.create_buffer_with_content` should be called.
    *   **Test Implementation:** Mock `ui.create_buffer_with_content` and assert it's called with the correct arguments.
*   **Test:** `M.fill_response_buffer()`
    *   **Status:** ✅ Implemented
    *   **Description:** Test filling the response buffer and applying syntax.
    *   **Expected Behavior:** `ui.replace_buffer_with_content` should be called, and `vim.cmd` should be called for syntax highlighting.
    *   **Test Implementation:** Mock `ui.replace_buffer_with_content` and `vim.cmd`. Assert they are called correctly.
*   **Test:** `M.write_context_to_temp_file()`
    *   **Status:** ✅ Implemented
    *   **Description:** Test writing context to a temporary file.
    *   **Expected Behavior:** A temporary file should be created and written to.
    *   **Test Implementation:** Mock `os.tmpname` and `io.open`. Call the function and assert that a file is written with the correct content.
*   **Test:** `M.llm_command_and_display_response()`
    *   **Status:** ✅ Implemented
    *   **Description:** Test the end-to-end flow of running a command and displaying the response.
    *   **Expected Behavior:** `llm_cli.run_llm_command` and `M.fill_response_buffer` should be called.
    *   **Test Implementation:** Mock the required functions and assert they are called in the correct order.
*   **Test:** `M.dispatch_command()`
    *   **Status:** ✅ Implemented
    *   **Description:** Test the command dispatcher.
    *   **Expected Behavior:** It should call the correct command function based on the subcommand.
    *   **Test Implementation:** Call with different subcommands (`selection`, `toggle`, etc.) and assert that the correct underlying function is called.
*   **Test:** `M.prompt()`
    *   **Status:** ✅ Implemented
    *   **Description:** Test the main prompt command execution.
    *   **Expected Behavior:** It should construct the full `llm` command string and call the CLI wrapper.
    *   **Test Implementation:** Mock `llm_cli.run_llm_command` and `M.create_response_buffer`. Call `M.prompt` and assert that the CLI is called with the correctly assembled command string.
*   **Test:** `M.explain_code()`
    *   **Status:** ✅ Implemented
    *   **Description:** Verify it calls `prompt_with_current_file` with the correct explanation prompt.
    *   **Expected Behavior:** `M.prompt_with_current_file` should be called with `"Explain this code"`.
    *   **Test Implementation:** Mock `M.prompt_with_current_file` and assert it's called with the correct arguments.
*   **Test:** `M.prompt_with_current_file()`
    *   **Status:** ✅ Implemented
    *   **Description:** Test the command that uses the current file as context.
    *   **Expected Behavior:** It should get the file path and call `execute_prompt_async`.
    *   **Test Implementation:** Mock `vim.api.nvim_buf_get_name` and `M.execute_prompt_async`. Assert that `execute_prompt_async` is called with the correct file path.
*   **Test:** `M.prompt_with_selection()`
    *   **Status:** ✅ Implemented
    *   **Description:** Test the command that uses a visual selection as context.
    *   **Expected Behavior:** It should get the selection, write it to a temp file, and call `execute_prompt_async`.
    *   **Test Implementation:** Mock `text.get_visual_selection`, `M.write_context_to_temp_file`, and `M.execute_prompt_async`. Assert that `execute_prompt_async` is called correctly.
*   **Test:** `M.execute_prompt_async()`
    *   **Status:** ✅ Implemented
    *   **Description:** Test the asynchronous prompt execution flow.
    *   **Expected Behavior:** It should show a floating input if no prompt is provided, then call `execute_prompt_with_file`.
    *   **Test Implementation:** Mock `ui.floating_input` and `M.execute_prompt_with_file`. Test both with and without a prompt provided.
*   **Test:** `M.execute_prompt_with_file()`
    *   **Status:** ✅ Implemented
    *   **Description:** Test the execution of a prompt with a file path as context.
    *   **Expected Behavior:** It should construct the correct `llm` command and call `llm_command_and_display_response`.
    *   **Test Implementation:** Mock `M.llm_command_and_display_response`. Call the function and assert the command string passed to the mock is correct.
*   **Test:** `M.interactive_prompt_with_fragments()`
    *   **Status:** ⚠️ Omitted
    *   **Description:** Test the full interactive workflow for selecting fragments.
    *   **Expected Behavior:** It should guide the user via `vim.ui.select` and `vim.ui.input` and then call `M.prompt` with the collected fragments and prompt.
    *   **Test Implementation:** Mock `vim.ui.select` and `vim.ui.input` to simulate a user workflow. Mock `M.prompt` and assert it's called with the final, correct arguments.
*   **Test:** `M.test_terminal_creation()`
    *   **Omission Justification:** This is a debugging/testing function and is not part of the core plugin functionality.

#### `config.lua`

*   **Test:** `M.setup()`
    *   **Status:** ✅ Implemented
    *   **Description:** Verify that the `setup` function correctly merges user-provided options with defaults and notifies listeners.
    *   **Expected Behavior:** `M.options` should be correctly populated, and registered listener functions should be called.
    *   **Test Implementation:** Register a listener function. Call `M.setup` with custom options. Assert the values in `M.options` and assert that the listener was called.
*   **Test:** `M.get()`
    *   **Status:** ✅ Implemented
    *   **Description:** Test retrieval of single and all configuration values.
    *   **Expected Behavior:** Should return the specific value for a key, the default value if not set, or a table of all values if no key is provided.
    *   **Test Implementation:** Call `M.get("model")` and assert the result. Call `M.get()` and assert the returned table contains all expected keys.
*   **Test:** `M.on_change()`
    *   **Status:** ✅ Implemented
    *   **Description:** Verify that it correctly registers and unregisters a listener function.
    *   **Omission Justification:** This is implicitly tested by the `M.setup()` test.
*   **Test:** `M.reset()`
    *   **Status:** ✅ Implemented
    *   **Description:** Ensure the configuration is restored to its default state.
    *   **Expected Behavior:** `M.options` should match `M.defaults`.
    *   **Test Implementation:** Set a custom config, call `M.reset()`, and then assert that `M.get()` returns the default value.

#### `errors.lua`

*   **Test:** `M.handle()`
    *   **Status:** ✅ Implemented
    *   **Description:** Verify error formatting and notification.
    *   **Expected Behavior:** `vim.notify` should be called with a correctly formatted message.
    *   **Test Implementation:** Mock `vim.notify`. Call `M.handle` and assert `vim.notify` was called with the expected string.
*   **Test:** `M.wrap()`
    *   **Status:** ✅ Implemented
    *   **Description:** Test the `pcall` wrapper for functions.
    *   **Expected Behavior:** It should return the function's result on success and call `M.handle` on failure.
    *   **Test Implementation:** Wrap a function that succeeds and assert the result. Wrap a function that errors and assert that `M.handle` is called.
*   **Test:** `M.shell_error()`
    *   **Status:** ✅ Implemented
    *   **Description:** Test the specific handler for shell command errors.
    *   **Expected Behavior:** It should call `M.handle` with a formatted shell error message.
    *   **Test Implementation:** Mock `M.handle`. Call `M.shell_error` and assert that `M.handle` was called with the expected arguments.

#### `facade.lua`

*   **Test:** `M.get_manager()`
    *   **Description:** Test the lazy loading of manager modules.
    *   **Expected Behavior:** It should `require` a manager module only once.
    *   **Test Implementation:** Mock `require`. Call `M.get_manager("models")` twice. Assert that `require` was only called once for `'llm.managers.models_manager'`.
*   **Test:** `M.command()`, `M.prompt()`, `M.prompt_with_selection()`, `M.prompt_with_current_file()`, `M.toggle_unified_manager()`
    *   **Omission Justification:** These are simple one-line passthrough functions. Testing them would be redundant as the target functions in `commands.lua` and `unified_manager.lua` are already tested.

### `lua/llm/core/`

#### `data/cache.lua`

*   **Test:** `M.get()`, `M.set()`, `M.invalidate()`
    *   **Description:** Test the full lifecycle of a cached item.
    *   **Expected Behavior:** Data should be set, retrieved, and invalidated correctly.
    *   **Test Implementation:** Mock `io.open` and `vim.fn.json_encode/decode` to simulate file-based caching. Call `M.set("key", "value")`, then `M.get("key")` and assert the result. Call `M.invalidate("key")` and assert `M.get("key")` returns `nil`.

#### `data/llm_cli.lua`

*   **Test:** `M.run_llm_command()`
    *   **Description:** Ensure it prepends "llm " to the command and calls the shell wrapper.
    *   **Expected Behavior:** `shell.safe_shell_command` should be called with the correct full command string.
    *   **Test Implementation:** Mock `require('llm.core.utils.shell').safe_shell_command`. Call `M.run_llm_command("models list")` and assert the mock was called with `"llm models list"`.

#### `loaders.lua`

*   **Test:** `M.load_models()`, `M.load_available_plugins()`, `M.load_keys()`, `M.load_fragments()`, `M.load_templates()`, `M.load_schemas()`
    *   **Description:** For each `load_*` function, verify that it calls the correct CLI command and correctly parses the text-based output.
    *   **Expected Behavior:** Each function should call `llm_cli.run_llm_command` with the appropriate subcommand and then call `cache.set` with the correctly parsed data structure.
    *   **Test Implementation:** For each function, mock `llm_cli.run_llm_command` to return a sample multi-line string (as seen in the codebase). Mock `cache.set`. Call the function and assert that `cache.set` was called with a Lua table that matches the expected structure.
*   **Test:** `M.load_all()`
    *   **Description:** Ensure it calls all individual loader functions.
    *   **Expected Behavior:** All `M.load_*` functions in the module should be called.
    *   **Test Implementation:** Mock all `M.load_*` functions. Call `M.load_all()` and assert that each mock was called once.

#### `utils/file_utils.lua`

*   **Test:** `M.ensure_config_dir_exists()`
    *   **Description:** Verify the logic for ensuring a directory exists.
    *   **Expected Behavior:** It should correctly determine if a directory is writable and attempt to create it if not.
    *   **Test Implementation:** Mock the internal functions `test_directory_writable` and `create_directory` to simulate different scenarios (directory exists, does not exist, creation fails) and assert the function's return value.
*   **Test:** `M.get_config_path()`
    *   **Description:** Test the resolution of the configuration file path.
    *   **Expected Behavior:** It should correctly construct the path from the `llm` logs path and cache the result.
    *   **Test Implementation:** Mock `shell.safe_shell_command` and `M.ensure_config_dir_exists`. Call the function and assert the returned path. Call it again and assert the shell command was not re-run.

#### `utils/notify.lua`

*   **Test:** `M.notify()`
    *   **Description:** Test the simple wrapper around `vim.notify`.
    *   **Expected Behavior:** `vim.notify` should be called with the exact arguments passed to `M.notify`.
    *   **Test Implementation:** Mock `vim.notify`. Call `M.notify` with a message, level, and options table, and assert the mock was called with those same arguments.

#### `utils/shell.lua`

*   **Test:** `M.safe_shell_command()`
    *   **Description:** Test the safe execution of a shell command.
    *   **Expected Behavior:** It should call `vim.fn.system` and return the trimmed result.
    *   **Test Implementation:** Mock `vim.fn.system`. Call `M.safe_shell_command` and assert the result is correctly trimmed. Test with `nil` and empty string returns.
*   **Test:** `M.command_exists()`
    *   **Description:** Test the check for a command's existence in the system's PATH.
    *   **Expected Behavior:** Should return `true` if `os.execute` returns 0, `false` otherwise.
    *   **Test Implementation:** Mock `os.execute`. Call `M.command_exists` and assert the return value is correct for different mock return values from `os.execute`.
*   **Test:** `M.check_llm_installed()`
    *   **Description:** Verify it calls `M.command_exists` with "llm".
    *   **Omission Justification:** This is a simple passthrough to `M.command_exists`, which is already tested.
*   **Test:** `M.execute()`
    *   **Description:** Test the execution of a command via `io.popen`.
    *   **Expected Behavior:** It should correctly read the output from the command.
    *   **Test Implementation:** Mock `io.popen` and its `read`/`close` methods. Call `M.execute` and assert that it returns the expected output from the mock.
*   **Test:** `M.get_last_update_timestamp()` and `M.set_last_update_timestamp()`
    *   **Description:** Test reading and writing the update timestamp file.
    *   **Expected Behavior:** The functions should correctly read from and write to the `last_update_check.txt` file.
    *   **Test Implementation:** Mock `io.open` to simulate file operations. Test writing a timestamp, then reading it back.
*   **Test:** `M.run_update_command()`
    *   **Description:** Test the wrapper around `vim.fn.system` for updates.
    *   **Omission Justification:** This is a thin wrapper around `vim.fn.system`, which is already mocked and tested in `safe_shell_command`.
*   **Test:** `M.update_llm_cli()`
    *   **Description:** Test the sequential logic for trying different CLI update methods.
    *   **Expected Behavior:** It should attempt to update using `uv`, `pipx`, `pip`, etc., in order, stopping at the first success.
    *   **Test Implementation:** Mock `M.command_exists` and `M.run_update_command`. Create several test cases where a different update method is the first to succeed, and assert that the correct commands were attempted in the correct order.

#### `utils/text.lua`

*   **Test:** `M.get_visual_selection()`
    *   **Description:** Test the extraction of text from a visual selection.
    *   **Expected Behavior:** It should correctly handle single-line and multi-line selections.
    *   **Test Implementation:** Mock `vim.fn.getpos` to return different start/end coordinates. Mock `vim.api.nvim_buf_get_lines` to provide sample buffer content. Assert the returned string is correct for both single-line and multi-line cases.
*   **Test:** `M.capitalize()`
    *   **Description:** Test string capitalization.
    *   **Expected Behavior:** The first letter should be capitalized.
    *   **Test Implementation:** Pass various strings (`"test"`, `"Test"`, `"1test"`, `""`) and assert the output.
*   **Test:** `M.escape_pattern()`
    *   **Description:** Test escaping of Lua pattern special characters.
    *   **Expected Behavior:** Characters like `(`, `)`, `.` should be prepended with `%`.
    *   **Test Implementation:** Pass a string with special characters and assert the output is correctly escaped.
*   **Test:** `M.parse_simple_yaml()`
    *   **Description:** Test the simple YAML parser.
    *   **Expected Behavior:** Should correctly parse a string with nested keys and lists into a Lua table.
    *   **Test Implementation:** Mock `io.open` to return a sample YAML string. Call the function and assert that the returned Lua table has the expected nested structure and values.

#### `utils/ui.lua`

*   **Test:** `M.create_split_buffer()`
    *   **Description:** Test the creation of a new buffer in a split.
    *   **Expected Behavior:** `vim.api.nvim_create_buf` and `vim.api.nvim_open_win` should be called.
    *   **Test Implementation:** Mock the two `vim.api` functions and assert they are called.
*   **Test:** `M.create_buffer_with_content()` and `M.replace_buffer_with_content()`
    *   **Description:** Test creating and replacing buffer content.
    *   **Expected Behavior:** They should call the correct sequence of `vim.api` buffer functions.
    *   **Test Implementation:** Mock the relevant `vim.api` functions (`nvim_create_buf`, `nvim_buf_set_option`, `nvim_buf_set_lines`, etc.). Call the functions and assert the mocks were called with the correct arguments.
*   **Test:** `M.create_floating_window()`
    *   **Description:** Test floating window creation.
    *   **Expected Behavior:** Should call `vim.api.nvim_open_win` with a specific floating window configuration.
    *   **Test Implementation:** Mock `vim.api.nvim_open_win`. Call the function and assert that the configuration table passed to the mock contains `relative = 'editor'` and `border = 'rounded'`.
*   **Test:** `M.floating_input()`
    *   **Description:** Test the floating input dialog.
    *   **Expected Behavior:** It should create a window and buffer, set up keymaps, and trigger a callback on confirmation.
    *   **Test Implementation:** Mock `vim.api` functions. Call `M.floating_input` with a callback. Simulate confirmation by calling `M._confirm_floating_input()` and assert the original callback was called with the correct input.
*   **Test:** `M.floating_confirm()`
    *   **Description:** Test the floating confirmation dialog.
    *   **Expected Behavior:** Similar to `floating_input`, it should create a UI and trigger a callback.
    *   **Test Implementation:** Mock `vim.api` functions. Call `M.floating_confirm` with a callback. Simulate confirmation by calling `M._confirm_floating_dialog(true)` and assert the original callback was called.

#### `utils/validate.lua`

*   **Test:** `M.convert()`
    *   **Description:** Test type conversion for config values.
    *   **Expected Behavior:** Should correctly convert between string, boolean, and number types.
    *   **Test Implementation:** Call `M.convert` with various inputs (e.g., `"true"`, `"123"`, `false`, `0`) and target types (`"boolean"`, `"number"`, `"string"`) and assert the output has the correct type and value.
*   **Test:** `M.validate()`
    *   **Description:** Test the type validation function.
    *   **Expected Behavior:** Should return `true` if the value's type matches the expectation, `false` otherwise.
    *   **Test Implementation:** Call `M.validate` with various values and type strings and assert the boolean result.

### `lua/llm/managers/`

*   **Omission Justification for all manager files:** The tests for the manager modules are highly dependent on the UI and view files, which are difficult to test in a unit testing environment. The core logic of the managers is to orchestrate calls to the `llm` CLI and the UI. The CLI interactions are tested in `llm_cli.lua`, and the UI interactions are omitted for the reasons stated below. Therefore, dedicated tests for the manager files would be redundant and provide little value.

### `lua/llm/ui/`

*   **`styles.lua`**
    *   **Omission Justification:** This file contains only data (color palettes) and functions that generate `vim.cmd` strings for highlighting. It has no complex logic to test, and its effects are purely visual. Testing it would require a complex visual regression setup which is outside the scope of unit testing.
*   **`ui.lua`**
    *   **Omission Justification:** This file is a simple pass-through layer to `vim.ui` and `vim.api`. The functions it wraps are already mocked and tested in the tests for the `core/utils/ui.lua` module, making dedicated tests here redundant.
*   **`unified_manager.lua`**
    *   **Omission Justification:** This file is the core of the UI management and is heavily coupled to the Neovim API for windows, buffers, and keymaps. Unit testing this file would require extensive and brittle mocking of the Neovim API. The logic is primarily concerned with orchestrating the display of different views, which is better suited for end-to-end or integration testing.

### `lua/llm/ui/views/`

*   **Omission Justification for all view files:** The files in this directory (`fragments_view.lua`, `keys_view.lua`, etc.) consist almost entirely of wrappers around `vim.ui.input` and `vim.ui.select`. Their logic is trivial and is implicitly covered by the tests for the manager modules that would use them. For example, testing `keys_manager.set_key_under_cursor` would involve mocking `vim.ui.input`, which is what `keys_view.get_api_key` wraps. This makes dedicated tests for the view functions redundant.
