-- llm/fragments/fragments_view.lua - UI functions for fragment management
-- License: Apache 2.0

local M = {}

local utils = require('llm.utils')
local api = vim.api

function M.view_fragment(fragment_hash, fragment_info)
  local content_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(content_buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(content_buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(content_buf, 'swapfile', false)
  api.nvim_buf_set_name(content_buf, 'Fragment: ' .. fragment_hash:sub(1, 8))

  utils.create_floating_window(content_buf, 'LLM Fragment Content')

  local content_lines = {
    "# Fragment: " .. fragment_hash,
    "Source: " .. (fragment_info.source or "unknown"),
    "Aliases: " .. (#fragment_info.aliases > 0 and table.concat(fragment_info.aliases, ", ") or "none"),
    "Date: " .. (fragment_info.datetime or "unknown"),
    "",
    "## Content:",
    "",
  }
  for line in fragment_info.content:gmatch("[^\r\n]+") do table.insert(content_lines, line) end
  api.nvim_buf_set_lines(content_buf, 0, -1, false, content_lines)

  api.nvim_buf_set_option(content_buf, 'modifiable', false)

  local filetype = "text"
  if fragment_info.source then
    local ext = fragment_info.source:match("%.([^%.]+)$")
    if ext then filetype = ext end
    if filetype == "js" then filetype = "javascript" end
    if filetype == "py" then filetype = "python" end
    if filetype == "md" then filetype = "markdown" end
  end
  api.nvim_buf_set_option(content_buf, 'filetype', filetype)

  api.nvim_buf_set_keymap(content_buf, 'n', 'q', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]],
    { noremap = true, silent = true })
  api.nvim_buf_set_keymap(content_buf, 'n', '<Esc>', [[<cmd>lua vim.api.nvim_win_close(0, true)<CR>]],
    { noremap = true, silent = true })
end

function M.get_alias(callback)
  utils.floating_input({ prompt = "Enter alias for fragment: " }, callback)
end

function M.select_alias_to_remove(aliases, callback)
  vim.ui.select(aliases, { prompt = "Select alias to remove:" }, callback)
end

function M.confirm_remove_alias(alias, callback)
  utils.floating_confirm({
    prompt = "Remove alias '" .. alias .. "'?",
    on_confirm = function(confirmed)
      callback(confirmed)
    end
  })
end

function M.get_prompt(callback)
    utils.floating_input({
        prompt = "Enter prompt to use with fragment: "
    }, callback)
end

return M
