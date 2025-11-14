-- llm/chat/buffer.lua - Chat Buffer UI Management
-- License: Apache 2.0

local M = {}
local config = require('llm.config')

--- ChatBuffer class for managing chat buffer UI
-- @class ChatBuffer
local ChatBuffer = {}
ChatBuffer.__index = ChatBuffer

-- Section markers
local HEADER_START_MARKER = "╭─"
local HEADER_END_MARKER = "╰─"
local HISTORY_START_MARKER = "┌─ Conversation History "
local HISTORY_END_MARKER = "└─"
local INPUT_START_MARKER = "┌─ Your Message "
local INPUT_END_MARKER = "└─"

--- Create a new chat buffer
-- @param opts table: Buffer options
--   - model: string (optional) - Model name
--   - conversation_id: string (optional) - Conversation ID
--   - system_prompt: string (optional) - System prompt
-- @return ChatBuffer: New buffer instance
function ChatBuffer.new(opts)
  opts = opts or {}
  
  -- Create new vertical split
  vim.cmd('vnew')
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- Configure buffer
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)  -- Allow modifications
  
  -- Set buffer name
  local model_name = opts.model or config.get("model") or "default"
  local conversation_id = opts.conversation_id or "new"
  local buffer_name = string.format("LLM Chat - %s (%s)", model_name, conversation_id)
  vim.api.nvim_buf_set_name(bufnr, buffer_name)
  
  local buffer = {
    bufnr = bufnr,
    model = opts.model,
    conversation_id = opts.conversation_id,
    system_prompt = opts.system_prompt,
    history_start_line = 0, -- Will be set after initialization
    history_end_line = 0,
    input_start_line = 0,
    input_end_line = 0,
  }
  
  setmetatable(buffer, ChatBuffer)
  
  -- Initialize buffer layout
  buffer:initialize_layout()
  
  -- Set up keymaps
  buffer:setup_keymaps()
  
  -- Set up highlights
  buffer:setup_highlights()
  
  -- Move cursor to input area
  buffer:focus_input()
  
  if config.get('debug') then
    vim.notify(
      string.format("[ChatBuffer] Created buffer %d", bufnr),
      vim.log.levels.DEBUG
    )
  end
  
  return buffer
end

--- Initialize buffer layout with sections
function ChatBuffer:initialize_layout()
  local lines = {}
  
  -- Header line
  local model_display = self.model or config.get("model") or "default"
  local conv_id_display = self.conversation_id or "new"
  table.insert(lines, string.format("LLM Chat - %s (ID: %s) | Status: Ready", model_display, conv_id_display))
  table.insert(lines, "")
  
  -- Conversation history section
  self.history_start_line = #lines
  table.insert(lines, "No messages yet")
  self.history_end_line = #lines
  table.insert(lines, "")
  
  -- Input area section
  self.input_start_line = #lines
  table.insert(lines, "--- (<C-CR> to send) ---")
  table.insert(lines, "Type your message here...")
  self.input_end_line = #lines
  
  -- Set buffer content
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  
  -- Make history section read-only by default (we'll manage this programmatically)
  -- Neovim doesn't have per-line read-only, so we'll handle in keymaps
end

--- Set up buffer keymaps with proper scoping
function ChatBuffer:setup_keymaps()
  local bufnr = self.bufnr
  
  -- Helper function to check if cursor is in input area
  local function is_cursor_in_input()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1]
    return line > self.input_start_line and line <= self.input_end_line
  end
  
  -- Auto-remove placeholder on insert mode entry
  vim.api.nvim_create_autocmd("InsertEnter", {
    buffer = bufnr,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      local line_num = cursor[1]
      
      -- Check if cursor is in input area
      if line_num > self.input_start_line and line_num <= self.input_end_line then
        local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
        
        -- Remove placeholder text if present
        if line and line:match("Type your message here") then
          vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {""})
          -- Keep cursor at the now-empty line
          vim.api.nvim_win_set_cursor(0, {line_num, 0})
        end
      end
    end
  })
  
  -- <C-CR> to send prompt (works anywhere, but only sends if in input area)
  vim.api.nvim_buf_set_keymap(
    bufnr, 'i', '<C-CR>',
    '<Cmd>lua require("llm.chat").send_message()<CR>',
    { noremap = true, silent = true, desc = "Send message" }
  )
  
  vim.api.nvim_buf_set_keymap(
    bufnr, 'n', '<C-CR>',
    '<Cmd>lua require("llm.chat").send_message()<CR>',
    { noremap = true, silent = true, desc = "Send message" }
  )
  
  -- <Leader>s alternative to send
  vim.api.nvim_buf_set_keymap(
    bufnr, 'i', '<Leader>s',
    '<Cmd>lua require("llm.chat").send_message()<CR>',
    { noremap = true, silent = true, desc = "Send message" }
  )
  
  vim.api.nvim_buf_set_keymap(
    bufnr, 'n', '<Leader>s',
    '<Cmd>lua require("llm.chat").send_message()<CR>',
    { noremap = true, silent = true, desc = "Send message" }
  )
  
  -- q to close buffer
  vim.api.nvim_buf_set_keymap(
    bufnr, 'n', 'q',
    '<Cmd>bd<CR>',
    { noremap = true, silent = true, desc = "Close chat buffer" }
  )
  
  -- <C-n> to clear input and start new message
  vim.api.nvim_buf_set_keymap(
    bufnr, 'n', '<C-n>',
    '<Cmd>lua require("llm.chat").new_message()<CR>',
    { noremap = true, silent = true, desc = "New message" }
  )
  
  vim.api.nvim_buf_set_keymap(
    bufnr, 'i', '<C-n>',
    '<Cmd>lua require("llm.chat").new_message()<CR>',
    { noremap = true, silent = true, desc = "New message" }
  )
  
  if config.get('debug') then
    vim.notify("[ChatBuffer] Keymaps configured", vim.log.levels.DEBUG)
  end
end

--- Set up syntax highlighting for chat elements
function ChatBuffer:setup_highlights()
  -- Define highlight groups
  vim.api.nvim_set_hl(0, 'LlmChatHeader', { fg = '#f8f8f2', bg = '#44475a', bold = true })
  vim.api.nvim_set_hl(0, 'LlmChatBorder', { fg = '#6272a4' })
  vim.api.nvim_set_hl(0, 'LlmChatUserTag', { fg = '#50fa7b', bold = true })    -- Green
  vim.api.nvim_set_hl(0, 'LlmChatLlmTag', { fg = '#bd93f9', bold = true })     -- Purple
  vim.api.nvim_set_hl(0, 'LlmChatStatus', { fg = '#8be9fd', italic = true })   -- Cyan
  vim.api.nvim_set_hl(0, 'LlmChatInputPrompt', { fg = '#ffb86c', italic = true }) -- Orange
  
  -- Apply highlights to header
  vim.api.nvim_buf_add_highlight(self.bufnr, -1, 'LlmChatBorder', 0, 0, -1)
  vim.api.nvim_buf_add_highlight(self.bufnr, -1, 'LlmChatStatus', 1, 0, -1)
  vim.api.nvim_buf_add_highlight(self.bufnr, -1, 'LlmChatBorder', 2, 0, -1)
end

--- Update conversation ID in header
-- @param conversation_id string: New conversation ID
function ChatBuffer:update_conversation_id(conversation_id)
  self.conversation_id = conversation_id
  
  -- Update buffer name
  local model_display = self.model or config.get("model") or "default"
  local buffer_name = string.format("LLM Chat - %s (%s)", model_display, conversation_id)
  vim.api.nvim_buf_set_name(self.bufnr, buffer_name)
  
  if config.get('debug') then
    vim.notify(
      string.format("[ChatBuffer] Updated conversation ID: %s", conversation_id),
      vim.log.levels.DEBUG
    )
  end
end

--- Set status message in header
-- @param status string: Status message
function ChatBuffer:set_status(status)
  self.current_status = status
  local model_display = self.model or config.get("model") or "default"
  local conv_id_display = self.conversation_id or "new"
  local new_line = string.format("LLM Chat - %s (ID: %s) | Status: %s", model_display, conv_id_display, status)
  
  vim.api.nvim_buf_set_lines(self.bufnr, 0, 1, false, { new_line })
  vim.api.nvim_buf_add_highlight(self.bufnr, -1, 'LlmChatStatus', 0, 0, -1)
end

--- Append user message to history
-- @param message string: User message
function ChatBuffer:append_user_message(message)
  if not message or message == "" then
    return
  end
  
  -- Get ALL current history content (everything between header and input section)
  local history_lines = vim.api.nvim_buf_get_lines(
    self.bufnr,
    2,  -- Start after header (line 0 is title, line 1 is blank)
    self.input_start_line,  -- Everything before input section
    false
  )
  
  -- Remove placeholder if exists
  if #history_lines == 1 and history_lines[1]:match("No messages yet") then
    history_lines = {}
  end
  
  -- Filter out any remaining placeholder lines
  local filtered_lines = {}
  for _, line in ipairs(history_lines) do
    if not line:match("No messages yet") then
      table.insert(filtered_lines, line)
    end
  end
  history_lines = filtered_lines
  
  -- Remove trailing blank line if exists
  if #history_lines > 0 and history_lines[#history_lines] == "" then
    table.remove(history_lines)
  end
  
  -- Add user message with tag
  table.insert(history_lines, "[You]")
  
  -- Split message by lines
  for line in message:gmatch("[^\r\n]+") do
    table.insert(history_lines, line)
  end
  
  table.insert(history_lines, "")
  
  -- Rebuild entire buffer to fix formatting
  self:rebuild_buffer(history_lines)
  
  if config.get('debug') then
    vim.notify(string.format("[ChatBuffer] Appended user message (%d history lines)", #history_lines), vim.log.levels.DEBUG)
  end
end

--- Append LLM message to history (supports streaming)
-- @param text string: LLM response text
function ChatBuffer:append_llm_message(text)
  if not text or text == "" then
    return
  end
  
  -- Get ALL current history content
  local history_lines = vim.api.nvim_buf_get_lines(
    self.bufnr,
    2,  -- Start after header
    self.input_start_line,  -- Everything before input section
    false
  )
  
  -- Remove placeholder if exists
  if #history_lines == 1 and history_lines[1]:match("No messages yet") then
    history_lines = {}
  end
  
  -- Filter out any remaining placeholder lines
  local filtered_lines = {}
  for _, line in ipairs(history_lines) do
    if not line:match("No messages yet") then
      table.insert(filtered_lines, line)
    end
  end
  history_lines = filtered_lines
  
  -- Remove trailing blank line if exists
  if #history_lines > 0 and history_lines[#history_lines] == "" then
    table.remove(history_lines)
  end
  
  -- Check if this is the first chunk of a new LLM response
  local is_new_response = #history_lines == 0 or 
                          history_lines[#history_lines] == "" or
                          history_lines[#history_lines]:match("^%[You%]") or
                          history_lines[#history_lines]:match("^%[LLM%]")
  
  if is_new_response then
    table.insert(history_lines, "[LLM]")
  end
  
  -- Append the text (handle streaming chunks)
  local lines = {}
  for line in text:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  
  -- If text ends with newline, add it
  if text:match("\n$") then
    table.insert(lines, "")
  end
  
  for _, line in ipairs(lines) do
    table.insert(history_lines, line)
  end
  
  -- Rebuild entire buffer to fix formatting
  self:rebuild_buffer(history_lines)
end

--- Rebuild entire buffer with current history
-- @param history_lines table: Array of history lines
function ChatBuffer:rebuild_buffer(history_lines)
  local lines = {}
  
  -- Header line
  local model_display = self.model or config.get("model") or "default"
  local conv_id_display = self.conversation_id or "new"
  local status_display = self.current_status or "Ready"
  table.insert(lines, string.format("LLM Chat - %s (ID: %s) | Status: %s", model_display, conv_id_display, status_display))
  table.insert(lines, "")
  
  -- History section
  self.history_start_line = #lines
  
  -- Add all history lines
  for _, line in ipairs(history_lines) do
    table.insert(lines, line)
  end
  
  self.history_end_line = #lines
  table.insert(lines, "")
  
  -- Input section
  self.input_start_line = #lines
  table.insert(lines, "--- (<C-CR> to send) ---")
  table.insert(lines, "Type your message here...")
  self.input_end_line = #lines
  
  -- Replace entire buffer
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  
  if config.get('debug') then
    vim.notify(
      string.format("[ChatBuffer] Rebuilt buffer: history_start=%d, history_end=%d", 
        self.history_start_line, self.history_end_line),
      vim.log.levels.DEBUG
    )
  end
end

--- Get user input from input section
-- @return string: User input text
function ChatBuffer:get_user_input()
  -- Get lines from input area (after the separator line)
  local input_lines = vim.api.nvim_buf_get_lines(
    self.bufnr,
    self.input_start_line + 1,
    self.input_end_line + 1,
    false
  )
  
  -- Filter out placeholder text
  local cleaned_lines = {}
  for _, line in ipairs(input_lines) do
    -- Skip placeholder text
    if not line:match("^Type your message here") then
      table.insert(cleaned_lines, line)
    end
  end
  
  local input = table.concat(cleaned_lines, "\n")
  
  -- Trim whitespace
  input = input:gsub("^%s+", ""):gsub("%s+$", "")
  
  if config.get('debug') then
    vim.notify(
      string.format("[ChatBuffer] Got user input: %s", input),
      vim.log.levels.DEBUG
    )
  end
  
  return input
end

--- Clear input area
function ChatBuffer:clear_input()
  -- Reset input section with placeholder
  local input_lines = {
    "--- (<C-CR> to send) ---",
    "Type your message here...",
  }
  
  -- Replace input section
  vim.api.nvim_buf_set_lines(
    self.bufnr,
    self.input_start_line,
    self.input_end_line + 1,
    false,
    input_lines
  )
  
  -- Update input_end_line
  self.input_end_line = self.input_start_line + 1
  
  if config.get('debug') then
    vim.notify("[ChatBuffer] Cleared input area", vim.log.levels.DEBUG)
  end
end

--- Set input area text
-- @param text string: Text to set in input area
function ChatBuffer:set_input(text)
  -- Build input section with text
  local input_lines = {
    "--- (<C-CR> to send) ---",
    text,
  }
  
  -- Replace input section
  vim.api.nvim_buf_set_lines(
    self.bufnr,
    self.input_start_line,
    self.input_end_line + 1,
    false,
    input_lines
  )
  
  -- Update input_end_line
  self.input_end_line = self.input_start_line + 1
  
  if config.get('debug') then
    vim.notify("[ChatBuffer] Set input text: " .. text, vim.log.levels.DEBUG)
  end
end

--- Focus cursor on input area
function ChatBuffer:focus_input()
  -- Move cursor to input area (first editable line)
  local input_line = self.input_start_line + 2 -- Line after start marker
  vim.api.nvim_win_set_cursor(0, { input_line, 2 }) -- Position after "│ "
  
  -- Switch to insert mode
  vim.cmd('startinsert')
end

--- Check if cursor is in input area
-- @return boolean: True if cursor is in input section
function ChatBuffer:is_cursor_in_input()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  return line > self.input_start_line and line <= self.input_end_line
end

--- Get buffer number
-- @return number: Buffer number
function ChatBuffer:get_bufnr()
  return self.bufnr
end

M.ChatBuffer = ChatBuffer
return M
