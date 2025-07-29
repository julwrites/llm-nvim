-- llm/facade.lua - Centralized API surface for llm-nvim
-- License: Apache 2.0

local M = {}

-- Manager registry and cache
local managers = {
  models = nil,
  keys = nil,
  fragments = nil,
  templates = nil,
  schemas = nil,
  plugins = nil,
  unified = nil,
}

local manager_files = {
  models = 'llm.managers.models_manager',
  keys = 'llm.managers.keys_manager',
  fragments = 'llm.managers.fragments_manager',
  templates = 'llm.managers.templates_manager',
  schemas = 'llm.managers.schemas_manager',
  plugins = 'llm.managers.plugins_manager',
  unified = 'llm.ui.unified_manager',
}

-- Get manager instances with lazy loading
function M.get_manager(name)
  if not managers[name] and manager_files[name] then
    managers[name] = require(manager_files[name])
  end
  return managers[name]
end

if vim.env.NVIM_LLM_TEST then
  function M._get_managers()
    return managers
  end
end

-- Unified LLM command handler
function M.command(subcmd, ...)
  return require('llm.commands').dispatch_command(subcmd, ...)
end

-- Prompt functions
function M.prompt(prompt, fragment_paths)
  return require('llm.commands').prompt(prompt, fragment_paths)
end

function M.prompt_with_selection(prompt, fragment_paths)
  return require('llm.commands').prompt_with_selection(prompt, fragment_paths)
end

function M.prompt_with_current_file(prompt)
  return require('llm.commands').prompt_with_current_file(prompt)
end

-- Unified manager functions
function M.toggle_unified_manager(initial_view)
  local unified_manager = M.get_manager('unified')
  if unified_manager then
    return unified_manager.toggle(initial_view)
  else
    error("Failed to load unified manager")
  end
end

return M
