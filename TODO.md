# Test Coverage Evaluation and Improvement Plan

## Summary

The repository has a decent foundation of tests, with good coverage of the `core` modules. However, there are significant gaps in the test coverage for the `managers` and `ui` modules, as well as the `facade.lua` file. These modules contain a large portion of the plugin's logic and user-facing features, so it's crucial that they are well-tested to ensure the plugin is reliable and maintainable.

## Testing Gaps

1.  **`lua/llm/facade.lua`**: This module, which serves as the main entry point for the plugin, is completely untested.

2.  **`lua/llm/managers/`**: None of the manager modules are tested. This is the most critical gap, as these modules contain the core logic for managing models, plugins, API keys, fragments, templates, and schemas.

3.  **`lua/llm/ui/`**: None of the UI modules are tested. While UI testing can be challenging in Neovim, the lack of any tests for the UI means that there is no automated way to verify that the UI is functioning correctly.

## Proposed Solutions

To address these gaps, I propose the following testing strategy:

### 1. `lua/llm/facade.lua`

*   **File:** `tests/spec/facade_spec.lua`
*   **Actions:**
    *   Verify that the `facade` module correctly delegates calls to the appropriate modules (`llm.commands` and the various manager modules).
    *   Use mocking to isolate the `facade` module from its dependencies.

### 2. `lua/llm/managers/`

*   **Files:** Create new test files for each manager module (e.g., `tests/spec/managers/models_manager_spec.lua`, `tests/spec/managers/plugins_manager_spec.lua`, etc.).
*   **Actions:** For each manager, add tests to verify the following:
    *   **Data retrieval and parsing**: Test that the manager correctly retrieves and parses data from the `llm-cli` and other external sources.
    *   **Caching**: Test that the manager correctly caches data.
    *   **Logic**: Test the core logic of the manager.
    *   **CLI interaction**: Test that the manager correctly calls the `llm-cli` with the correct arguments.
    *   **Buffer population**: Test that the manager correctly populates the buffer with the correct data for the TUI.

### 3. `lua/llm/ui/`

*   **`unified_manager.lua`**:
    *   **File:** `tests/spec/ui/unified_manager_spec.lua`
    *   **Actions:**
        *   Verify that the `unified_manager` correctly switches between views, sets the buffer name and window title, and calls the appropriate functions from the manager modules.
*   **`views/`**:
    *   Create integration-style tests that simulate user input and verify that the correct UI elements are displayed.

By implementing this testing strategy, we can significantly improve the test coverage of the repository, which will make the plugin more reliable, easier to maintain, and less prone to regressions.

---

## Detailed Task Breakdown

### Phase 1: Core Logic and Managers

#### 1. `facade.lua` (`tests/spec/facade_spec.lua`) - Done

#### 2. `managers/custom_openai.lua` (`tests/spec/managers/custom_openai_spec.lua`)

*   **`load_custom_openai_models()`**
    *   **Test:** should load models from a valid YAML file.
        *   **Implementation:** Create a dummy `extra-openai-models.yaml` file. Mock `file_utils.get_config_path` to return the path to the dummy file. Call `load_custom_openai_models` and assert that `M.custom_openai_models` is populated correctly.
    *   **Test:** should handle a missing or empty YAML file.
        *   **Implementation:** Mock `io.open` to return `nil`. Call `load_custom_openai_models` and assert that `M.custom_openai_models` is an empty table.
    *   **Test:** should handle an invalid YAML file.
        *   **Implementation:** Create a dummy YAML file with invalid syntax. Mock `text_utils.parse_simple_yaml` to return `nil`. Call `load_custom_openai_models` and assert that it returns an empty table and that `os.rename` was called to back up the file.
*   **`is_custom_openai_model_valid(model_identifier_or_data)`**
    *   **Test:** should return `true` for a valid model with an API key.
        *   **Implementation:** Mock `keys_manager.is_key_set` to return `true`. Call `is_custom_openai_model_valid` with a model that requires auth and assert that it returns `true`.
    *   **Test:** should return `false` for a valid model without an API key.
        *   **Implementation:** Mock `keys_manager.is_key_set` to return `false`. Call `is_custom_openai_model_valid` with a model that requires auth and assert that it returns `false`.
    *   **Test:** should return `true` for a model that does not require auth.
        *   **Implementation:** Call `is_custom_openai_model_valid` with a model where `needs_auth` is `false` and assert that it returns `true`.
*   **`add_custom_openai_model(model_details)` & `delete_custom_openai_model(model_id)`**
    *   **Test:** should correctly add/remove a model from the YAML file.
        *   **Implementation:** Create a dummy YAML file. Call the function and then read the file to assert that the content has been updated correctly.

#### 3. `managers/models_io.lua` (`tests/spec/managers/models_io_spec.lua`)

*   **All functions**
    *   **Test:** should call `llm_cli.run_llm_command` with the correct command string.
        *   **Implementation:** Mock `llm_cli.run_llm_command`. Call each function in `models_io.lua` and assert that the mock was called with the expected command string.

#### 4. `managers/models_manager.lua` (`tests/spec/managers/models_manager_spec.lua`)

*   **`get_available_models()`**
    *   **Test:** should parse the output from `llm-cli` correctly.
        *   **Implementation:** Mock `llm_cli.run_llm_command` to return a sample output string. Call `get_available_models` and assert that the returned table is structured correctly.
    *   **Test:** should cache the models.
        *   **Implementation:** Mock `llm_cli.run_llm_command` and `cache.get`/`cache.set`. Call `get_available_models` twice and assert that `llm_cli.run_llm_command` was only called once.
*   **`is_model_available(model_line)`**
    *   **Test:** should return `true` for an available model.
        *   **Implementation:** Mock `get_available_providers` to return a table indicating that the provider is available. Call `is_model_available` with a model from that provider and assert that it returns `true`.
    *   **Test:** should return `false` for an unavailable model.
        *   **Implementation:** Mock `get_available_providers` to return a table indicating that the provider is *not* available. Call `is_model_available` with a model from that provider and assert that it returns `false`.
*   **`set_default_model(model_name)`, `set_model_alias(alias, model)`, `remove_model_alias(alias)`**
    *   **Test:** should call the corresponding function in `models_io.lua`.
        *   **Implementation:** Mock the corresponding function in `models_io.lua`. Call the `models_manager` function and assert that the mock was called with the correct arguments.

#### 5. `managers/fragments_manager.lua` (`tests/spec/managers/fragments_manager_spec.lua`)

*   **`get_fragments()`**:
    *   **Test:** should parse JSON output from `llm_cli.run_llm_command('fragments list --json')`.
    *   **Test:** should cache the fragments.
*   **`set_alias_for_fragment_under_cursor()`**:
    *   **Test:** should call `llm_cli.run_llm_command` with `'fragments alias set <hash> <alias>'`.
*   **`remove_alias_from_fragment_under_cursor()`**:
    *   **Test:** should call `llm_cli.run_llm_command` with `'fragments alias remove <alias>'`.
*   **`add_file_fragment()`**:
    *   **Test:** should call `llm_cli.run_llm_command` with `'fragments store <file_path>'`.
*   **`add_github_fragment_from_manager()`**:
    *   **Test:** should call `llm_cli.run_llm_command` with `'fragments store <url>'`.

#### 6. `managers/keys_manager.lua` (`tests/spec/managers/keys_manager_spec.lua`)

*   **`get_stored_keys()`**:
    *   **Test:** should parse JSON output from `llm_cli.run_llm_command('keys list --json')`.
    *   **Test:** should cache the keys.
*   **`is_key_set(key_name)`**:
    *   **Test:** should return `true` if the key is in the list of stored keys.
    *   **Test:** should return `false` if the key is not in the list.
*   **`set_api_key(key_name, key_value)`**:
    *   **Test:** should call `llm_cli.run_llm_command` with `'keys set <key_name> <key_value>'`.
*   **`remove_api_key(key_name)`**:
    *   **Test:** should call `llm_cli.run_llm_command` with `'keys remove <key_name>'`.

#### 7. `managers/plugins_manager.lua` (`tests/spec/managers/plugins_manager_spec.lua`)

*   **`get_available_plugins()`**:
    *   **Test:** should parse the HTML from the plugin directory URL.
    *   **Test:** should handle a failed `curl` command gracefully.
    *   **Test:** should cache the available plugins.
*   **`get_installed_plugins()`**:
    *   **Test:** should parse the JSON output from `llm_cli.run_llm_command('plugins')`.
    *   **Test:** should cache the installed plugins.
*   **`is_plugin_installed(plugin_name)`**:
    *   **Test:** should return `true` if the plugin is in the list of installed plugins.
    *   **Test:** should return `false` if the plugin is not in the list.
*   **`install_plugin(plugin_name)`**:
    *   **Test:** should call `llm_cli.run_llm_command` with `'install <plugin_name>'`.
*   **`uninstall_plugin(plugin_name)`**:
    *   **Test:** should call `llm_cli.run_llm_command` with `'uninstall <plugin_name> -y'`.

#### 8. `managers/schemas_manager.lua` (`tests/spec/managers/schemas_manager_spec.lua`)

*   **`get_schemas()`**:
    *   **Test:** should parse JSON output from `llm_cli.run_llm_command('schemas list --json')`.
    *   **Test:** should cache the schemas.
*   **`get_schema(schema_id)`**:
    *   **Test:** should parse JSON output from `llm_cli.run_llm_command('schemas get <schema_id>')`.
*   **`save_schema(name, content)`**:
    *   **Test:** should call `llm_cli.run_llm_command` with `'schemas save <name> <temp_file_path>'`.
*   **`run_schema(schema_id, input, is_multi)`**:
    *   **Test:** should call `llm_cli.run_llm_command` with the correct arguments, including the `--multi` flag.

#### 9. `managers/templates_manager.lua` (`tests/spec/managers/templates_manager_spec.lua`)

*   **`get_templates()`**:
    *   **Test:** should parse JSON output from `llm_cli.run_llm_command('templates list --json')`.
    *   **Test:** should cache the templates.
*   **`get_template_details(template_name)`**:
    *   **Test:** should parse JSON output from `llm_cli.run_llm_command('templates show <template_name>')`.
*   **`create_template(...)`**:
    *   **Test:** should construct the correct `llm_cli.run_llm_command` string with all the provided arguments.
*   **`delete_template(template_name)`**:
    *   **Test:** should call `llm_cli.run_llm_command` with `'templates delete <template_name> -y'`.
*   **`run_template(template_name, input, params)`**:
    *   **Test:** should construct the correct `llm_cli.run_llm_command` string with the template name, input, and parameters.

### Phase 2: UI Components

*Note: UI components are notoriously difficult to unit test. The following tests focus on the logic within the UI modules, not the visual output.*

#### 1. `ui/unified_manager.lua` (`tests/spec/ui/unified_manager_spec.lua`)

*   **`switch_view(view_name)`**
    *   **Test:** should call the correct `populate` and `setup_keymaps` functions for the given view.
        *   **Implementation:** Mock the `populate` and `setup_keymaps` functions for each view. Call `switch_view` and assert that the correct mock functions were called.
    *   **Test:** should set the buffer name and window title correctly.
        *   **Implementation:** Mock `api.nvim_buf_set_name` and `api.nvim_win_set_config`. Call `switch_view` and assert that the mocks were called with the expected buffer name and window title.
*   **`open(initial_view)` & `toggle(view_name)`**
    *   **Test:** should open and close the unified window.
        *   **Implementation:** Mock `ui.create_floating_window` and `api.nvim_win_close`. Call `open` and `toggle` and assert that the mocks were called as expected.

#### 2. `ui/views/*.lua`

*   **Omission Explanation:** The `views` modules are primarily responsible for interacting with `vim.ui`, which is a part of the Neovim API that is not easily mockable. Testing these modules would require a more complex integration testing setup that is beyond the scope of this initial testing effort. The focus should be on testing the manager modules that *use* these views. The logic within the manager modules that prepares data for the views can and should be tested.

