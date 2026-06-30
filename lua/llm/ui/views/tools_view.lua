-- llm/ui/views/tools_view.lua - UI functions for tool management
-- License: Apache 2.0

local M = {}

local ui = require('llm.core.utils.ui')
local api = vim.api

-- Displays detailed information about a tool in a floating window.
function M.show_details(tool_name, tool_info, manager_module)
  local content_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(content_buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(content_buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(content_buf, 'swapfile', false)
  api.nvim_buf_set_name(content_buf, 'Tool Details: ' .. tool_name)

  local winid = ui.create_floating_window(content_buf, 'Tool Details')

  local lines = {
    "# Tool: " .. tool_name,
    "",
    "Description: " .. (tool_info.description or "None"),
    "Plugin: " .. (tool_info.plugin or "None"),
    "",
    "## Arguments:",
  }

  if tool_info.arguments and tool_info.arguments.properties and not vim.tbl_isempty(tool_info.arguments.properties) then
    for arg_name, arg_data in pairs(tool_info.arguments.properties) do
      table.insert(lines, "- " .. arg_name .. ": " .. (arg_data.description or "") .. " (Type: " .. (arg_data.type or "unknown") .. ")")
    end
  else
    table.insert(lines, "None")
  end

  table.insert(lines, "")
  table.insert(lines, "Press [q]uit or [Esc] to close")

  api.nvim_buf_set_lines(content_buf, 0, -1, false, lines)

  -- Setup syntax highlights if needed
  local styles = require('llm.ui.styles')
  pcall(styles.setup_buffer_syntax, content_buf)

  api.nvim_buf_set_option(content_buf, 'modifiable', false)

  local function set_keymap(mode, lhs, rhs)
    api.nvim_buf_set_keymap(content_buf, mode, lhs, rhs, { noremap = true, silent = true })
  end

  set_keymap('n', 'q', '<Cmd>close<CR>')
  set_keymap('n', '<Esc>', '<Cmd>close<CR>')
end

return M
