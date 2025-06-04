-- llm/api.lua - Public API surface for llm-nvim
-- License: Apache 2.0

local M = {}
local facade = require('llm.facade')
local config = require('llm.config')

--- Setup function for plugin configuration
-- @param opts table: Configuration options table
-- @return table: The API module
function M.setup(opts)
  config.setup(opts)
  return M
end

--- Get current plugin version
-- @return string: Version string
function M.version()
  return require('llm.config').version
end

-- Expose all facade functions through API
for name, fn in pairs(facade) do
  M[name] = function(...)
    return fn(...)
  end
end

-- Add API documentation metadata
M.__name = 'llm.api'
M.__description = 'Public API surface for llm-nvim plugin'

return M