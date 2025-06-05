-- llm/init.lua - Entry point for lazy.nvim integration
-- License: Apache 2.0

local M = {}
local api = require('llm.api')
local facade = require('llm.facade')

-- Setup function for configuration
function M.setup(opts)
  -- Initialize config first
  M.config = require('llm.config')
  M.config.setup(opts or {})

  -- Initialize styles
  require('llm.styles').setup_highlights()

  -- Initialize facade with managers
  facade.init()

  -- Refresh plugins cache on startup if enabled
  if not M.config.get("no_auto_refresh_plugins") then
    vim.defer_fn(function()
      require('llm.plugins.plugins_loader').refresh_plugins_cache()
    end, 1000) -- Longer delay to avoid startup impact
  end

  -- Auto-update LLM CLI check
  local auto_update_cli = M.config.get('auto_update_cli')
  local auto_update_interval_days = M.config.get('auto_update_interval_days')

  if auto_update_cli then
    local shell = require('llm.utils.shell')
    local last_update_ts = shell.get_last_update_timestamp()
    local current_ts = os.time()
    local days_since_last_update = (current_ts - last_update_ts) / (60 * 60 * 24)

    if days_since_last_update >= auto_update_interval_days then
      vim.notify("LLM-Nvim: Checking for LLM CLI updates...", vim.log.levels.INFO)
      vim.defer_fn(function()
        local result = shell.update_llm_cli()
        if result and result.success then
          vim.notify("LLM CLI auto-update successful.", vim.log.levels.INFO)
        elseif result then
          local msg = "LLM CLI auto-update failed."
          if result.message and string.len(result.message) > 0 then
            msg = msg .. " Details:\n" .. result.message
             -- Check if notify module is available to use more advanced notification
            local notify_mod = require('llm.utils.notify')
            if notify_mod and notify_mod.notify then
              notify_mod.notify(msg, vim.log.levels.WARN, {title = "LLM Auto-Update"})
            else
              vim.notify(msg, vim.log.levels.WARN)
            end
          else
            vim.notify(msg, vim.log.levels.WARN)
          end
        else
          vim.notify("LLM CLI auto-update check failed to run.", vim.log.levels.ERROR)
        end
      end, 100) -- Short delay to not block startup critical path
    end
  end

  return M
end

-- Initialize config after module definition
local function initialize_config()
  M.config = require('llm.config')
  M.config.setup()
  if not M.config then
    M.config = { get = function() return {} end }
    require('llm.errors').handle('config', 
      "Failed to initialize config, using empty fallback", nil, require('llm.errors').levels.WARNING)
  end
end

-- Initialize config immediately after module definition
initialize_config()

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