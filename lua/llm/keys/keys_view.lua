-- llm/keys/keys_view.lua - UI functions for key management
-- License: Apache 2.0

local M = {}

local utils = require('llm.utils')

function M.get_custom_key_name(callback)
  utils.floating_input({ prompt = "Enter custom key name:" }, callback)
end

function M.get_api_key(provider_name, callback)
  utils.floating_input({ prompt = "Enter API key for '" .. provider_name .. "':" }, callback)
end

function M.confirm_remove_key(provider_name, callback)
  utils.floating_confirm({
    prompt = "Remove key for '" .. provider_name .. "'?",
    on_confirm = function()
      callback()
    end
  })
end

return M
