-- llm/facade.lua - Centralized API surface for llm-nvim
-- License: Apache 2.0

local M = {}

-- Manager registry
local managers = {}

-- Dependency configuration
local dependencies = {
  config = require('llm.config'),
  commands = require('llm.commands')
}

-- Initialize all managers with dependencies
function M.init()
  managers.models = require('llm.managers.models_manager')
  managers.keys = require('llm.managers.keys_manager')
  managers.fragments = require('llm.managers.fragments_manager')
  managers.templates = require('llm.managers.templates_manager')
  managers.schemas = require('llm.managers.schemas_manager')
  managers.plugins = require('llm.managers.plugins_manager')
  managers.unified = require('llm.ui.unified_manager')

  -- Inject dependencies into all managers
  for name, manager in pairs(managers) do
    if manager.setup then
      local deps = {
        config = dependencies.config,
        get_manager = function(m_name) return managers[m_name] end
      }
      manager.setup(deps)
    end
  end
end

-- Get manager instances
function M.get_manager(name)
  return managers[name]
end

-- Unified LLM command handler
function M.command(subcmd, ...)
  return dependencies.commands.dispatch_command(subcmd, ...)
end

-- Prompt functions
function M.prompt(prompt, fragment_paths)
  return dependencies.commands.prompt(prompt, fragment_paths)
end

function M.prompt_with_selection(prompt, fragment_paths)
  return dependencies.commands.prompt_with_selection(prompt, fragment_paths)
end

function M.prompt_with_current_file(prompt)
  return dependencies.commands.prompt_with_current_file(prompt)
end

-- Unified manager functions
function M.toggle_unified_manager(initial_view)
  if not managers.unified then
    M.init()
    if not managers.unified then
      error("Failed to initialize unified manager")
    end
  end
  return managers.unified.toggle(initial_view)
end

return M
