## Test Tasks for llm-nvim

This document outlines the test tasks for various functionalities of the `llm-nvim` plugin. Each task represents a specific feature or module that requires testing to ensure its correct behavior and integration.

### Core Functionality

- [x] Test `:LLM {prompt}` command: Verify that a basic prompt is sent to the LLM and the response is handled correctly.
- [x] Test `:LLM file [{prompt}]` command: Verify that the content of the current file is sent to the LLM with an optional prompt.
- [x] Test `:LLM selection [{prompt}]` command: Verify that the visual selection is sent to the LLM with an optional prompt.
- [x] Test `:LLM explain` command: Verify that the current buffer's code is sent for explanation.
- [x] Test `:LLM fragments` command: Verify the interactive prompt with fragment selection.
- [x] Test `:LLM schema` command: Verify the selection and execution of a schema.
- [x] Test `:LLM template` command: Verify the selection and execution of a template.
- [ ] Test `:LLM update` command: Verify manual triggering of the `llm` CLI update.
- [ ] Test `llm.setup()` configuration options: Verify that various configuration options are applied correctly.
- [ ] Test Markdown-formatted responses with syntax highlighting: Verify that LLM responses are displayed with correct Markdown formatting and syntax highlighting.
- [ ] Test asynchronous command execution: Verify that commands run asynchronously without blocking the Neovim UI.

### Unified Manager (`:LLMToggle`)

- [ ] Test `:LLMToggle` (default view): Verify that the unified manager opens to its default view.
- [ ] Test `:LLMToggle models`: Verify that the unified manager opens directly to the Models view.
- [ ] Test `:LLMToggle plugins`: Verify that the unified manager opens directly to the Plugins view.
- [ ] Test `:LLMToggle keys`: Verify that the unified manager opens directly to the API Keys view.
- [ ] Test `:LLMToggle fragments`: Verify that the unified manager opens directly to the Fragments view.
- [ ] Test `:LLMToggle templates`: Verify that the unified manager opens directly to the Templates view.
- [ ] Test `:LLMToggle schemas`: Verify that the unified manager opens directly to the Schemas view.
- [ ] Test navigation within the unified manager: Verify that navigation between different views (Models, Plugins, etc.) works correctly.

### Model Management

- [ ] Test `llm.models.models_manager.get_available_models()`: Verify retrieval of available LLM models.
- [ ] Test `llm.models.models_manager.extract_model_name()`: Verify correct extraction of model names from strings.
- [ ] Test `llm.models.models_manager.select_model()`: Verify the interactive model selection process.
- [ ] Test `llm.models.models_manager.get_model_aliases()`: Verify retrieval of configured model aliases.
- [ ] Test `llm.models.models_manager.set_model_alias()`: Verify setting a new model alias.
- [ ] Test `llm.models.models_manager.remove_model_alias()`: Verify removal of an existing model alias.

### Plugin Management

- [ ] Test `llm.plugins.plugins_manager.get_available_plugins()`: Verify retrieval of available `llm` CLI plugins.
- [ ] Test `llm.plugins.plugins_manager.get_installed_plugins()`: Verify retrieval of currently installed `llm` CLI plugins.
- [ ] Test `llm.plugins.plugins_manager.is_plugin_installed()`: Verify checking if a specific plugin is installed.
- [ ] Test `llm.plugins.plugins_manager.install_plugin()`: Verify the installation process of an `llm` CLI plugin.
- [ ] Test `llm.plugins.plugins_manager.uninstall_plugin()`: Verify the uninstallation process of an `llm` CLI plugin.

### API Key Management

- [ ] Test `llm.keys.keys_manager.get_stored_keys()`: Verify retrieval of stored API keys.
- [ ] Test `llm.keys.keys_manager.is_key_set()`: Verify checking if a specific API key is set.
- [ ] Test `llm.keys.keys_manager.set_api_key()`: Verify setting a new API key.
- [ ] Test `llm.keys.keys_manager.remove_api_key()`: Verify removal of an existing API key.

### Fragment Management

- [ ] Test `llm.fragments.fragments_manager.select_file_as_fragment()`: Verify selection of a file as a fragment.
- [ ] Test `llm.fragments.fragments_manager.manage_fragments()`: Verify the management interface for fragments.

### Template Management

- [ ] Test `llm.templates.templates_manager.manage_templates()`: Verify the management interface for templates.
- [ ] Test `llm.templates.templates_manager.select_template()`: Verify interactive template selection.
- [ ] Test `llm.templates.templates_manager.create_template()`: Verify the template creation process.
- [ ] Test `llm.templates.templates_manager.run_template_by_name()`: Verify running a template by its name.

### Schema Management

- [ ] Test `llm.schemas.schemas_manager.manage_schemas()`: Verify the management interface for schemas.
- [ ] Test `llm.schemas.schemas_manager.select_schema()`: Verify interactive schema selection.
- [ ] Test `llm.schemas.schemas_manager.create_schema()`: Verify the schema creation process.
- [ ] Test `llm.schemas.schemas_manager.run_schema()`: Verify running a schema with given input.

### Utilities

- [ ] Test `llm.utils.shell.check_llm_installed()`: Verify checking for `llm` CLI installation.
- [ ] Test `llm.utils.shell.update_llm_cli()`: Verify the `llm` CLI update mechanism.
- [ ] Test `llm.utils.notify` functions: Verify that notifications are displayed correctly.
- [ ] Test `llm.utils.file_utils` functions: Verify file-related utility functions (e.g., reading, writing).
- [ ] Test `llm.utils.text` functions: Verify text manipulation utility functions.
- [ ] Test `llm.utils.ui` functions: Verify UI-related utility functions (e.g., popups, input).
- [ ] Test `llm.utils.validate` functions: Verify data validation utility functions.