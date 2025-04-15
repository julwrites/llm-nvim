-- llm/schemas.lua - Simple schema handling for llm-nvim
-- License: Apache 2.0

local M = {}

-- Disabled functionality
function M.select_schema()
  vim.notify("Schemas functionality is currently disabled", vim.log.levels.INFO)
end

function M.manage_schemas()
  vim.notify("Schemas functionality is currently disabled", vim.log.levels.INFO)
end

-- Placeholder functions to maintain API compatibility
function M.get_schemas()
  return {}
end

function M.get_schema(name)
  return nil
end

function M.save_schema(name, schema_text)
  vim.notify("Schemas functionality is currently disabled", vim.log.levels.INFO)
  return false
end

function M.delete_schema(name)
  vim.notify("Schemas functionality is currently disabled", vim.log.levels.INFO)
  return false
end

function M.run_schema(name, input, is_multi)
  vim.notify("Schemas functionality is currently disabled", vim.log.levels.INFO)
  return nil
end

return M
