-- llm/init.lua - Entry point for lazy.nvim integration
-- License: Apache 2.0

-- Create module
local M = {}

-- Forward declarations
local api = vim.api
local fn = vim.fn

-- Load utility modules
local utils = require('llm.utils')
local commands = require('llm.commands')
local models_manager = require('llm.managers.models_manager')
local keys_manager = require('llm.managers.keys_manager')
local plugins_manager = require('llm.managers.plugins_manager')
local templates_manager = require('llm.managers.templates_manager')
local schemas_manager = require('llm.managers.schemas_manager')

-- Forward declaration of other modules
local config
local fragments

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

-- Prompt with fragments
function M.prompt_with_fragments(prompt)
  -- This function is implemented in the fragments_loader module
  require('llm.loaders.fragments_loader').prompt_with_fragments(prompt)
end

-- Prompt with selection and fragments
function M.prompt_with_selection_and_fragments(prompt)
  -- This function is implemented in the fragments_loader module
  require('llm.loaders.fragments_loader').prompt_with_selection_and_fragments(prompt)
end

-- Get available models from llm CLI
function M.get_available_models()
  return models_manager.get_available_models()
end

-- Extract model name from the full model line
function M.extract_model_name(model_line)
  return models_manager.extract_model_name(model_line)
end

-- Select a model to use
function M.select_model()
  models_manager.select_model()
end

-- Get available plugins from the plugin directory
function M.get_available_plugins()
  return plugins_manager.get_available_plugins()
end

-- Get installed plugins from llm CLI
function M.get_installed_plugins()
  return plugins_manager.get_installed_plugins()
end

-- Check if a plugin is installed
function M.is_plugin_installed(plugin_name)
  return plugins_manager.is_plugin_installed(plugin_name)
end

-- Install a plugin using llm CLI
function M.install_plugin(plugin_name)
  return plugins_manager.install_plugin(plugin_name)
end

-- Uninstall a plugin using llm CLI
function M.uninstall_plugin(plugin_name)
  return plugins_manager.uninstall_plugin(plugin_name)
end

-- Get model aliases from llm CLI
function M.get_model_aliases()
  return models_manager.get_model_aliases()
end

-- Set a model alias using llm CLI
function M.set_model_alias(alias, model)
  return models_manager.set_model_alias(alias, model)
end

-- Remove a model alias using llm CLI
function M.remove_model_alias(alias)
  return models_manager.remove_model_alias(alias)
end

-- Manage models and aliases
function M.manage_models()
  -- Delegate to the models_manager module
  models_manager.manage_models()
end

-- Manage API keys
function M.manage_keys()
  keys_manager.manage_keys()
end

-- Manage plugins (view, install, uninstall)
function M.manage_plugins()
  plugins_manager.manage_plugins()
end

-- Setup function for configuration
function M.setup(opts)
  -- Load the configuration module
  config = require('llm.config')
  config.setup(opts)

  -- Load the templates module
  templates = require('llm.managers.templates_manager')
  
  -- Initialize styles
  require('llm.styles').setup_highlights()

  return M
end

-- Initialize with default configuration
config = require('llm.config')
config.setup()

-- Initialize config path cache by making a call early
vim.defer_fn(function()
  require('llm.utils').get_config_path("")
end, 100)  -- Small delay to avoid blocking startup

-- Load the fragments modules
local fragments_manager = require('llm.managers.fragments_manager')
local fragments_loader = require('llm.loaders.fragments_loader')

-- Load the templates module
templates = require('llm.managers.templates_manager')

-- Get stored API keys from llm CLI
function M.get_stored_keys()
  return keys_manager.get_stored_keys()
end

-- Expose for testing
_G.get_stored_keys = function()
  return M.get_stored_keys()
end

-- Check if an API key is set
function M.is_key_set(key_name)
  return keys_manager.is_key_set(key_name)
end

-- Expose for testing
_G.is_key_set = function(key_name)
  return M.is_key_set(key_name)
end

-- Set an API key using llm CLI
function M.set_api_key(key_name, key_value)
  return keys_manager.set_api_key(key_name, key_value)
end

-- Expose for testing
_G.set_api_key = function(key_name, key_value)
  return M.set_api_key(key_name, key_value)
end

-- Remove an API key using llm CLI
function M.remove_api_key(key_name)
  return keys_manager.remove_api_key(key_name)
end

-- Expose for testing
_G.remove_api_key = function(key_name)
  return M.remove_api_key(key_name)
end

-- Manage fragments
function M.manage_fragments(show_all)
  require('llm.managers.fragments_manager').manage_fragments(show_all)
end

-- Select a file to use as a fragment
function M.select_fragment()
  require('llm.loaders.fragments_loader').select_file_as_fragment()
end

-- Manage templates
function M.manage_templates()
  templates_manager.manage_templates()
end

-- Select and run a template
function M.select_template()
  templates_manager.select_template()
end

-- Create a new template with guided flow
function M.create_template()
  templates_manager.create_template()
end

-- Run a template by name
function M.run_template_by_name(template_name)
  templates_manager.run_template_by_name(template_name)
end

-- Manage schemas
function M.manage_schemas(show_named_only)
  schemas_manager.manage_schemas(show_named_only)
end

-- Select and run a schema
function M.select_schema()
  schemas_manager.select_schema()
end

-- Create a new schema
function M.create_schema()
  schemas_manager.create_schema()
end

-- Run a schema with input
function M.run_schema(schema_id, input, is_multi)
  return schemas_manager.run_schema(schema_id, input, is_multi)
end

-- Manually refresh plugins
function M.refresh_plugins()
  require('llm.loaders.plugins_loader').refresh_plugins_cache()
end

-- Set up syntax highlighting for plugin/key manager buffers
function M.setup_buffer_highlighting(buf)
  utils.setup_buffer_highlighting(buf)
end

return M
