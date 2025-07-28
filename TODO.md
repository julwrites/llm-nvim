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
    *   **Test:** `read_file()`
        *   **Description:** Test reading content from a file.
        *   **Expected Behavior:** Should return the content of a given file path. Handle errors for non-existent files.
        *   **Test Implementation:** Create a temporary file with known content, read it using the function, and assert the content matches. Test with a non-existent file path and assert it returns `nil` or an error.
    *   **Test:** `write_file()`
        *   **Description:** Test writing content to a file.
        *   **Expected Behavior:** A file should be created with the specified content.
        *   **Test Implementation:** Write to a temporary file path, then read the file to assert its content.
*   **`notify.lua`**
    *   **Test:** `notify()`
        *   **Description:** Test the notification wrapper.
        *   **Expected Behavior:** It should call `vim.notify` with the correct message, level, and title.
        *   **Test Implementation:** Mock `vim.notify` and call the function with different parameters. Assert that the mock was called with the expected arguments.
*   **`shell.lua`**
    *   **Test:** `check_llm_installed()`
        *   **Description:** Verify it correctly checks for the `llm` executable.
        *   **Expected Behavior:** Return `true` if the executable exists, `false` otherwise.
        *   **Test Implementation:** Mock `vim.fn.executable` to return `1` and `0` in different tests and assert the function's return value.
    *   **Test:** `update_llm_cli()`
        *   **Description:** Test the CLI update command.
        *   **Expected Behavior:** It should execute the `pip install --upgrade llm` command.
        *   **Test Implementation:** Mock the shell command execution and assert that the correct command string is passed.
*   **`text.lua`**
    *   **Test:** `get_visual_selection()`
        *   **Description:** Test the retrieval of the visual selection.
        *   **Expected Behavior:** Should return the text selected in visual mode.
        *   **Test Implementation:** Mock `vim.api.nvim_buf_get_text` to return a sample selection and assert the function's output.
    *   **Test:** `capitalize()`
        *   **Description:** Test the capitalization of a string.
        *   **Expected Behavior:** The first letter of the string should be capitalized.
        *   **Test Implementation:** Pass various strings (all lowercase, mixed case) and assert the output.
*   **`ui.lua`**
    *   **Test:** `create_floating_window()`
        *   **Description:** Test the creation of a floating window.
        *   **Expected Behavior:** It should call `vim.api.nvim_open_win` with the correct buffer and configuration.
        *   **Test Implementation:** Mock `vim.api.nvim_open_win` and assert it's called with the expected arguments.
    *   **Test:** `create_buffer_with_content()` and `replace_buffer_with_content()`
        *   **Description:** Test buffer creation and content replacement.
        *   **Expected Behavior:** A new buffer should be created, or an existing one modified, with the given content.
        *   **Test Implementation:** Mock `vim.api.nvim_create_buf` and `vim.api.nvim_buf_set_lines`. Call the functions and assert that the mocks are called with the right content.
*   **`validate.lua`**
    *   **Test:** `convert()`
        *   **Description:** Test type conversion for configuration values.
        *   **Expected Behavior:** Should correctly convert strings to booleans, numbers, etc.
        *   **Test Implementation:** Call `convert` with various input strings (`"true"`, `"false"`, `"123"`) and target types, then assert the output's type and value.

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
