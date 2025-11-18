-- lua/llm/chat/buffer.lua

local M = {}

function M.new(opts)
  local self = setmetatable({}, { __index = M })
  opts = opts or {}
  self.bufnr = vim.api.nvim_create_buf(false, true)
  self.win_id = nil
  self.conversation_id = nil
  self.on_submit = opts.on_submit or function() end
  self.input_start_line = -1

  self:_setup_buffer()
  self:render({ history = {} })
  return self
end

function M:get_bufnr()
    return self.bufnr
end

function M:get_user_input()
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, self.input_start_line - 1, -1, false)
  lines[1] = lines[1]:sub(3) -- Remove "> "
  return table.concat(lines, "\n")
end

function M:set_status(status)
  vim.api.nvim_buf_set_lines(self.bufnr, 1, 2, false, { "LLM Chat - " .. status })
end

function M:append_user_message(message)
  vim.api.nvim_buf_set_lines(self.bufnr, self.input_start_line - 2, self.input_start_line - 2, false, {"", "**user**:", message})
  self.input_start_line = self.input_start_line + 3
  vim.api.nvim_buf_add_highlight(self.bufnr, -1, "Question", self.input_start_line - 4, 0, -1)
end

function M:clear_input()
  vim.api.nvim_buf_set_lines(self.bufnr, self.input_start_line - 1, -1, false, { "> " })
end

function M:set_input(text)
  vim.api.nvim_buf_set_lines(self.bufnr, self.input_start_line - 1, -1, false, { "> " .. text })
end

function M:append_llm_message(message)
  local last_line = vim.api.nvim_buf_get_lines(self.bufnr, self.input_start_line - 3, self.input_start_line - 2, false)[1]
  if last_line == "" or last_line == nil then
    vim.api.nvim_buf_set_lines(self.bufnr, self.input_start_line - 3, self.input_start_line - 2, false, { message })
  else
    vim.api.nvim_buf_set_lines(self.bufnr, self.input_start_line - 3, self.input_start_line - 2, false, { last_line .. message })
  end
  vim.api.nvim_buf_add_highlight(self.bufnr, -1, "Question", self.input_start_line - 3, 0, -1)
end

function M:get_last_line()
    local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
    return lines[#lines - 2]
end

function M:update_conversation_id(id)
  self.conversation_id = id
  vim.api.nvim_buf_set_lines(self.bufnr, 0, 1, false, { "--- Conversation ID: " .. id })
end

function M:focus_input()
  if self.win_id and vim.api.nvim_win_is_valid(self.win_id) then
    vim.api.nvim_win_set_cursor(self.win_id, { self.input_start_line, 3 })
    vim.cmd('startinsert')
  end
end

function M:_setup_buffer()
  vim.api.nvim_buf_set_option(self.bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(self.bufnr, "filetype", "markdown")

  -- Keymap for submitting the prompt
  vim.api.nvim_buf_set_keymap(
    self.bufnr,
    "n",
    "<CR>",
    "<Cmd>lua require('llm.chat')._submit_prompt_from_mapping()<CR>",
    { noremap = true, silent = true }
  )
end

function M:open()
  if self.win_id and vim.api.nvim_win_is_valid(self.win_id) then
    vim.api.nvim_set_current_win(self.win_id)
    -- Make buffer modifiable and focus input when window already exists
    vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
    self:focus_input()
    return
  end

  vim.cmd("vsplit")
  self.win_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(self.win_id, self.bufnr)

  -- Make buffer modifiable and focus input area
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
  self:focus_input()
end

function M:render(state)
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})

  local lines = { "---", "LLM Chat", "---", "" }
  
  -- Render history
  for _, message in ipairs(state.history or {}) do
    table.insert(lines, "**" .. message.role .. "**:")
    table.insert(lines, message.content)
    table.insert(lines, "")
  end

  -- Render input area
  self.input_start_line = #lines + 2
  table.insert(lines, "")
  table.insert(lines, "> ")
  
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  if self.win_id and vim.api.nvim_win_is_valid(self.win_id) then
    vim.api.nvim_win_set_cursor(self.win_id, { self.input_start_line, 3 })
  end
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
end

function M:get_input()
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, self.input_start_line - 1, -1, false)
  lines[1] = lines[1]:sub(3) -- Remove "> "
  return table.concat(lines, "\n")
end

function M:append_content(content)
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
  local last_line = vim.api.nvim_buf_line_count(self.bufnr)
  local line_content = vim.api.nvim_buf_get_lines(self.bufnr, last_line - 1, last_line, false)[1]
  
  -- Insert the new content on a new line before the input line
  vim.api.nvim_buf_set_lines(self.bufnr, self.input_start_line - 2, self.input_start_line - 2, false, {line_content .. content})

  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
end

function M:add_assistant_message(content)
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(self.bufnr, self.input_start_line - 2, self.input_start_line - 2, false, {"", "**assistant**:", content})
  self.input_start_line = self.input_start_line + 3
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
end

return { ChatBuffer = M }
