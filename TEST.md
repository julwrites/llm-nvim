# Test Enumeration

This document enumerates the tests that were written for the previous architecture of the plugin.

## Core Functionality

- **`minimal_spec.lua`**: A minimal test to ensure the test runner is working.
- **`simple_spec.lua`**: A simple test to ensure the test runner is working.
- **`utils_spec.lua`**: Tests for utility functions, including:
    - `validate`: Type validation and conversion.
    - `text`: Text manipulation functions like `get_visual_selection`, `escape_pattern`, and `parse_simple_yaml`.
    - `shell`: Shell command execution, command existence checks, and `llm` CLI interactions.
    - `file_utils`: File and directory manipulation, and configuration path management.

## Model Management

- **`custom_openai_spec.lua`**: Tests for managing custom OpenAI models, including:
    - Loading custom models from a YAML file.
    - Validating custom models.
    - Adding and deleting custom models.
- **`models_io_spec.lua`**: Tests for the I/O layer of model management, which interacts with the `llm` CLI to:
    - Get available models.
    - Get and set the default model.
    - Get, set, and remove aliases.
- **`models_manager_spec.lua`**: Tests for the main logic of model management, including:
    - Extracting model names.
    - Getting available models and aliases.
    - Setting the default model.
    - Setting and removing aliases for models.
    - Adding custom OpenAI models.
- **`generate_models_list_spec.lua`**: Tests for generating the formatted list of models for the UI.

## Fragments Management

- **`fragments_manager_spec.lua`**: Tests for managing fragments, including:
    - Setting and removing aliases for fragments.
    - Adding file and GitHub fragments.
    - Prompting with a fragment.
    - Viewing a fragment.

## Keys Management

- **`keys_manager_spec.lua`**: Tests for managing API keys, including:
    - Setting and removing API keys.
    - Adding new custom keys.

## Plugins Management

- **`plugins_manager_spec.lua`**: Tests for managing plugins, including:
    - Checking if a plugin is installed.
    - Installing and uninstalling plugins.
    - Populating the plugins buffer in the UI.

## Schemas Management

- **`schemas_manager_spec.lua`**: Tests for managing schemas, including:
    - Getting schemas.
    - Setting and deleting aliases for schemas.
    - Creating and running schemas.

## Templates Management

- **`templates_manager_spec.lua`**: Tests for managing templates, including:
    - Getting templates.
    - Deleting, creating, and running templates.
- **`templates_view_spec.lua`**: Tests for the UI components of template management, ensuring that the correct UI functions are called.
