-- llm/init.lua - Entry point for lazy.nvim integration
-- License: Apache 2.0

-- Check if the main module is already loaded
local ok, llm = pcall(require, 'llm')
if not ok then
  vim.notify("Failed to load llm module", vim.log.levels.ERROR)
  return {}
end

-- Re-export the main module
return llm
