# Comprehensive Test Plan for llm-nvim

This document outlines the necessary tests to ensure the quality and stability of the `llm-nvim` plugin. The tests are categorized by module and functionality.

## Testing Framework and Dependencies

To implement these tests, the following tools are required:

*   **Test Framework:** [busted](httpshttps://github.com/Olivine-Labs/busted) is a popular and robust testing framework for Lua. It supports Arrange-Act-Assert (AAA) patterns and provides a rich set of assertion functions. Integration with Neovim can be achieved using [plenary-busted](https://github.com/nvim-lua/plenary.nvim).
*   **Mocks:** A mocking library is essential for isolating components and simulating external dependencies, especially the `llm` command-line tool and Neovim's UI functions. We can use a simple table-based mocking strategy or a more feature-rich library like [luassert](https://github.com/Olivine-Labs/luassert) which has mocking capabilities. For this plan, we'll assume a custom mocking implementation for simplicity.
*   **Test Data:** A dedicated `test_data` directory should be created to store mock responses from the `llm` CLI (in JSON format), sample configuration files, and other test-related data.

## Test Plan by Module

### Common Functionality (`lua/llm/`)

This section covers the core, non-manager-specific modules.

#### `config.lua`

*   **Test:** `setup()` function.
    *   **Description:** Verify that the `setup` function correctly merges user-provided options with the default configuration.
    *   **Expected Behavior:** The `M.options` table should contain the merged configuration.
    *   **Test Implementation:** Call `setup` with a sample configuration table and assert that the values in `M.options` are as expected.
*   **Test:** `get()` function.
    *   **Description:** Test the `get` function's ability to retrieve configuration values.
    *   **Expected Behavior:** It should return the correct value for a given key, or the default value if not set by the user.
    *   **Test Implementation:** After setting up the configuration, call `get` for various keys and assert the returned values.
*   **Test:** `reset()` function.
    *   **Description:** Ensure that the `reset` function restores the configuration to its default state.
    *   **Expected Behavior:** `M.options` should be identical to `M.defaults`.
    *   **Test Implementation:** Call `setup` with custom values, then call `reset` and assert that `M.options` matches the defaults.

#### `errors.lua`

*   **Test:** `handle()` function.
    *   **Description:** Verify that the `handle` function formats and reports errors correctly.
    *   **Expected Behavior:** It should call `vim.notify` with the expected formatted message and severity level.
    *   **Test Implementation:** Mock `vim.notify` and call `handle` with different categories, messages, and severities. Assert that `vim.notify` was called with the correct arguments.

#### `loaders.lua`

*   **Test:** Each `load_*` function (e.g., `load_models`, `load_keys`).
    *   **Description:** Test that each loader function correctly parses the mock `llm` CLI output and stores the data in the cache.
    *   **Expected Behavior:** The cache should be populated with the correctly structured data.
    *   **Test Implementation:** Mock `llm.core.data.llm_cli.run_llm_command` to return sample JSON output. Call the loader function and then use `cache.get` to assert the stored data's structure and content.

### Core Functionality (`lua/llm/core/`)

This section covers the low-level data and utility modules.

#### Data Modules (`lua/llm/core/data/`)

*   **`cache.lua`**
    *   **Test:** `set()` and `get()`.
        *   **Description:** Verify that data can be stored and retrieved from the cache.
        *   **Expected Behavior:** `get` should return the same data that was `set`.
        *   **Test Implementation:** Set a value with a key, then get it and assert they are equal.
    *   **Test:** `invalidate()`.
        *   **Description:** Test that a cache key can be invalidated.
        *   **Expected Behavior:** After invalidating a key, `get` should return `nil`.
        *   **Test Implementation:** Set a value, invalidate its key, then get it and assert the result is `nil`.
*   **`llm_cli.lua`**
    *   **Test:** `run_llm_command()`.
        *   **Description:** Ensure it correctly constructs and executes the shell command.
        *   **Expected Behavior:** `vim.fn.system` should be called with the correct `llm` command string.
        *   **Test Implementation:** Mock `vim.fn.system` and call `run_llm_command` with a sample command. Assert that the mock was called with the expected string.

#### Utility Modules (`lua/llm/core/utils/`)

*   **`file_utils.lua`**
    *   **Test:** `ensure_config_dir_exists()`
        *   **Description:** Verify that it correctly checks for and creates the configuration directory.
        *   **Expected Behavior:** It should return `true` if the directory exists or was created successfully. It should handle non-writable paths gracefully.
        *   **Test Implementation:** Mock internal functions `test_directory_writable` and `create_directory`. Test the case where the directory exists and the case where it needs to be created.
    *   **Test:** `get_config_path()`
        *   **Description:** Test the logic for resolving the path to a configuration file.
        *   **Expected Behavior:** It should correctly resolve and return the full path to a config file. It should use the cache after the first resolution.
        *   **Test Implementation:** Mock `shell.safe_shell_command` to return a fake `llm` logs path. Assert that the function returns the expected config path. Call it a second time and assert that the shell command is not called again (cache hit).

*   **`notify.lua`**
    *   **Test:** `notify()`
        *   **Description:** Test the notification wrapper.
        *   **Expected Behavior:** It should call `vim.notify` with the correct message, level, and options.
        *   **Test Implementation:** Mock `vim.notify` and call the function with different parameters. Assert that the mock was called with the expected arguments.

*   **`shell.lua`**
    *   **Test:** `safe_shell_command()`
        *   **Description:** Verify it executes a shell command and handles its output.
        *   **Expected Behavior:** It should return the command's output. It should handle `nil` or empty results correctly.
        *   **Test Implementation:** Mock `vim.fn.system` to return various outputs (a string, an empty string, `nil`) and assert the function's return value.
    *   **Test:** `command_exists()`
        *   **Description:** Test the check for an executable's existence.
        *   **Expected Behavior:** Return `true` if the command exists, `false` otherwise.
        *   **Test Implementation:** Mock `os.execute` to return `0` and `1` and assert the function's return value.
    *   **Test:** `update_llm_cli()`
        *   **Description:** Test the logic for attempting to update the `llm` CLI.
        *   **Expected Behavior:** It should try different update methods (`uv`, `pipx`, `pip`, `brew`) in order and stop on the first success.
        *   **Test Implementation:** Mock `M.command_exists` and `M.run_update_command`. In separate tests, have different mocks succeed to ensure the logic flows correctly. For example, make `uv` fail but `pipx` succeed, and assert that the correct commands were attempted.

*   **`text.lua`**
    *   **Test:** `get_visual_selection()`
        *   **Description:** Test the retrieval of text from a visual selection.
        *   **Expected Behavior:** It should correctly extract the selected text, handling single-line and multi-line selections.
        *   **Test Implementation:** Mock `vim.fn.getpos` to define start and end positions. Mock `vim.api.nvim_buf_get_lines` to provide sample buffer lines. Test with a single-line selection and a multi-line selection and assert the returned string is correct.
    *   **Test:** `capitalize()`
        *   **Description:** Test the capitalization of a string.
        *   **Expected Behavior:** The first letter of the string should be capitalized.
        *   **Test Implementation:** Pass various strings (e.g., `"hello"`, `"Hello"`, `"123"`, `""`) and assert the output.
    *   **Test:** `escape_pattern()`
        *   **Description:** Test the escaping of special Lua pattern characters.
        *   **Expected Behavior:** Special characters should be correctly escaped with a `%`.
        *   **Test Implementation:** Pass a string with special characters like `(`, `)`, `.` and assert that the output has them correctly escaped.
    *   **Test:** `parse_simple_yaml()`
        *   **Description:** Test the parsing of a simple YAML file into a Lua table.
        *   **Expected Behavior:** It should correctly parse nested maps and lists.
        *   **Test Implementation:** Mock `io.open` to return a multi-line string representing a simple YAML file. Call the function and assert that the returned Lua table has the correct structure and values.

*   **`ui.lua`**
    *   **Test:** `create_buffer_with_content()`
        *   **Description:** Test the creation of a new split buffer with content.
        *   **Expected Behavior:** It should create a new buffer, open it in a new window, and set its content.
        *   **Test Implementation:** Mock `vim.api.nvim_create_buf`, `vim.api.nvim_open_win`, and `vim.api.nvim_buf_set_lines`. Call the function and assert that the mocks were called in the correct order with the correct parameters.
    *   **Test:** `create_floating_window()`
        *   **Description:** Test the creation of a floating window.
        *   **Expected Behavior:** It should call `vim.api.nvim_open_win` with the correct configuration for a floating window.
        *   **Test Implementation:** Mock `vim.api.nvim_open_win` and assert it's called with the expected window configuration table.
    *   **Test:** `floating_input()` and `floating_confirm()`
        *   **Description:** Test the interactive floating dialogs.
        *   **Expected Behavior:** They should create a floating window and set up the correct keymaps for confirming or canceling. The callback should be triggered with the correct value.
        *   **Test Implementation:** Mock the `vim.api` functions for window/buffer creation and keymaps. Call the function, then simulate the confirmation/cancellation by calling the internal `_confirm_*` functions. Assert that the callback provided to the original function is called with the expected value.

*   **`validate.lua`**
    *   **Test:** `convert()`
        *   **Description:** Test type conversion for configuration values.
        *   **Expected Behavior:** Should correctly convert values between string, boolean, and number.
        *   **Test Implementation:** Call `convert` with various inputs (e.g., `"true"`, `"false"`, `"123"`, `1`, `0`, `true`) and target types, then assert the output's type and value are correct.
    *   **Test:** `validate()`
        *   **Description:** Test the validation of a value's type.
        *   **Expected Behavior:** It should return `true` if the value's type matches the expected type, otherwise `false`.
        *   **Test Implementation:** Call `validate` with different values and expected types and assert the boolean result.

### Managers (`lua/llm/managers/`)

For all manager tests, the `llm.core.data.llm_cli.run_llm_command` function will be mocked to simulate interactions with the `llm` CLI.

#### `models_manager.lua`

*   **Test:** `get_available_models()`.
    *   **Description:** Ensure it correctly parses the `llm models list` output.
    *   **Expected Behavior:** Returns a table of model tables with `provider`, `id`, and `name`.
    *   **Test Implementation:** Mock the CLI command to return a sample model list. Call the function and assert the structure of the returned table.
*   **Test:** `set_default_model()`.
    *   **Description:** Verify it calls the `llm models default <model_name>` command.
    *   **Expected Behavior:** The CLI mock should be called with the correct command.
    *   **Test Implementation:** Mock the CLI command, call `set_default_model`, and assert the command passed to the mock.
*   **Test:** Alias functions (`get_model_aliases`, `set_model_alias`, `remove_model_alias`).
    *   **Description:** Test that alias management functions call the correct `llm aliases` subcommands.
    *   **Expected Behavior:** The CLI mock should be called with the appropriate `aliases` subcommand and arguments.
    *   **Test Implementation:** Mock the CLI command, call the alias functions, and assert the command passed to the mock.

#### `keys_manager.lua`

*   **Test:** `get_stored_keys()`.
    *   **Description:** Ensure it parses the `llm keys list --json` output.
    *   **Expected Behavior:** Returns a table of key tables.
    *   **Test Implementation:** Mock the CLI command with sample JSON output and assert the returned table.
*   **Test:** `set_api_key()` and `remove_api_key()`.
    *   **Description:** Verify they call the correct `llm keys` subcommands.
    *   **Expected Behavior:** The CLI mock should be called with `keys set <name> <value>` or `keys remove <name>`.
    *   **Test Implementation:** Mock the CLI command and assert the command string.

#### `plugins_manager.lua`

*   **Test:** `get_installed_plugins()`.
    *   **Description:** Parses the `llm plugins` output.
    *   **Expected Behavior:** Returns a table of installed plugins.
    *   **Test Implementation:** Mock the CLI command and assert the returned table.
*   **Test:** `install_plugin()` and `uninstall_plugin()`.
    *   **Description:** Verify they call `llm install` and `llm uninstall`.
    *   **Expected Behavior:** The CLI mock should be called with the correct command.
    *   **Test Implementation:** Mock the CLI command and assert the command string.

#### `fragments_manager.lua`, `templates_manager.lua`, `schemas_manager.lua`

These managers follow a similar pattern. For each, we need to test:

*   **`get_*` functions:** Mock the corresponding `llm <type> list --json` command and assert that the output is parsed correctly.
*   **Action functions (create, delete, run, etc.):** Mock the corresponding `llm <type> <action>` command and assert that it's called with the correct arguments.
*   **Interactive functions:** Mock `vim.ui.input` and `vim.ui.select` to simulate user input and verify that the correct actions are taken based on that input.

### Commands and API (`lua/llm/commands.lua`, `lua/llm/api.lua`)

#### `commands.lua`

*   **Test:** `prompt()`.
    *   **Description:** Test the main prompt command.
    *   **Expected Behavior:** It should construct the correct `llm` command string, including model, system prompt, and fragments, and then call the CLI mock.
    *   **Test Implementation:** Set config values, call `prompt` with a prompt and fragments, and assert the command string passed to the CLI mock.
*   **Test:** `prompt_with_selection()` and `prompt_with_current_file()`.
    *   **Description:** Test the commands that use context from the editor.
    *   **Expected Behavior:** They should correctly get the selection/file content, write it to a temporary file, and include that file as a fragment in the `llm` command.
    *   **Test Implementation:** Mock `text.get_visual_selection()` and `vim.api.nvim_buf_get_name()`. Mock file I/O to verify the temporary file is created and its path is passed to the CLI mock.
*   **Test:** `interactive_prompt_with_fragments()`.
    *   **Description:** Test the interactive fragment selection process.
    *   **Expected Behavior:** It should guide the user through fragment selection and then construct the final `llm` command.
    *   **Test Implementation:** Mock `vim.ui.select` and `vim.ui.input` to simulate a user selecting multiple fragments and entering a prompt. Assert the final command string.

#### `api.lua`

*   **Test:** `setup()`.
    *   **Description:** Ensure the API's `setup` function calls the config setup.
    *   **Expected Behavior:** `config.setup` should be called with the provided options.
    *   **Test Implementation:** Mock `require('llm.config').setup` and assert that it's called.
*   **Test:** Facade functions.
    *   **Description:** Verify that all functions from the facade are exposed through the API.
    *   **Expected Behavior:** Calling an API function (e.g., `api.prompt()`) should call the corresponding facade function.
    *   **Test Implementation:** Mock the facade functions, call the API functions, and assert that the mocks were called.

This test plan provides a comprehensive roadmap for ensuring the quality of `llm-nvim`. By implementing these tests, we can catch regressions, verify new features, and maintain a high level of stability for the plugin.
