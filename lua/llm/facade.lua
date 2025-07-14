-- llm/facade.lua - Centralized API surface for llm-nvim
-- License: Apache 2.0

local M = {}

-- Manager registry
local managers = {}

-- Dependency configuration
local dependencies = {
  utils = require('llm.utils'),
  config = require('llm.config'),
  styles = require('llm.styles'),
  commands = require('llm.commands')
}

-- Initialize all managers with dependencies
function M.init()
  -- Load managers in strict dependency order
  -- 1. Basic managers with no cross-dependencies
  managers.models = require('llm.models.models_manager')
  managers.keys = require('llm.keys.keys_manager')
  managers.fragments = require('llm.fragments.fragments_manager')
  managers.templates = require('llm.templates.templates_manager')
  managers.schemas = require('llm.schemas.schemas_manager')
  
  -- 2. Unified manager depends on basic managers
  managers.unified = require('llm.unified_manager')
  
  -- 3. Plugins manager depends on unified manager
  managers.plugins = require('llm.plugins.plugins_manager')
  
  -- Inject dependencies into all managers
  for _, manager in pairs(managers) do
    if manager.setup then
      -- Inject config with change listener support
      local config = {
        get = function(key)
          return dependencies.config.get(key)
        end,
        on_change = dependencies.config.on_change
      }
      manager.setup(vim.tbl_extend("keep", dependencies, {config = config}))
    end
  end
end

local function ensure_init()
    if not managers.models then
        M.init()
    end
end

-- Get manager instances
function M.get_manager(name)
  ensure_init()
  return managers[name]
end

-- Unified LLM command handler
function M.command(subcmd, ...)
  ensure_init()
  return dependencies.commands.dispatch_command(subcmd, ...)
end

-- Prompt functions
function M.prompt(prompt, fragment_paths)
  ensure_init()
  return dependencies.commands.prompt(prompt, fragment_paths)
end

function M.prompt_with_selection(prompt, fragment_paths)
  ensure_init()
  return dependencies.commands.prompt_with_selection(prompt, fragment_paths)
end

function M.prompt_with_current_file(prompt)
  ensure_init()
  return dependencies.commands.prompt_with_current_file(prompt)
end

-- Model functions
function M.get_available_models()
  ensure_init()
  return managers.models.get_available_models()
end

function M.extract_model_name(model_line)
  ensure_init()
  return managers.models.extract_model_name(model_line)
end

function M.select_model()
  ensure_init()
  return managers.models.select_model()
end

function M.get_model_aliases()
  ensure_init()
  return managers.models.get_model_aliases()
end

function M.set_model_alias(alias, model)
  ensure_init()
  return managers.models.set_model_alias(alias, model)
end

function M.remove_model_alias(alias)
  ensure_init()
  return managers.models.remove_model_alias(alias)
end

-- Plugin functions
function M.get_available_plugins()
  ensure_init()
  return managers.plugins.get_available_plugins()
end

function M.get_installed_plugins()
  ensure_init()
  return managers.plugins.get_installed_plugins()
end

function M.is_plugin_installed(plugin_name)
  ensure_init()
  return managers.plugins.is_plugin_installed(plugin_name)
end

function M.install_plugin(plugin_name)
  ensure_init()
  return managers.plugins.install_plugin(plugin_name)
end

function M.uninstall_plugin(plugin_name)
  ensure_init()
  return managers.plugins.uninstall_plugin(plugin_name)
end

-- Key functions
function M.get_stored_keys()
  ensure_init()
  return managers.keys.get_stored_keys()
end

function M.is_key_set(key_name)
  ensure_init()
  return managers.keys.is_key_set(key_name)
end

function M.set_api_key(key_name, key_value)
  ensure_init()
  return managers.keys.set_api_key(key_name, key_value)
end

function M.remove_api_key(key_name)
  ensure_init()
  return managers.keys.remove_api_key(key_name)
end

-- Fragment functions
function M.select_fragment()
  ensure_init()
  return managers.fragments.select_file_as_fragment()
end

function M.manage_fragments(show_all)
  ensure_init()
  return managers.fragments.manage_fragments(show_all)
end

-- Template functions
function M.manage_templates()
  ensure_init()
  return managers.templates.manage_templates()
end

function M.select_template()
  ensure_init()
  return managers.templates.select_template()
end

function M.create_template()
  ensure_init()
  return managers.templates.create_template()
end

function M.run_template_by_name(template_name)
  ensure_init()
  return managers.templates.run_template_by_name(template_name)
end

-- Schema functions
function M.manage_schemas(show_named_only)
  ensure_init()
  return managers.schemas.manage_schemas(show_named_only)
end

function M.select_schema()
  ensure_init()
  return managers.schemas.select_schema()
end

function M.create_schema()
  ensure_init()
  return managers.schemas.create_schema()
end

function M.run_schema(schema_id, input, is_multi)
  ensure_init()
  return managers.schemas.run_schema(schema_id, input, is_multi)
end

-- Unified manager functions
function M.manage_models()
  ensure_init()
  return managers.unified.open_specific_manager("Models")
end

function M.manage_keys()
  ensure_init()
  return managers.unified.open_specific_manager("Keys")
end

function M.manage_plugins()
  ensure_init()
  return managers.unified.open_specific_manager("Plugins")
end

function M.toggle_unified_manager(initial_view)
  if not managers.unified then
    M.init()
    if not managers.unified then
      error("Failed to initialize unified manager")
    end
  end
  return managers.unified.toggle(initial_view)
end

-- Utility functions
function M.refresh_plugins()
  ensure_init()
  return require('llm.plugins.plugins_loader').refresh_plugins_cache()
end

function M.setup_buffer_highlighting(buf)
  ensure_init()
  return dependencies.utils.setup_buffer_highlighting(buf)
end

return M