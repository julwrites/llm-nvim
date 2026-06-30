-- llm/managers/tools_manager.lua - Tool management for llm-nvim
-- License: Apache 2.0

local M = {}

local llm_cli = require('llm.core.data.llm_cli')
local api = vim.api
local styles = require('llm.ui.styles')
local tools_view = require('llm.ui.views.tools_view')

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

-- Populate the buffer with tool management content
function M.populate_tools_buffer(bufnr)
  local tools = M.get_tools()

  local lines = {
    "# Tool Management",
    "",
    "Navigate: [M]odels [P]lugins [K]eys [F]ragments",
    "Actions: [v]iew details [q]uit",
    "──────────────────────────────────────────────────────────────",
    "",
  }

  local tool_data = {}
  local line_to_tool = {}

  if #tools == 0 then
    table.insert(lines, "No tools found.")
  else
    table.insert(lines, "Available Tools:")
    table.insert(lines, "----------------")
    local current_line = #lines + 1

    for _, tool in ipairs(tools) do
      table.insert(lines, "- " .. tool.name .. ": " .. (tool.description or "No description"))
      tool_data[tool.name] = tool
      line_to_tool[current_line] = tool.name
      current_line = current_line + 1
    end
  end

  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  styles.setup_highlights()
  styles.setup_buffer_syntax(bufnr)

  vim.b[bufnr].line_to_tool = line_to_tool
  vim.b[bufnr].tool_data = tool_data

  return line_to_tool, tool_data
end

-- Setup keymaps for the tools management buffer
function M.setup_tools_keymaps(bufnr, manager_module)
  manager_module = manager_module or M

  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, { noremap = true, silent = true })
  end

  -- View tool details
  set_keymap('n', 'v', string.format([[<Cmd>lua require('%s').view_tool_details_under_cursor(%d)<CR>]], manager_module.__name or 'llm.managers.tools_manager', bufnr))
end

-- View tool details
function M.view_tool_details_under_cursor(bufnr)
  local tool_name, tool_info = M.get_tool_info_under_cursor(bufnr)
  if not tool_name then
    vim.notify("No tool found under cursor", vim.log.levels.WARN)
    return
  end

  -- Open details view
  tools_view.show_details(tool_name, tool_info, M)
end

-- Get tool info under cursor
function M.get_tool_info_under_cursor(bufnr)
  local current_line = api.nvim_win_get_cursor(0)[1]
  local line_to_tool = vim.b[bufnr].line_to_tool
  local tool_data = vim.b[bufnr].tool_data

  if not line_to_tool or not tool_data then
    return nil, nil
  end

  local tool_name = line_to_tool[current_line]
  if tool_name and tool_data[tool_name] then
    return tool_name, tool_data[tool_name]
  end

  return nil, nil
end

-- Main function to open tools view
function M.manage_tools()
  require('llm.ui.unified_manager').open_specific_manager("Tools")
end

M.__name = 'llm.managers.tools_manager'

return M
