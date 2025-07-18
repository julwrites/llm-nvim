-- llm/plugins/plugins_view.lua - UI functions for plugin management
-- License: Apache 2.0

local M = {}

local utils = require('llm.utils')

function M.confirm_uninstall(plugin_name, callback)
  utils.floating_confirm({
    prompt = "Uninstall " .. plugin_name .. "?",
    on_confirm = function(confirmed)
      callback(confirmed)
    end
  })
end

return M
