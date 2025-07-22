-- llm/init.lua - Entry point for lazy.nvim integration
-- License: Apache 2.0

local M = {}
local loaders = require('llm.core.loaders')

-- Setup function for configuration
function M.setup(opts)
  -- Initialize config first
  M.config = require('llm.config')
  M.config.setup(opts or {})

  -- Initialize styles
  require('llm.ui.styles').setup_highlights()

  -- Defer loading facade to prevent circular dependency
  local facade = require('llm.facade')
  for k, v in pairs(facade) do
    M[k] = v
  end

  -- Load all data
  loaders.load_all()

  -- Auto-update LLM CLI check
  local auto_update_cli = M.config.get('auto_update_cli')
  local auto_update_interval_days = M.config.get('auto_update_interval_days')

  if auto_update_cli then
    local shell = require('llm.core.utils.shell')
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
            local notify_mod = require('llm.core.utils.notify')
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

  -- Defer the plugin refresh to avoid circular dependencies
  vim.defer_fn(function()
    local plugins_manager = require('llm.managers.plugins_manager')
    plugins_manager.refresh_available_plugins()
  end, 100)

  return M
end

-- Expose functions to global scope for testing purposes only
if vim.env.LLM_NVIM_TEST then
  for k, v in pairs(facade) do
    _G[k] = v
  end
end

return M