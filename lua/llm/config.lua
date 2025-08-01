-- llm/config.lua - Configuration module for llm-nvim
-- License: Apache 2.0

local M = {}

-- Default configuration
M.defaults = {
  model = nil, -- Use llm CLI's default model if not set
  system_prompt = "You are a helpful assistant.",
  no_mappings = false,
  debug = true,  -- Enable debug logging while we troubleshoot
}

-- User configuration
M.options = {}

-- Initialize configuration
function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts)
end

-- Get a configuration value
function M.get(key)
  return M.options[key]
end

return M
