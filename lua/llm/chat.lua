-- llm/chat.lua - Chat Orchestration
-- License: Apache 2.0

local M = {}
local config = require('llm.config')
local ChatSession = require('llm.chat.session').ChatSession
local ChatBuffer = require('llm.chat.buffer').ChatBuffer

-- Track active chat sessions by buffer number
local active_sessions = {}

--- Start a new chat session
-- @param opts table: Chat options
--   - model: string (optional) - Model to use
--   - system_prompt: string (optional) - System prompt
--   - fragments: table (optional) - List of fragment paths
-- @return table: { session, buffer }
function M.start_chat(opts)
  opts = opts or {}
  
  -- Create session
  local session = ChatSession.new({
    model = opts.model,
    system_prompt = opts.system_prompt,
    fragments = opts.fragments,
  })
  
  -- Create buffer
  local buffer = ChatBuffer.new({
    model = opts.model or config.get("model"),
    system_prompt = opts.system_prompt or config.get("system_prompt"),
  })
  
  -- Link session to buffer
  session.bufnr = buffer:get_bufnr()
  
  -- Store session for later access (keep table with metatables intact)
  active_sessions[buffer:get_bufnr()] = {
    session = session,
    buffer = buffer,
  }
  
  -- Store reference in buffer variable for keymap access
  -- Note: Store the active_sessions reference, not a copy
  vim.b[buffer:get_bufnr()].llm_chat_bufnr = buffer:get_bufnr()
  
  if config.get('debug') then
    vim.notify(
      string.format("[Chat] Started new chat session in buffer %d", buffer:get_bufnr()),
      vim.log.levels.DEBUG
    )
  end
  
  return {
    session = session,
    buffer = buffer,
  }
end

--- Send message from current buffer
-- Called by keymap (<C-CR> or <Leader>s)
function M.send_message()
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- Get chat data from active_sessions using buffer number
  local chat_bufnr = vim.b[bufnr].llm_chat_bufnr
  if not chat_bufnr then
    vim.notify("Not a chat buffer", vim.log.levels.ERROR)
    return
  end
  
  local chat_data = active_sessions[chat_bufnr]
  if not chat_data then
    vim.notify("Chat session not found", vim.log.levels.ERROR)
    return
  end
  
  local session = chat_data.session
  local buffer = chat_data.buffer
  
  -- Check if session is ready
  if not session:is_ready() then
    vim.notify("Chat is processing, please wait", vim.log.levels.WARN)
    return
  end
  
  -- Get user input
  local prompt = buffer:get_user_input()
  
  if not prompt or prompt == "" then
    vim.notify("Cannot send empty message", vim.log.levels.WARN)
    return
  end
  
  -- Switch to normal mode if in insert mode
  if vim.fn.mode() == 'i' then
    vim.cmd('stopinsert')
  end
  
  -- Update status
  buffer:set_status("Processing...")
  
  -- Add user message to history
  buffer:append_user_message(prompt)
  
  -- Clear input area
  buffer:clear_input()
  
  -- Send prompt to LLM
  local job_id = session:send_prompt(prompt, {
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          -- Skip conversation ID lines (they'll be extracted by session)
          if not line:match("^Conversation ID:") then
            buffer:append_llm_message(line .. "\n")
          end
        end
      end
    end,
    
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          vim.notify("LLM error: " .. line, vim.log.levels.ERROR)
        end
      end
    end,
    
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        buffer:set_status("Ready")
        
        -- Update conversation ID in buffer if this was first message
        local conv_id = session:get_conversation_id()
        if conv_id then
          buffer:update_conversation_id(conv_id)
        end
        
        -- Add blank line after LLM response
        buffer:append_llm_message("")
        
        -- Focus input for next message
        buffer:focus_input()
        
        if config.get('debug') then
          vim.notify(
            string.format("[Chat] Message completed (conversation: %s)", conv_id or "unknown"),
            vim.log.levels.DEBUG
          )
        end
      else
        buffer:set_status("Error")
        vim.notify(
          string.format("LLM command failed with exit code: %d", exit_code),
          vim.log.levels.ERROR
        )
      end
    end,
  })
  
  if not job_id then
    buffer:set_status("Error")
    vim.notify("Failed to start LLM command", vim.log.levels.ERROR)
  else
    if config.get('debug') then
      vim.notify(
        string.format("[Chat] Started job %d for message", job_id),
        vim.log.levels.DEBUG
      )
    end
  end
end

--- Start a new message in the input area
-- Called by keymap (<C-n>)
function M.new_message()
  local bufnr = vim.api.nvim_get_current_buf()
  local chat_data = vim.b[bufnr].llm_chat_session
  
  if not chat_data then
    vim.notify("Not a chat buffer", vim.log.levels.ERROR)
    return
  end
  
  local buffer = chat_data.buffer
  
  -- Clear input and focus
  buffer:clear_input()
  buffer:focus_input()
  
  if config.get('debug') then
    vim.notify("[Chat] Cleared input for new message", vim.log.levels.DEBUG)
  end
end

--- Get active session for a buffer
-- @param bufnr number: Buffer number
-- @return table|nil: Chat session data or nil
function M.get_session(bufnr)
  return active_sessions[bufnr]
end

--- Stop current job in active chat buffer
function M.stop_current_job()
  local bufnr = vim.api.nvim_get_current_buf()
  local chat_data = vim.b[bufnr].llm_chat_session
  
  if not chat_data then
    vim.notify("Not a chat buffer", vim.log.levels.ERROR)
    return
  end
  
  local session = chat_data.session
  session:stop_current_job()
  
  local buffer = chat_data.buffer
  buffer:set_status("Stopped")
  
  vim.notify("Stopped current LLM job", vim.log.levels.INFO)
end

--- Clean up session when buffer is deleted
-- Set up autocmd to clean up when chat buffer is closed
vim.api.nvim_create_autocmd("BufDelete", {
  callback = function(args)
    local bufnr = args.buf
    if active_sessions[bufnr] then
      -- Stop any running jobs
      local session = active_sessions[bufnr].session
      if session.current_job_id then
        session:stop_current_job()
      end
      
      -- Remove from active sessions
      active_sessions[bufnr] = nil
      
      if config.get('debug') then
        vim.notify(
          string.format("[Chat] Cleaned up session for buffer %d", bufnr),
          vim.log.levels.DEBUG
        )
      end
    end
  end,
})

return M
