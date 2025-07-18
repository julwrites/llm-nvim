-- llm/ui/views/plugins_view.lua - UI functions for plugin management
-- License: Apache 2.0

local M = {}

local ui = require('llm.core.utils.ui')

function M.confirm_uninstall(plugin_name, callback)
  ui.floating_confirm({
    prompt = "Uninstall " .. plugin_name .. "?",
    on_confirm = function(confirmed)
      callback(confirmed == "Yes")
    end
  })
end

return M
