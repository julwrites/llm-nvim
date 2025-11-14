-- llm/chat/session.lua - Chat Session Management
-- License: Apache 2.0

local M = {}
local config = require('llm.config')
local shell = require('llm.core.utils.shell')

--- ChatSession class for managing individual chat sessions
-- @class ChatSession
local ChatSession = {}
ChatSession.__index = ChatSession

--- Create a new chat session
-- @param opts table: Session options
--   - model: string (optional) - Model to use
--   - system_prompt: string (optional) - System prompt
--   - fragments: table (optional) - List of fragment paths
--   - bufnr: number (optional) - Associated buffer number
-- @return ChatSession: New session instance
function ChatSession.new(opts)
  opts = opts or {}
  
  local session = {
    conversation_id = nil,  -- Will be set after first response
    model = opts.model or config.get("model"),
    system_prompt = opts.system_prompt or config.get("system_prompt"),
    fragments = opts.fragments or {},
    bufnr = opts.bufnr,
    state = 'ready', -- ready, processing, error
    current_job_id = nil,
  }
  
  setmetatable(session, ChatSession)
  
  if config.get('debug') then
    vim.notify(
      string.format("[ChatSession] Created new session (model: %s)", session.model or "default"),
      vim.log.levels.DEBUG
    )
  end
  
  return session
end

--- Build command parts for llm CLI
-- @param prompt string: User prompt to send
-- @return table: Command parts array
function ChatSession:build_command(prompt)
  local llm_executable = config.get("llm_executable_path") or "llm"
  local cmd_parts = { llm_executable, "prompt" }
  
  -- Add model if specified
  if self.model and self.model ~= "" then
    table.insert(cmd_parts, "-m")
    table.insert(cmd_parts, self.model)
  end
  
  -- For first message: add system prompt and fragments
  -- For continuation: use -c flag (system prompt and fragments are preserved)
  if not self.conversation_id then
    -- First message in conversation
    if self.system_prompt and self.system_prompt ~= "" then
      table.insert(cmd_parts, "-s")
      table.insert(cmd_parts, self.system_prompt)
    end
    
    -- Add fragments
    for _, fragment in ipairs(self.fragments) do
      table.insert(cmd_parts, "-f")
      table.insert(cmd_parts, fragment)
    end
  else
    -- Continuation of existing conversation
    table.insert(cmd_parts, "-c")
    table.insert(cmd_parts, self.conversation_id)
  end
  
  -- Note: Don't add prompt as argument here
  -- We'll send it via stdin to avoid quoting issues
  
  if config.get('debug') then
    vim.notify(
      string.format("[ChatSession] Command: %s (prompt via stdin)", table.concat(cmd_parts, " ")),
      vim.log.levels.DEBUG
    )
  end
  
  return cmd_parts
end

--- Extract conversation ID from LLM output
-- The LLM CLI includes conversation ID in the output like:
-- "Conversation ID: 01abc123def"
-- @param output string: Output text from LLM
-- @return string|nil: Extracted conversation ID or nil
function ChatSession:extract_conversation_id(output)
  if not output or output == "" then
    return nil
  end
  
  -- Try to find conversation ID in the output
  -- Pattern: "Conversation ID: <id>"
  local id = output:match("Conversation ID: ([%w]+)")
  
  if id then
    if config.get('debug') then
      vim.notify(
        string.format("[ChatSession] Extracted conversation ID: %s", id),
        vim.log.levels.DEBUG
      )
    end
    return id
  end
  
  return nil
end

--- Get conversation ID from llm CLI logs
-- Falls back to querying llm logs if ID not in output
-- @return string|nil: Conversation ID or nil
function ChatSession:get_conversation_id_from_logs()
  local llm_executable = config.get("llm_executable_path") or "llm"
  local cmd_string = string.format("%s logs -n 1 --json", llm_executable)
  
  local result = vim.fn.system(cmd_string)
  
  if not result or result == "" then
    if config.get('debug') then
      vim.notify("[ChatSession] No logs returned from llm CLI", vim.log.levels.DEBUG)
    end
    return nil
  end
  
  -- Trim whitespace
  result = result:gsub("^%s*(.-)%s*$", "%1")
  
  -- Parse JSON
  local ok, log_data = pcall(vim.json.decode, result)
  if not ok or not log_data or type(log_data) ~= "table" or #log_data == 0 then
    if config.get('debug') then
      vim.notify("[ChatSession] Failed to parse llm logs JSON", vim.log.levels.DEBUG)
    end
    return nil
  end
  
  -- Get conversation ID from first log entry
  local conversation_id = log_data[1] and log_data[1].conversation_id
  
  if conversation_id then
    if config.get('debug') then
      vim.notify(
        string.format("[ChatSession] Got conversation ID from logs: %s", conversation_id),
        vim.log.levels.DEBUG
      )
    end
  end
  
  return conversation_id
end

--- Update conversation ID from output or logs
-- @param output string: LLM output text
function ChatSession:update_conversation_id(output)
  -- First try to extract from output
  local id = self:extract_conversation_id(output)
  
  -- If not in output, query logs
  if not id then
    id = self:get_conversation_id_from_logs()
  end
  
  if id then
    self.conversation_id = id
    if config.get('debug') then
      vim.notify(
        string.format("[ChatSession] Conversation ID updated: %s", id),
        vim.log.levels.DEBUG
      )
    end
  else
    if config.get('debug') then
      vim.notify("[ChatSession] Could not determine conversation ID", vim.log.levels.WARN)
    end
  end
end

--- Send a prompt to the LLM
-- @param prompt string: User prompt
-- @param callbacks table: Callbacks for streaming
--   - on_stdout: function(job_id, data) - Called with stdout chunks
--   - on_stderr: function(job_id, data) - Called with stderr chunks
--   - on_exit: function(job_id, exit_code) - Called on completion
-- @return number|nil: Job ID or nil if failed
function ChatSession:send_prompt(prompt, callbacks)
  if not prompt or prompt == "" then
    vim.notify("Cannot send empty prompt", vim.log.levels.ERROR)
    return nil
  end
  
  -- Build command
  local cmd_parts = self:build_command(prompt)
  
  -- Update state
  self.state = 'processing'
  
  -- Track accumulated output for conversation ID extraction
  local accumulated_output = ""
  
  -- Wrap callbacks to track output and update conversation ID
  local wrapped_callbacks = {
    on_stdout = function(job_id, data)
      if data then
        for _, line in ipairs(data) do
          accumulated_output = accumulated_output .. line .. "\n"
        end
      end
      
      if callbacks and callbacks.on_stdout then
        callbacks.on_stdout(job_id, data)
      end
    end,
    
    on_stderr = function(job_id, data)
      if callbacks and callbacks.on_stderr then
        callbacks.on_stderr(job_id, data)
      end
    end,
    
    on_exit = function(job_id, exit_code)
      -- Update conversation ID after first message
      if not self.conversation_id then
        self:update_conversation_id(accumulated_output)
      end
      
      -- Update state
      if exit_code == 0 then
        self.state = 'ready'
      else
        self.state = 'error'
      end
      
      self.current_job_id = nil
      
      if callbacks and callbacks.on_exit then
        callbacks.on_exit(job_id, exit_code)
      end
    end,
  }
  
  -- Execute command using job module
  local job = require('llm.core.utils.job')
  local job_id = job.run(cmd_parts, wrapped_callbacks)
  
  if job_id then
    self.current_job_id = job_id
    
    -- Send prompt via stdin to avoid shell quoting issues
    vim.fn.chansend(job_id, prompt)
    vim.fn.chanclose(job_id, "stdin")
    
    if config.get('debug') then
      vim.notify(
        string.format("[ChatSession] Started job %d, sent prompt: %s", job_id, prompt),
        vim.log.levels.DEBUG
      )
    end
  else
    self.state = 'error'
    vim.notify("Failed to start LLM command", vim.log.levels.ERROR)
  end
  
  return job_id
end

--- Get current conversation ID
-- @return string|nil: Conversation ID or nil
function ChatSession:get_conversation_id()
  return self.conversation_id
end

--- Get current session state
-- @return string: Session state (ready, processing, error)
function ChatSession:get_state()
  return self.state
end

--- Check if session is ready for new prompts
-- @return boolean: True if ready
function ChatSession:is_ready()
  return self.state == 'ready'
end

--- Stop current job if running
function ChatSession:stop_current_job()
  if self.current_job_id then
    vim.fn.jobstop(self.current_job_id)
    self.current_job_id = nil
    self.state = 'ready'
    
    if config.get('debug') then
      vim.notify("[ChatSession] Stopped current job", vim.log.levels.DEBUG)
    end
  end
end

M.ChatSession = ChatSession
return M
