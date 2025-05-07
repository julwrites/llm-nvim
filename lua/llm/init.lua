-- llm/init.lua - Entry point for lazy.nvim integration
-- License: Apache 2.0

-- Create module
local M = {}

-- Forward declarations
local api = vim.api
local fn = vim.fn

-- Load core utility modules (needed early or by multiple managers)
local utils = require('llm.utils')
local commands = require('llm.commands')
local config = require('llm.config')
local fragments_loader = require('llm.fragments.fragments_loader')
local styles = require('llm.styles')

-- Manager modules will be required lazily when their functions are called

-- Send a prompt to llm
function M.prompt(prompt, fragment_paths)
  commands.prompt(prompt, fragment_paths)
end

-- Send selected text with a prompt to llm
function M.prompt_with_selection(prompt, fragment_paths)
  commands.prompt_with_selection(prompt, fragment_paths)
end

-- Explain the current buffer or selection
function M.explain_code(fragment_paths)
  commands.explain_code(fragment_paths)
end

-- Start a chat session with llm
function M.start_chat(model_override)
  commands.start_chat(model_override)
end

-- Interactive prompt with fragments (handles visual selection internally)
function M.interactive_prompt_with_fragments(opts)
  commands.interactive_prompt_with_fragments(opts)
end

-- Get available models from llm CLI
function M.get_available_models()
  local models_manager = require('llm.models.models_manager')
  return models_manager.get_available_models()
end

-- Extract model name from the full model line
function M.extract_model_name(model_line)
  local models_manager = require('llm.models.models_manager')
  return models_manager.extract_model_name(model_line)
end

-- Select a model to use
function M.select_model()
  local models_manager = require('llm.models.models_manager')
  models_manager.select_model()
end

-- Get available plugins from the plugin directory
function M.get_available_plugins()
  local plugins_manager = require('llm.plugins.plugins_manager')
  return plugins_manager.get_available_plugins()
end

-- Get installed plugins from llm CLI
function M.get_installed_plugins()
  local plugins_manager = require('llm.plugins.plugins_manager')
  return plugins_manager.get_installed_plugins()
end

-- Check if a plugin is installed
function M.is_plugin_installed(plugin_name)
  local plugins_manager = require('llm.plugins.plugins_manager')
  return plugins_manager.is_plugin_installed(plugin_name)
end

-- Install a plugin using llm CLI
function M.install_plugin(plugin_name)
  local plugins_manager = require('llm.plugins.plugins_manager')
  return plugins_manager.install_plugin(plugin_name)
end

-- Uninstall a plugin using llm CLI
function M.uninstall_plugin(plugin_name)
  local plugins_manager = require('llm.plugins.plugins_manager')
  return plugins_manager.uninstall_plugin(plugin_name)
end

-- Get model aliases from llm CLI
function M.get_model_aliases()
  local models_manager = require('llm.models.models_manager')
  return models_manager.get_model_aliases()
end

-- Set a model alias using llm CLI
function M.set_model_alias(alias, model)
  local models_manager = require('llm.models.models_manager')
  return models_manager.set_model_alias(alias, model)
end

-- Remove a model alias using llm CLI
function M.remove_model_alias(alias)
  local models_manager = require('llm.models.models_manager')
  return models_manager.remove_model_alias(alias)
end

-- Manage models and aliases - Delegates to unified manager
function M.manage_models()
  local unified_manager = require('llm.unified_manager')
  unified_manager.open_specific_manager("Models")
end

-- Manage API keys - Delegates to unified manager
function M.manage_keys()
  local unified_manager = require('llm.unified_manager')
  unified_manager.open_specific_manager("Keys")
end

-- Manage plugins (view, install, uninstall) - Delegates to unified manager
function M.manage_plugins()
  local unified_manager = require('llm.unified_manager')
  unified_manager.open_specific_manager("Plugins")
end

-- Setup function for configuration
function M.setup(opts)
  -- Load the configuration module (already required at top)
  config.setup(opts)

  -- Initialize styles (already required at top)
  styles.setup_highlights()

  -- Refresh plugins cache on startup if enabled
  if not config.get("no_auto_refresh_plugins") then
    vim.defer_fn(function()
      require('llm.plugins.plugins_loader').refresh_plugins_cache()
    end, 1000) -- Longer delay to avoid startup impact
  end

  return M
end

-- Initialize with default configuration (config module already required)
config.setup()

-- Initialize config path cache by making a call early
-- This helps ensure the config directory is known before managers need it
vim.defer_fn(function()
  utils.get_config_path("")
  -- Refresh plugins cache in background after a short delay
  vim.defer_fn(function()
    require('llm.plugins.plugins_loader').refresh_plugins_cache()
  end, 500) -- Longer delay to avoid startup impact
end, 100) -- Small delay to avoid blocking startup

-- Get stored API keys from llm CLI
function M.get_stored_keys()
  local keys_manager = require('llm.keys.keys_manager')
  return keys_manager.get_stored_keys()
end

-- Check if an API key is set
function M.is_key_set(key_name)
  local keys_manager = require('llm.keys.keys_manager')
  return keys_manager.is_key_set(key_name)
end

-- Set an API key using llm CLI
function M.set_api_key(key_name, key_value)
  local keys_manager = require('llm.keys.keys_manager')
  return keys_manager.set_api_key(key_name, key_value)
end

-- Remove an API key using llm CLI
function M.remove_api_key(key_name)
  local keys_manager = require('llm.keys.keys_manager')
  return keys_manager.remove_api_key(key_name)
end

-- Manage fragments - Delegates to unified manager
function M.manage_fragments(show_all)
  local fragments_manager = require('llm.fragments.fragments_manager')
  fragments_manager.manage_fragments(show_all) -- The manager itself handles delegation
end

-- Select a file to use as a fragment
function M.select_fragment()
  -- fragments_loader is already required at the top
  fragments_loader.select_file_as_fragment()
end

-- Manage templates - Delegates to unified manager
function M.manage_templates()
  local templates_manager = require('llm.templates.templates_manager')
  templates_manager.manage_templates() -- The manager itself handles delegation
end

-- Select and run a template
function M.select_template()
  local templates_manager = require('llm.templates.templates_manager')
  templates_manager.select_template()
end

-- Create a new template with guided flow
function M.create_template()
  local templates_manager = require('llm.templates.templates_manager')
  templates_manager.create_template()
end

-- Run a template by name
function M.run_template_by_name(template_name)
  local templates_manager = require('llm.templates.templates_manager')
  templates_manager.run_template_by_name(template_name)
end

-- Manage schemas - Delegates to unified manager
function M.manage_schemas(show_named_only)
  local schemas_manager = require('llm.schemas.schemas_manager')
  schemas_manager.manage_schemas(show_named_only) -- The manager itself handles delegation
end

-- Select and run a schema
function M.select_schema()
  local schemas_manager = require('llm.schemas.schemas_manager')
  schemas_manager.select_schema()
end

-- Create a new schema
function M.create_schema()
  local schemas_manager = require('llm.schemas.schemas_manager')
  schemas_manager.create_schema()
end

-- Run a schema with input
function M.run_schema(schema_id, input, is_multi)
  local schemas_manager = require('llm.schemas.schemas_manager')
  return schemas_manager.run_schema(schema_id, input, is_multi)
end

-- Manually refresh plugins
function M.refresh_plugins()
  local plugins_loader = require('llm.plugins.plugins_loader')
  plugins_loader.refresh_plugins_cache()
end

-- Set up syntax highlighting for plugin/key manager buffers
function M.setup_buffer_highlighting(buf)
  -- utils is already required at the top
  utils.setup_buffer_highlighting(buf)
end

-- Toggle the unified manager window
function M.toggle_unified_manager(initial_view)
  local unified_manager = require('llm.unified_manager')
  unified_manager.toggle(initial_view)
end

-- Expose functions to global scope for testing purposes only
-- These should ideally be conditional on a test environment flag
-- Note: These global assignments are also handled in plugin/llm.lua
-- Keeping them here provides a fallback if plugin/llm.lua is not sourced
-- or if testing directly requires llm.init.
if vim.env.LLM_NVIM_TEST then
  local models_manager = require('llm.models.models_manager')
  local plugins_manager = require('llm.plugins.plugins_manager')
  local keys_manager = require('llm.keys.keys_manager')
  local fragments_loader = require('llm.fragments.fragments_loader')
  local schemas_manager = require('llm.schemas.schemas_manager')
  local templates_manager = require('llm.templates.templates_manager')

  _G.select_model = models_manager.select_model
  _G.get_available_models = models_manager.get_available_models
  _G.extract_model_name = models_manager.extract_model_name
  _G.set_default_model = models_manager.set_default_model

  _G.get_available_plugins = plugins_manager.get_available_plugins
  _G.get_installed_plugins = plugins_manager.get_installed_plugins
  _G.is_plugin_installed = plugins_manager.is_plugin_installed
  _G.install_plugin = plugins_manager.install_plugin
  _G.uninstall_plugin = plugins_manager.uninstall_plugin

  _G.get_fragments = fragments_loader.get_fragments
  _G.set_fragment_alias = fragments_loader.set_fragment_alias
  _G.remove_fragment_alias = fragments_loader.remove_fragment_alias

  _G.get_stored_keys = keys_manager.get_stored_keys
  _G.is_key_set = keys_manager.is_key_set
  _G.set_api_key = keys_manager.set_api_key
  _G.remove_api_key = keys_manager.remove_api_key

  _G.get_schemas = schemas_manager.get_schemas
  _G.get_schema = schemas_manager.get_schema
  _G.save_schema = schemas_manager.save_schema
  _G.run_schema = schemas_manager.run_schema

  _G.get_templates = templates_manager.get_templates
  _G.get_template_details = templates_manager.get_template_details
  _G.delete_template = templates_manager.delete_template
  _G.run_template = templates_manager.run_template
end


return M
