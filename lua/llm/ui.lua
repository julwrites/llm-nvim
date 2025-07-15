-- lua/llm/ui.lua - UI functions for the llm-nvim plugin

local M = {}
local api = vim.api

function M.display_in_buffer(bufnr, lines, syntax)
  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  if syntax then
    vim.bo[bufnr].syntax = syntax
  end
end

function M.notify(message, level)
  vim.notify(message, level)
end

function M.get_input(prompt, on_confirm)
  vim.ui.input({ prompt = prompt }, on_confirm)
end

function M.select(items, opts, on_choice)
  vim.ui.select(items, opts, on_choice)
end

return M
