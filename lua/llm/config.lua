-- llm/config.lua - Configuration module for llm-nvim
-- License: Apache 2.0

local M = {}

-- Default configuration
M.defaults = {
  model = "",
  system_prompt = "",
  no_mappings = false,
}

-- User configuration
M.options = {}

-- Initialize configuration
function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts)
  
  -- For backward compatibility, also check global variables
  if vim.g.llm_model and vim.g.llm_model ~= "" then
    M.options.model = vim.g.llm_model
  end
  
  if vim.g.llm_system_prompt and vim.g.llm_system_prompt ~= "" then
    M.options.system_prompt = vim.g.llm_system_prompt
  end
  
  if vim.g.llm_no_mappings == 1 then
    M.options.no_mappings = true
  end
end

-- Get a configuration value
function M.get(key)
  return M.options[key]
end

return M
