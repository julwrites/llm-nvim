-- lua/llm/chat/buffer.lua

local M = {}

function M.new(opts)
  local self = setmetatable({}, { __index = M })
  opts = opts or {}
  self.bufnr = vim.api.nvim_create_buf(false, true)
  self.win_id = nil
  self.on_submit = opts.on_submit or function() end

  self:_setup_buffer()
  self:render()
  return self
end

function M:get_bufnr()
    return self.bufnr
end

function M:get_user_input()
  local current_cursor_line, _ = table.unpack(vim.api.nvim_win_get_cursor(0))
  local all_buffer_lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)

  local you_marker_line_num = -1

  for i = current_cursor_line, 1, -1 do
    if all_buffer_lines[i] == "--- You ---" then
      you_marker_line_num = i
      break
    end
  end

  if you_marker_line_num == -1 then
    vim.notify("Error: '--- You ---' marker not found in buffer.", vim.log.levels.ERROR)
    return nil
  end

  local user_prompt_lines = {}
  for i = you_marker_line_num + 1, current_cursor_line do
    table.insert(user_prompt_lines, all_buffer_lines[i])
  end

  -- Strip the '> ' prefix from the first line
  if #user_prompt_lines > 0 and user_prompt_lines[1]:sub(1, 2) == "> " then
    user_prompt_lines[1] = user_prompt_lines[1]:sub(3)
  end

  return table.concat(user_prompt_lines, "\n")
end


function M:append_user_message(message)
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
  local all_buffer_lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)

  local you_marker_line_idx = -1

  for i = #all_buffer_lines, 1, -1 do
    if all_buffer_lines[i] == "--- You ---" then
      you_marker_line_idx = i - 1 -- 0-indexed
      break
    end
  end

  if you_marker_line_idx ~= -1 then
    -- Split message into lines
    local message_lines = vim.split(message, "\n")
    -- Replace from the line after "--- You ---" to the end of the buffer
    vim.api.nvim_buf_set_lines(self.bufnr, you_marker_line_idx + 1, -1, false, message_lines)
  end
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
end

function M:append_llm_message(message)
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
  local last_line_num = vim.api.nvim_buf_line_count(self.bufnr)
  local last_line_content = vim.api.nvim_buf_get_lines(self.bufnr, last_line_num - 1, last_line_num, false)[1] or ""

  -- Append message to the last line, handling newlines
  local message_lines = vim.split(message, "\n")
  if #message_lines == 1 then
    vim.api.nvim_buf_set_lines(self.bufnr, last_line_num - 1, last_line_num, false, {last_line_content .. message})
  else
    vim.api.nvim_buf_set_lines(self.bufnr, last_line_num - 1, last_line_num, false, {last_line_content .. message_lines[1]})
    table.remove(message_lines, 1)
    vim.api.nvim_buf_set_lines(self.bufnr, last_line_num, last_line_num, false, message_lines)
  end

  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
end

function M:focus_input()
  if self.win_id and vim.api.nvim_win_is_valid(self.win_id) then
    local num_lines = vim.api.nvim_buf_line_count(self.bufnr)
    vim.api.nvim_win_set_cursor(self.win_id, { num_lines, 3 })
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
    "<Cmd>lua require('llm.chat').send_message()<CR>",
    { noremap = true, silent = true }
  )
end

function M:open()
  if self.win_id and vim.api.nvim_win_is_valid(self.win_id) then
    vim.api.nvim_set_current_win(self.win_id)
    vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
    self:focus_input()
    return
  end

  vim.cmd("vsplit")
  self.win_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(self.win_id, self.bufnr)

  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
  self:focus_input()
end

function M:render()
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})

  local lines = {
    "Enter your prompt below and press <Enter> to submit",
    "-----------",
    "--- You ---",
    "> ",
  }
  
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  if self.win_id and vim.api.nvim_win_is_valid(self.win_id) then
      local num_lines = vim.api.nvim_buf_line_count(self.bufnr)
    vim.api.nvim_win_set_cursor(self.win_id, { num_lines, 3 })
  end
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
end

function M:add_llm_header()
    vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
    local num_lines = vim.api.nvim_buf_line_count(self.bufnr)
    vim.api.nvim_buf_set_lines(self.bufnr, num_lines, num_lines, false, {"--- LLM ---"})
    vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
end

function M:add_user_header()
    vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
    local num_lines = vim.api.nvim_buf_line_count(self.bufnr)
    vim.api.nvim_buf_set_lines(self.bufnr, num_lines, num_lines, false, {"--- You ---", "> "})
    vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
end


return { ChatBuffer = M }
