-- llm/init.lua - Entry point for lazy.nvim integration
-- License: Apache 2.0

local M = {}
local api = require('llm.api')
local facade = require('llm.facade')

-- Setup function for configuration
function M.setup(opts)
  -- Load the configuration module
  require('llm.config').setup(opts)

  -- Initialize styles
  require('llm.styles').setup_highlights()

  -- Initialize facade with managers
  facade.init()

  -- Refresh plugins cache on startup if enabled
  if not require('llm.config').get("no_auto_refresh_plugins") then
    vim.defer_fn(function()
      require('llm.plugins.plugins_loader').refresh_plugins_cache()
    end, 1000) -- Longer delay to avoid startup impact
  end

  return M
end

-- Initialize with default configuration
require('llm.config').setup()

-- Initialize config path cache by making a call early
-- This helps ensure the config directory is known before managers need it
vim.defer_fn(function()
  require('llm.utils').get_config_path("")
  -- Refresh plugins cache in background after a short delay
  vim.defer_fn(function()
    require('llm.plugins.plugins_loader').refresh_plugins_cache()
  end, 500) -- Longer delay to avoid startup impact
end, 100)   -- Small delay to avoid blocking startup

-- Expose facade functions
for k, v in pairs(facade) do
  M[k] = v
end

-- Expose functions to global scope for testing purposes only
if vim.env.LLM_NVIM_TEST then
  for k, v in pairs(facade) do
    _G[k] = v
  end
end

return M