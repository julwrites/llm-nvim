-- llm/managers/tools_manager.lua - Tool management for llm-nvim
-- License: Apache 2.0

local M = {}

local llm_cli = require('llm.core.data.llm_cli')

function M.get_tools()
  local tools_json = llm_cli.run_llm_command('tools list --json')

  if not tools_json or tools_json == "" then
    return {}
  end

  local ok, tools_data = pcall(vim.fn.json_decode, tools_json)
  if not ok or type(tools_data) ~= "table" then
    vim.notify("Failed to parse tools JSON: " .. tostring(tools_json), vim.log.levels.ERROR)
    return {}
  end

  -- Some tools list might just be the list or nested under "tools"
  local tools_list = {}
  if tools_data.tools and type(tools_data.tools) == "table" then
    tools_list = tools_data.tools
  else
    tools_list = tools_data
  end

  return tools_list
end

M.__name = 'llm.managers.tools_manager'

return M
