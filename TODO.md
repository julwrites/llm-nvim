# TODO

## schemas_manager_spec.lua
- [ ] schemas_manager get_schemas should return the loaded schemas
- [ ] schemas_manager set_alias_for_schema_under_cursor should set an alias for a schema
- [ ] schemas_manager delete_alias_for_schema_under_cursor should delete an alias for a schema

## plugins_manager_spec.lua
- [ ] plugins_manager is_plugin_installed should return true if the plugin is installed
- [ ] plugins_manager is_plugin_installed should return false if the plugin is not installed
- [ ] plugins_manager install_plugin should call safe_shell_command with the correct arguments
- [ ] plugins_manager uninstall_plugin_under_cursor should call safe_shell_command with the correct arguments
- [ ] plugins_manager populate_plugins_buffer should correctly display installed and uninstalled plugins

## templates_view_spec.lua
- [ ] templates_view select_template should call vim.ui.select with the correct parameters
- [ ] templates_view get_user_input should call utils.floating_input with the correct parameters
- [ ] templates_view confirm_extract should call utils.floating_confirm
- [ ] templates_view select_schema should call vim.ui.select
- [ ] templates_view confirm_delete should call utils.floating_confirm

## generate_models_list_spec.lua
- [ ] generate_models_list should return a list of formatted models

## models_io_spec.lua
- [ ] models_io get_models_from_cli should call safe_shell_command with the correct arguments
- [ ] models_io get_default_model_from_cli should call safe_shell_command with the correct arguments
- [ ] models_io set_default_model_in_cli should call safe_shell_command with the correct arguments
- [ ] models_io get_aliases_from_cli should call safe_shell_command with the correct arguments
- [ ] models_io set_alias_in_cli should call safe_shell_command with the correct arguments
- [ ] models_io remove_alias_in_cli should call safe_shell_command with the correct arguments

## models_manager_spec.lua
- [ ] models_manager get_available_models should return a list of models from the cli
- [ ] models_manager get_model_aliases should return a table of aliases from the cli
- [ ] models_manager set_default_model should call models_io.set_default_model_in_cli with the correct model name
- [ ] models_manager set_alias_for_model_under_cursor should call set_model_alias with the correct alias and model
- [ ] models_manager remove_alias_for_model_under_cursor should call remove_model_alias with the correct alias
- [ ] models_manager add_custom_openai_model_interactive should call custom_openai.add_custom_openai_model with the correct details

## templates_manager_spec.lua
- [ ] templates_manager get_templates should return the loaded templates
- [ ] templates_manager create_template should create a basic template with a regular prompt
- [ ] templates_manager create_template should create a template with system prompt and model

## fragments_manager_spec.lua
- [ ] fragments_manager set_alias_for_fragment_under_cursor should set an alias for a fragment
- [ ] fragments_manager remove_alias_from_fragment_under_cursor should remove an alias from a fragment
- [ ] fragments_manager add_file_fragment should add a file fragment
- [ ] fragments_manager add_github_fragment_from_manager should add a github fragment
- [ ] fragments_manager prompt_with_fragment_under_cursor should prompt with a fragment
- [ ] fragments_manager view_fragment_under_cursor should view a fragment

## custom_openai_spec.lua
- [ ] custom_openai load_custom_openai_models should load custom models from a yaml file
- [ ] custom_openai is_custom_openai_model_valid should return false for an invalid model

## utils_spec.lua
- [ ] llm.core.utils.file_utils get_config_path should return the config path
- [ ] llm.core.utils.file_utils get_config_path should handle trailing whitespace in paths
