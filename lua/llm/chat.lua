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
  local buffer = ChatBuffer.new()
  
  -- Link session to buffer
  session.bufnr = buffer:get_bufnr()
  
  -- Store session for later access
  active_sessions[buffer:get_bufnr()] = {
    session = session,
    buffer = buffer,
  }
  
  -- Store reference in buffer variable for keymap access
  vim.b[buffer:get_bufnr()].llm_chat_session = active_sessions[buffer:get_bufnr()]
  
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
-- Called by keymap (<CR>)
function M.send_message()
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- Get chat data from active_sessions using buffer number
  local chat_data = active_sessions[bufnr]
  if not chat_data then
    vim.notify("Not a chat buffer", vim.log.levels.ERROR)
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
  
  -- Add user message to history
  buffer:append_user_message(prompt)
  buffer:add_llm_header()
  
  -- Send prompt to LLM
  local job_id = session:send_prompt(prompt, {
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          local new_conv_id = session:extract_conversation_id(line)
          if new_conv_id then
            session.conversation_id = new_conv_id
          else
            buffer:append_llm_message(line)
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
      -- Reset session state to ready regardless of exit code
      session:reset_state()

      if exit_code == 0 then
        buffer:add_user_header()

        -- Focus input for next message
        buffer:focus_input()

        if config.get('debug') then
          vim.notify(
            string.format("[Chat] Message completed (conversation: %s)", session:get_conversation_id() or "unknown"),
            vim.log.levels.DEBUG
          )
        end
      else
        vim.notify(
          string.format("LLM command failed with exit code: %d", exit_code),
          vim.log.levels.ERROR
        )
      end
    end,
  })
  
  if not job_id then
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
