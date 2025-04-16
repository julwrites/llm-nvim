-- llm/managers/templates_manager.lua - Template management for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local templates_loader = require('llm.loaders.templates_loader')

-- Disabled functionality
function M.select_template()
  vim.notify("Templates functionality is currently disabled", vim.log.levels.INFO)
end

function M.manage_templates()
  vim.notify("Templates functionality is currently disabled", vim.log.levels.INFO)
end

-- Re-export functions from templates_loader
M.get_templates = templates_loader.get_templates
M.get_template_details = templates_loader.get_template_details
M.create_template = templates_loader.create_template
M.delete_template = templates_loader.delete_template
M.run_template = templates_loader.run_template

return M
