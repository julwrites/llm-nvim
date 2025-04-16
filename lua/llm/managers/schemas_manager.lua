-- llm/managers/schemas_manager.lua - Schema management for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local schemas_loader = require('llm.loaders.schemas_loader')

-- Disabled functionality
function M.select_schema()
  vim.notify("Schemas functionality is currently disabled", vim.log.levels.INFO)
end

function M.manage_schemas()
  vim.notify("Schemas functionality is currently disabled", vim.log.levels.INFO)
end

-- Re-export functions from schemas_loader
M.get_schemas = schemas_loader.get_schemas
M.get_schema = schemas_loader.get_schema
M.save_schema = schemas_loader.save_schema
M.delete_schema = schemas_loader.delete_schema
M.run_schema = schemas_loader.run_schema

return M
