-- llm/loaders/templates_loader.lua - Template loading functionality for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local utils = require('llm.utils')

-- Disabled functionality
function M.get_templates()
  return {}
end

function M.get_template_details(template_name)
  return {
    name = template_name,
    prompt = "",
    system = "",
    schema = nil
  }
end

function M.create_template(name, prompt, system, schema)
  vim.notify("Templates functionality is currently disabled", vim.log.levels.INFO)
  return false
end

function M.delete_template(name)
  vim.notify("Templates functionality is currently disabled", vim.log.levels.INFO)
  return false
end

function M.run_template(name, input)
  vim.notify("Templates functionality is currently disabled", vim.log.levels.INFO)
  return nil
end

return M
